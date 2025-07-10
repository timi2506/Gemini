import SwiftUI
import GoogleGenerativeAI
import MarkdownUI
import KeychainSwift
import AsyncButton
import TipKit
import FoundationModels
import MarkdownWebView

struct ContentView: View {
    @AppStorage("Formal") var formal = false
    @State var message = ""
    @State var generationStatus: GenerationStatus = .ready
    @State var generationTask: Task<Void, Never>? = nil
    @State var wipResponse: String?
    @EnvironmentObject var chatSaves: ChatSaves
    @State var selectedModel: GeminiModel = GeminiModel(name: "Gemini 1.5 Flash", id: "gemini-1.5-flash")
    @AppStorage("aiModel") var selectedModelData: Data = Data()
    @State var model = GenerativeModel(name: "gemini-1.5-flash", apiKey: "")
    @KeychainText("apiKey", defaultValue: "") var apiKey: String
    @State var addKey = false
    @State var settings = false
    @StateObject var modelStore = GeminiModelStore()
    @State var showCodeEditor = false
    @State var code = ""
    @State var showHistory = false
    var intelligenceAvailable: Bool {
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.isAvailable
        } else {
            return false
        }
    }
    @State var selectMessage: Message?
    @State var selectSheetPlaintext = false
    var body: some View {
        VStack {
            ZStack {
                ScrollViewReader { proxy in
                    ScrollView {
                        Spacer()
                            .frame(height: 125)
                        VStack {
                            ForEach(chatSaves.messages) { messageItem in
                                messageItem
                                    .contextMenu {
                                        Button("Select Text", systemImage: "character.cursor.ibeam") {
                                            selectMessage = messageItem
                                        }
                                        Button("Copy Text", systemImage: "document.on.clipboard") {
                                            UIPasteboard.general.string = messageItem.message
                                        }
                                    }
                            }
                            
                            if let wipResponse {
                                Message(user: false, message: wipResponse)
                            }
                        }
                        .padding(.horizontal)
                        .sheet(item: $selectMessage) { message in
                            NavigationStack {
                                VStack {
                                    Picker("Display Mode", selection: Binding(get: {
                                        selectSheetPlaintext ? 1 : 0
                                    }, set: {
                                        selectSheetPlaintext = $0 == 1
                                    })) {
                                        Text("Markdown").tag(0)
                                        Text("Plain Text").tag(1)
                                    }
                                    .pickerStyle(.segmented)
                                    .padding()
                                    VStack {
                                        if selectSheetPlaintext {
                                            TextEditor(text: .constant(message.message))
                                        } else {
                                            ScrollView {
                                                MarkdownWebView(message.message)
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        Spacer()
                            .frame(height: 150)
                            .id("Bottom")
                            .onChange(of: wipResponse) {
                                withAnimation() {
                                    proxy.scrollTo("Bottom")
                                }
                            }
                            .onChange(of: chatSaves.messages) {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    withAnimation() {
                                        proxy.scrollTo("Bottom")
                                    }
                                }
                            }
                    }
                }
                VStack {
                    TextField("Message", text: $message, axis: .vertical)
                        .lineLimit(3)
                        .scrollDismissesKeyboard(.interactively)
                        .textEditorStyle(.plain)
                        .padding(10)
                    HStack {
                        Menu(content: {
                            GeminiPicker(selection: $selectedModel)
                            Button("Insert Code", systemImage: "text.redaction") {
                                showCodeEditor.toggle()
                            }
                        }) {
                            Image(systemName: "plus")
                                .bold()
                                .font(.system(size: 20))
                                .padding(5)
                        }
                        .menuStyle(.button)
                        .buttonStyle(.plain)
                        Button(action: {
                            formal.toggle()
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "eyeglasses")
                                Text("Formal")
                                    .bold()
                            }
                            .padding(7.5)
                            .foregroundStyle(formal ? Color.accentColor : Color(uiColor: .label))
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .foregroundStyle(formal ? .accentColor.opacity(0.25) : Color.gray.opacity(0.25))
                            )
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        AsyncButton(cancellationMessage: "This will stop Gemini from Generating the current Prompt, this cannot be undone", label: {
                            Image(systemName: "arrow.up")
                                .foregroundStyle(.white)
                                .bold()
                                .font(.system(size: 14))
                                .padding(7.5)
                                .background(
                                    Circle().foregroundStyle(.tint)
                                )
                        }) {
                            var message: String = ""
                            message = self.message
                            generationStatus = .generating
                            appendMessage(message, user: true)
                            wipResponse = ""
                            if selectedModel.id == "apple-intelligence" {
                                await streamIntelligenceResponse(for: generatePrompt(userPart: message), response: $wipResponse)
                            } else {
                                await streamResponse(for: generatePrompt(userPart: message), response: $wipResponse)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                appendMessage(wipResponse ?? "Unknown Response", user: false)
                                wipResponse = nil
                                generationStatus = .ready
                                if message == self.message {
                                    self.message = ""
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(generationStatus != .generating ? message.isEmpty : false)
                    }
                }
                .padding(10)
                .thinBackground()
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom)
            }
            .ignoresSafeArea(.container)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu(content: {
                        Button(action: { showHistory.toggle() }) {
                            Label("History", systemImage: "clock")
                        }
                        Button("Clear Chat", systemImage: "xmark") {
                            chatSaves.messages = []
                            chatSaves.latestChatData = Data()
                        }
                    }) {
                        Image(systemName: "clock")
                    }
                }
                ToolbarItem(placement: .title) {
                    Menu(content: {
                        Button("Settings", systemImage: "gear") {
                            settings.toggle()
                        }
                    }) {
                        HStack {
                            VStack(alignment: .center) {
                                Text(selectedModel.name)
                                    .bold()
                                HStack(spacing: 2.5) {
                                    Image(systemName: "chevron.down")
                                    Text(selectedModel.id)
                                }
                                .font(.caption)
                                .foregroundStyle(.gray)
                                .bold()
                            }
                        }
                    }
                    .popoverTip(
                        TipStruct(title: Text("Settings has moved"), message: Text("Settings is now found in the Title Menu"), image: Image(systemName: "gear"))
                    )
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink("Share Messages", item: shareMessages(chatSaves.messages))
                        .disabled(chatSaves.messages.isEmpty)
                }
            }
        }
        .sheet(isPresented: $settings) {
            settingsView
        }
        .sheet(isPresented: $addKey) {
            AddKeyView()
                .interactiveDismissDisabled(apiKey.isEmpty)
        }
        .sheet(isPresented: $showCodeEditor, onDismiss: { // early‑exit if empty
            guard !code.isEmpty else { return }
            
            // 1) show HUD
            let hudWindow = showInsertingAlert()
            
            // 2) fire off async work
            Task {
                var newText: String
                do {
                    let response = try await model.generateContent(
                        "You are part of an App, without any further comments take the following code, detect its language and put it in a markdown code block:\n\n\(code)"
                    )
                    newText = response.text ?? code
                } catch {
                    newText = code
                }
                
                // 3) once complete, update UI & dismiss
                await MainActor.run {
                    message += "\n\n" + newText
                    dismissInsertingAlert(hudWindow) {
                        
                        code = ""
                    }
                }
            }}) {
                CodeEditorView(source: $code)
                    .presentationDragIndicator(.visible)
                    .presentationDetents([.medium, .large])
                    .interactiveDismissDisabled(true)
            }
            .sheet(isPresented: $showHistory) {
                ChatHistoryView()
            }
            .onChange(of: selectedModel) {
                model = GenerativeModel(name: selectedModel.id, apiKey: apiKey)
                if let encoded = try? JSONEncoder().encode(selectedModel) {
                    selectedModelData = encoded
                }
            }
            .onChange(of: apiKey) {
                model = GenerativeModel(name: selectedModel.id, apiKey: apiKey)
            }
            .onChange(of: chatSaves.messages) {
                chatSaves.saveLatest()
            }
            .onAppear {
                if selectedModelData != Data() {
                    if let decoded = try? JSONDecoder().decode(GeminiModel.self, from: selectedModelData) {
                        selectedModel = decoded
                    }
                }
                if chatSaves.latestChatData != Data() {
                    chatSaves.loadLatest()
                }
                if apiKey.isEmpty {
                    addKey = true
                } else {
                    model = GenerativeModel(name: selectedModel.id, apiKey: apiKey)
                }
            }
    }
    @State var newModelName = ""
    @State var newModelID = ""
    @State var newModelSuccess = false
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    @StateObject var promptManager = SystemPromptManager.shared
    
    var settingsView: some View {
        NavigationStack {
            VStack {
                Text("Settings")
                    .fontDesign(.rounded)
                    .font(.title)
                    .bold()
                Text("Configure Gemini the way you like!")
                    .fontDesign(.rounded)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding()
            Form {
                Section("API Key") {
                    Button("Change API Key") {
                        settings = false
                        addKey = true
                    }
                }
                Section("Instructions") {
                    NavigationLink(destination: {
                        SystemPromptManagerView()
                    }) {
                        VStack(alignment: .leading) {
                            Text("Prompt")
                            Text(promptManager.customSystemPrompt == nil ? "Default" : "Custom")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Models") {
                    ForEach(modelStore.models) { model in
                        VStack(alignment: .leading) {
                            Text(model.name)
                            Text(model.id)
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                    .onDelete(perform: removeModel)
                    NavigationLink("Add Custom Model") {
                        VStack {
                            VStack {
                                Text("Add Custom Model")
                                    .fontDesign(.rounded)
                                    .font(.title)
                                    .bold()
                                Text("Add a Model yet not added to this App, the Model needs to be compatible with the Gemini iOS SDK")
                                    .fontDesign(.rounded)
                                    .foregroundStyle(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            Form {
                                TextField("New Models Name", text: $newModelName, onCommit: {
                                    newModelSuccess = false
                                })
                                TextField("New Models ID", text: $newModelID, onCommit: {
                                    newModelSuccess = false
                                })
                                Button("Test Model") {
                                    Task {
                                        do {
                                            let result = try await GenerativeModel(name: newModelID, apiKey: apiKey).generateContent("Hello")
                                            if let result = result.text {
                                                if !result.isEmpty {
                                                    newModelSuccess = true
                                                }
                                            } else {
                                                newModelSuccess = false
                                            }
                                        } catch {
                                            newModelSuccess = false
                                        }
                                    }
                                }
                            }
                            Button(action: {
                                modelStore.models.append(GeminiModel(name: newModelName, id: newModelID))
                            }) {
                                Text("Add Model")
                                    .foregroundColor(.white)
                                    .font(.headline)
                                    .padding()
                                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .center)
                                    .background(RoundedRectangle(cornerRadius: 15, style: .continuous)
                                        .fill(Color.accentColor))
                                    .padding(.bottom)
                            }
                            .disabled(!newModelSuccess)
                            .padding()
                        }
                    }
                    Button("Default Models") {
                        modelStore.resetModels()
                    }
                    Button(intelligenceAvailable ? "Add Apple Intelligence Model" : "Apple Intelligence is not available on this device") {
                        modelStore.models.append(
                            GeminiModel(name: "Apple Intelligence", id: "apple-intelligence")
                        )
                    }
                    .disabled(modelStore.models.contains(where: { $0.id == "apple-intelligence" }) || !intelligenceAvailable)
                }
                Section {
                    VStack(alignment: .leading) {
                        Text("Version: \(version ?? "Unknown")")
                        Text("Build: \(build ?? "Unknown")")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }
        }
    }
    func removeModel(at offsets: IndexSet) {
        modelStore.models.remove(atOffsets: offsets)
    }
    func stopGenerating() {
        generationTask?.cancel()
        generationTask = nil
        print("Generation cancelled")
    }
    func sendMessage(_ input: String? = "") {
        var message: String = ""
        if input!.isEmpty {
            message = self.message
        } else {
            message = input!
        }
        generationTask = Task {
            generationStatus = .generating
            appendMessage(message, user: true)
            wipResponse = ""
            if selectedModel.id == "apple-intelligence" {
                await streamIntelligenceResponse(for: generatePrompt(userPart: message), response: $wipResponse)
            } else {
                await streamResponse(for: generatePrompt(userPart: message), response: $wipResponse)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                appendMessage(wipResponse ?? "Unknown Response", user: false)
                generationStatus = .ready
                if message == self.message {
                    self.message = ""
                }
                wipResponse = nil
            }
        }
    }
    func streamResponse(for prompt: String, response: Binding<String?>) async {
        do {
            for try await chunk in model.generateContentStream(prompt) {
                let newText = chunk.text ?? ""
                DispatchQueue.main.async {
                    withAnimation() {
                        if response.wrappedValue == nil {
                            response.wrappedValue = newText
                        } else {
                            response.wrappedValue! += newText
                        }
                    }
                }
            }
        } catch {
            response.wrappedValue = error.localizedDescription
        }
    }
    func streamIntelligenceResponse(for prompt: String, response: Binding<String?>) async {
        do {
            if #available(iOS 26.0, *) {
                if intelligenceAvailable {
                    for try await chunk in LanguageModelSession().streamResponse(to: prompt) {
                        withAnimation() {
                            response.wrappedValue = chunk
                        }
                    }
                } else {
                    response.wrappedValue = "Apple Intelligence is not available"
                }
            } else {
                response.wrappedValue = "Apple Intelligence is only available on iOS 26 or higher on supported devices"
            }
        } catch {
            response.wrappedValue = error.localizedDescription
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
            if response == "Success" {
                return ModeltestResult(name: model.name, id: model.id, result: .success)
            } else {
                return ModeltestResult(name: model.name, id: model.id, result: .error)
            }
        } catch {
            return ModeltestResult(name: model.name, id: model.id, result: .error)
        }
    }
    func testAPIkey(key: String, results: Binding<[ModeltestResult]>, testing: Binding<Bool>) async {
        testing.wrappedValue = true
        for modelItem in modelStore.models {
            if modelItem.id != "apple-intelligence" {
                let result = await streamTestResponse(key: key, model: modelItem)
                results.wrappedValue.append(result)
            }
        }
        testing.wrappedValue = false
    }
    func appendMessage(_ message: String, user: Bool) {
        chatSaves.messages.append(Message(user: user, message: message))
    }
    func generatePrompt(userPart: String) -> String {
        var history: [HistoryItem] = []
        for messageItem in chatSaves.messages {
            let role = messageItem.user ? "user" : "ai"
            let currentMessage = messageItem.message
            let constructedHistoryItem = HistoryItem(role: role, message: currentMessage)
            history.append(constructedHistoryItem)
        }
        var encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let encoded = try? encoder.encode(history) {
            if let historyJSON = String(data: encoded, encoding: .utf8) {
                let prompt = SystemPromptManager.shared.customSystemPrompt ?? SystemPromptManager.shared.defaultSystemPrompt
                
                let systemPrompt = SystemPromptManager.shared.constructSystemPrompt(prompt, selectedModel: selectedModel.name, historyJSON: historyJSON, formal: formal)
                return systemPrompt
            }
        }
        return "None?"
    }
}

import SwiftUI

enum GenerationStatus {
    case generating
    case ready
    case error
    
    var configuration: GenerationButtonConfiguration {
        switch self {
        case .generating:
            return GenerationButtonConfiguration(imageName: "square.fill", color: .red)
        case .ready:
            return GenerationButtonConfiguration(imageName: "arrow.up", color: .accentColor)
        case .error:
            return GenerationButtonConfiguration(imageName: "exclamationmark.triangle", color: .orange)
        }
    }
}

struct GenerationButtonConfiguration {
    let imageName: String
    let color: Color
}

func shareMessages(_ messages: [Message]) -> String {
    var messagesStrings: [String] = []
    for message in messages {
        let userString = message.user ? "User" : "Gemini"
        let messageString = "**\(userString):** \(message.message)"
        messagesStrings.append(messageString)
    } 
    let finishedString = messagesStrings.joined(separator: "\n\n")
    return finishedString
}

struct Message: View, Identifiable, Equatable, Codable {
    let id = UUID()
    var user: Bool
    var message: String
    var body: some View {
        HStack {
            if user {
                Spacer()
                Markdown(message)
                    .colorScheme(.dark)
                    .foregroundStyle(.white)
                    .padding(7.5)
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .foregroundStyle(Color.accentColor)
                    )
            } else {
                Markdown(message)
                    .contentTransition(.numericText(countsDown: false))
                    .padding(7.5)
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .foregroundStyle(Color.gray.opacity(0.25))
                    )
                Spacer()
            }
        }
    }
}

struct HistoryItem: Codable {
    let role: String
    let message: String
}

import UIKit

/// Presents a basic “Inserting” alert with a spinning indicator.
/// - Returns: The UIAlertController that was shown, so you can dismiss it later.
@discardableResult
func showInsertingAlert() -> UIAlertController? {
    // 1) Find the topmost view controller
    guard let windowScene = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene }).first,
          let root = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
    else {
        print("⚠️ Could not find a window to present alert on.")
        return nil
    }
    
    // 2) Create the alert
    let alert = UIAlertController(title: "Inserting",
                                  message: "\n\n",                 // space for spinner
                                  preferredStyle: .alert)
    
    // 3) Add and center the spinner
    let spinner = UIActivityIndicatorView(style: .medium)
    spinner.translatesAutoresizingMaskIntoConstraints = false
    spinner.startAnimating()
    alert.view.addSubview(spinner)
    NSLayoutConstraint.activate([
        spinner.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
        spinner.bottomAnchor.constraint(equalTo: alert.view.bottomAnchor, constant: -20)
    ])
    
    // 4) Present it
    root.present(alert, animated: true, completion: nil)
    return alert
}

/// Dismisses the alert you got from `showInsertingAlert()`.
func dismissInsertingAlert(_ alert: UIAlertController?, completion: (() -> Void)? = nil) {
    guard let alert = alert else { return }
    alert.dismiss(animated: true, completion: completion)
}

struct TipStruct: Tip {
    var title: Text
    var message: Text?
    var image: Image?
}

extension View {
    @ViewBuilder
    func thinBackground(_ shape: some Shape = RoundedRectangle(cornerRadius: 25)) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(
                shape
                    .foregroundStyle(.ultraThinMaterial)
            )
        }
    }

}
