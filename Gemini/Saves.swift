import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers

struct Saves: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    let messages: [Message]
}

class ChatSaves: ObservableObject {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    static let shared = ChatSaves()
    @AppStorage("LatestChat", store: UserDefaults(suiteName: "group.timi2506.Gemini")) var latestChatData: Data = Data()
    @AppStorage("fullChatHistory", store: UserDefaults(suiteName: "group.timi2506.Gemini")) var chatHistoryData: Data = Data()
    @Published var messages: [Message] = []
    @Published var chatHistory: [Saves] = []
    func saveLatest() {
        do {
            let encoded = try encoder.encode(messages)
            try? encoded.write(to: ChatSaves.saveLocation.appendingPathComponent("LatestChat", conformingTo: .json), options: .atomic)
            latestChatData = encoded
        } catch {
            print(error.localizedDescription)
        }
    }
    func loadLatest() {
        do {
            do {
                let fileData = try Data(contentsOf: ChatSaves.saveLocation.appendingPathComponent("LatestChat", conformingTo: .json))
                let decoded = try decoder.decode([Message].self, from: fileData)
                messages = decoded
            } catch {
                if latestChatData != Data() {
                    let decoded = try decoder.decode([Message].self, from: latestChatData)
                    messages = decoded
                }
            }
        } catch {
            print(error.localizedDescription)
        }
    }
    func addToHistory(_ messages: [Message], title: String) {
        chatHistory.append(Saves(title: title, messages: messages))
        saveHistory()
    }
    func removeFromHistory(at offsets: IndexSet) {
        chatHistory.remove(atOffsets: offsets)
        saveHistory()
    }
    func saveHistory() {
        do {
            let encoded = try encoder.encode(chatHistory)
            try? encoded.write(to: ChatSaves.saveLocation.appendingPathComponent("ChatHistory", conformingTo: .json), options: .atomic)
            chatHistoryData = encoded
        } catch {
            print(error.localizedDescription)
        }
    }
    func loadHistory() {
        do {
            do {
                let fileData = try Data(contentsOf: ChatSaves.saveLocation.appendingPathComponent("ChatHistory", conformingTo: .json))
                let decoded = try decoder.decode([Saves].self, from: fileData)
                chatHistory = decoded
            } catch {
                let decoded = try decoder.decode([Saves].self, from: chatHistoryData)
                chatHistory = decoded
            }
        } catch {
            print(error.localizedDescription)
        }
    }
    static var saveLocation: URL {
        (FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.timi2506.Gemini") ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!).appendingPathComponent("ChatSaves", conformingTo: .folder)
    }
    func checkAndCreateFolders() {
        do {
            if !FileManager.default.fileExists(atPath: ChatSaves.saveLocation.path()) {
                try FileManager.default.createDirectory(at: ChatSaves.saveLocation, withIntermediateDirectories: true)
            }
        } catch {
            print(error.localizedDescription)
        }
    }
}

import FoundationModels
import GoogleGenerativeAI

struct ChatHistoryView: View {
    @EnvironmentObject var chatSaves: ChatSaves
    @Binding var selectedModel: GeminiModel
    @Binding var model: GenerativeModel
    @State var newSaveName = ""
    @State var searchText = ""
    var body: some View {
        NavigationStack {
            VStack {
                if searchText.isEmpty {
                    normalListView
                } else {
                    searchListView
                }
            }
            .searchable(text: $searchText)
            .toolbar {
                ToolbarItem(placement: .title) {
                    VStack {
                        Text("History")
                            .fontDesign(.rounded)
                            .font(.title)
                            .bold()
                        Text("Save or Restore Chats")
                            .fontDesign(.rounded)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
            }
        }
        .onChange(of: chatSaves.chatHistory) { 
            chatSaves.saveHistory()
        }
        .onAppear {
            if chatSaves.chatHistoryData != Data() {
                chatSaves.loadHistory()
            }
            triggerSmartRenameTask()
        }
    }
    var normalListView: some View {
        List {
            Section("Current Chat") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Latest Chat")
                        Text("\(chatSaves.messages.count.description) Messages")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    Spacer()
                    NavigationLink(" ") {
                        VStack {
                            VStack {
                                Text("Save Chat")
                                    .fontDesign(.rounded)
                                    .font(.title)
                                    .bold()
                                Text("To Save this Chat, please give it a name and then hit Save")
                                    .fontDesign(.rounded)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            Form {
                                TextField("Name of the Chat", text: $newSaveName)
                                Button("Save Chat") {
                                    chatSaves.addToHistory(chatSaves.messages, title: newSaveName)
                                    newSaveName = ""
                                }
                            }
                        }
                    }
                }
            }
            Section("Saved Chats") {
                if chatSaves.chatHistory.isEmpty {
                    Text("No Chats saved yet, try saving the Latest Chat!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(chatSaves.chatHistory) { historyItem in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(historyItem.title.isEmpty ? "Untitled Chat" : historyItem.title)
                            Text("\(historyItem.messages.count.description) Messages")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        Spacer()
                        Button("Restore") {
                            chatSaves.messages = historyItem.messages
                        }
                    }
                }
                .onDelete(perform: chatSaves.removeFromHistory)
            }
        }
    }
    var searchListView: some View {
        List {
            ForEach(chatSaves.chatHistory) { historyItem in
                if historyItem.title.lowercased().contains(searchText.lowercased()) || historyItem.messages.contains(where: { $0.message.lowercased().contains(searchText.lowercased())}) {
                    HStack {
                        VStack(alignment: .leading) {
                            chatTitleView(title: historyItem.title)
                            Text(historyItem.messages.first(where: { $0.message.lowercased().contains(searchText.lowercased()) })?.message ?? "\(historyItem.messages.count.description) Total Messages")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                        }
                        Spacer()
                        Button("Restore") {
                            chatSaves.messages = historyItem.messages
                        }
                    }
                }
            }
            .onDelete(perform: chatSaves.removeFromHistory)
        }
    }
    func chatTitleView(title: String) -> some View {
        Text(title.isEmpty ? "Untitled Chat" : title)
            .background {
                if title == "Smart Renaming..." {
                    
                }
            }
    }
    func triggerSmartRenameTask() {
        Task {
            for index in chatSaves.chatHistory.indices {
                if chatSaves.chatHistory[index].title.isEmpty {
                    chatSaves.chatHistory[index].title = "Smart Renaming..."
                    do {
                        try await smartRenameChat(for: $chatSaves.chatHistory[index])
                    } catch {
                        chatSaves.chatHistory[index].title = "Untitled Chat"
                    }
                }
            }
        }
    }
    func smartRenameChat(for chat: Binding<Saves>) async throws {
        let chatJSON = try JSONEncoder().encode(chat.wrappedValue.messages)
        let chatJSONstring = String(data: chatJSON, encoding: .utf8) ?? "Empty Chat"
        if selectedModel.id == "apple-intelligence" {
            if #available(iOS 26.0, *) {
                let newName = try await LanguageModelSession().respond(to: "You are Part of a SwiftUI AI Chat App, your purpose is to generate Names for the Chats between the User and the AI Model, make sure they're short and fitting based on the Chats Contents, the Chats contents are as follows, in a JSON: \(chatJSONstring)", generating: GeneratedChatName.self)
                DispatchQueue.main.async {
                    chat.wrappedValue.title = newName.content.newChatName
                }
            } else {
                throw CancellationError()
            }
        } else {
            let newName = try await model.generateContent("You are Part of a SwiftUI AI Chat App, your purpose is to generate Names for the Chats between the User and the AI Model, make sure they're short and fitting based on the Chats Contents, the Chats contents are as follows, in a JSON, make sure to ONLY RESPOND WITH THE NAME, no Extra Comment, no acknowledgement of this prompt, nothing - just the new name, heres the JSON: \(chatJSONstring)")
            DispatchQueue.main.async {
                chat.wrappedValue.title = newName.text ?? "Unnamed Chat"
            }
        }
    }
}

@available(iOS 26.0, *)
@Generable struct GeneratedChatName {
    @Guide(description: "A Fitting Short Name for the Chat based on it's Contents.") var newChatName: String
}
