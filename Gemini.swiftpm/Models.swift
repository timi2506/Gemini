import SwiftUI
import Foundation
import GoogleGenerativeAI
import Foundation
import Combine
import AsyncButton 

class GeminiModelStore: ObservableObject {
    private let userDefaultsKey = "models"
    
    // This returns a fresh copy from UserDefaults every time it's read
    var models: [GeminiModel] {
        get {
            if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
               let decoded = try? JSONDecoder().decode([GeminiModel].self, from: data) {
                return decoded
            } else {
                return defaultModels
            }
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
                objectWillChange.send()
            }
        }
    }
    
    var defaultModels: [GeminiModel] {
        [
            GeminiModel(name: "Gemini 2.0 Flash", id: "gemini-2.0-flash"),
            GeminiModel(name: "Gemini 2.0 Flash-Lite", id: "gemini-2.0-flash-lite"),
            GeminiModel(name: "Gemini 1.5 Flash", id: "gemini-1.5-flash"),
            GeminiModel(name: "Gemini 1.5 Flash-8B", id: "gemini-1.5-flash-8b"),
            GeminiModel(name: "Gemini 1.5 Pro", id: "gemini-1.5-pro")
        ]
    }
    
    func resetModels() {
        models = defaultModels
    }
}


struct GeminiModel: Codable, Identifiable, Hashable {
    let name: String
    let id: String
}

struct GeminiPicker: View {
    @Binding var selection: GeminiModel
     @StateObject var modelStore = GeminiModelStore()
    var body: some View {
        Menu("Model") {
            Picker("Model", selection: $selection) {
                ForEach(modelStore.models) { model in
                    Text(model.name)
                        .tag(model)
                }
            }
        }
    }
}

struct ModeltestResult: Hashable, Codable, Identifiable {
    let name: String
    let id: String
    let result: ModeltestResultEnum
}

enum ModeltestResultEnum: Codable {
    case error
    case success
}

struct AddKeyView: View {
    @State var testResults: [ModeltestResult] = []
    @State var testing = false
    @State var newApiKey = ""
     @KeychainText("apiKey", defaultValue: "") var apiKey: String
    @State var noSuccesses = true
     @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack {
                Text("Welcome!")
                    .fontDesign(.rounded)
                    .font(.title)
                    .bold()
                Text("To use this App, you need to provide your Gemini API Key.\n\n [How?](https://github.com/timi2506/wsf-md-guides/blob/1fcab31cea13cb0d7156a50d013e46d4d265404b/README.md)")
                    .fontDesign(.rounded)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding()
            Form {
                TextField("API Key", text: $newApiKey)
            }
            NavigationLink(destination: {
                Text("Validate your Key")
                    .fontDesign(.rounded)
                    .font(.title)
                    .bold()
                Text("Next, we have to validate your API Key to check which Models it works with")
                    .fontDesign(.rounded)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                AsyncButton("Run Test", "play.fill", cancellationMessage: "This will stop the Test and might stop you from proceeding") {
                    testResults = []
                    await testAPIkey(key: newApiKey, results: $testResults, testing: $testing)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                List {
                    if testResults.isEmpty {
                        Text("This Test will Test each Model supported by this App, if at least one is supported you can continue, please make sure to only use Models supported by your API Key")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    } else {
                        Section("Test Results - Pull to Refresh") {
                            ForEach(testResults) { result in
                                if result.result == .error {
                                    HStack {
                                        Image(systemName: "xmark")
                                        VStack(alignment: .leading) {
                                            Text(result.name)
                                            Text(result.id)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .foregroundStyle(.red)
                                } else if result.result == .success {
                                    HStack {
                                        Image(systemName: "checkmark")
                                        VStack(alignment: .leading) {
                                            Text(result.name)
                                            Text(result.id)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                }
                .refreshable {
                    testResults = []
                    await testAPIkey(key: newApiKey, results: $testResults, testing: $testing)
                }
                Spacer()
                Button(action: {
                    dismiss.callAsFunction()
                    apiKey = newApiKey
                }) {
                    Text("Add API Key")
                        .foregroundColor(.white)
                        .font(.headline)
                        .padding()
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .center)
                        .background(RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(Color.accentColor))
                        .padding(.bottom)
                }
                .disabled(noSuccesses)
                .padding()
            }) {
                Text("Continue")
                    .foregroundColor(.white)
                    .font(.headline)
                    .padding()
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .center)
                    .background(RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Color.accentColor))
                    .padding(.bottom)
            }
            .padding()
        }
        .onChange(of: testing) { newValue in
            if testing {
                noSuccesses = true
            } else {
                for result in testResults {
                    if result.result == .success {
                        noSuccesses = false
                    }
                }
            }
        }
        .onChange(of: newApiKey) {_ in
            testResults = []    
        }
    }
}

func streamTestResponse(key: String, model: GeminiModel) async -> ModeltestResult {
    var response: String = ""
    do {
        let prompt = "This is a system Test, respond with exactly \"Success\" without the \"'s to indicate that no issues occured."
        let testModel = GenerativeModel(name: model.id, apiKey: key)
        for try await chunk in testModel.generateContentStream(prompt) {
            let newText = chunk.text ?? ""
            DispatchQueue.main.async {
                response += newText
            }
        }
        if !response.isEmpty {
            print(response)
            return ModeltestResult(name: model.name, id: model.id, result: .success)
        } else {
            return ModeltestResult(name: model.name, id: model.id, result: .error)
        }
    } catch {
        return ModeltestResult(name: model.name, id: model.id, result: .error)
    }
}
func testAPIkey(key: String, results: Binding<[ModeltestResult]>, testing: Binding<Bool>) async {
     @StateObject var modelStore = GeminiModelStore()
    testing.wrappedValue = true
    for modelItem in modelStore.models {
        let result = await streamTestResponse(key: key, model: modelItem)
        results.wrappedValue.append(result)
    }
    testing.wrappedValue = false
}
