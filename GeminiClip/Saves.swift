import Foundation
import SwiftUI
import Combine

struct Saves: Codable, Identifiable, Equatable {
    var id = UUID()
    let title: String
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
            latestChatData = encoded
        } catch {
            print(error.localizedDescription)
        }
    }
    func loadLatest() {
        do {
            if latestChatData != Data() {
                let decoded = try decoder.decode([Message].self, from: latestChatData)
                messages = decoded
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
            chatHistoryData = encoded
        } catch {
            print(error.localizedDescription)
        }
    }
    func loadHistory() {
        do {
            let decoded = try decoder.decode([Saves].self, from: chatHistoryData)
            chatHistory = decoded
        } catch {
            print(error.localizedDescription)
        }
    }
}

struct ChatHistoryView: View {
    @EnvironmentObject var chatSaves: ChatSaves
    @State var newSaveName = ""
    var body: some View {
        NavigationStack {
            VStack {
                Text("History")
                    .fontDesign(.rounded)
                    .font(.title)
                    .bold()
                Text("Save or Restore Chats")
                    .fontDesign(.rounded)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding()
            List {
                Section("Current Chat") {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Latest Chat")
                            Text("\(chatSaves.messages.count.description) Messages")
                                .foregroundStyle(.gray)
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
                                        .foregroundStyle(.gray)
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
                        }
                        ForEach(chatSaves.chatHistory) { historyItem in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(historyItem.title)
                                    Text("\(historyItem.messages.count.description) Messages")
                                        .foregroundStyle(.gray)
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
        .onChange(of: chatSaves.chatHistory) { 
            chatSaves.saveHistory()
        }
        .onAppear {
            if chatSaves.chatHistoryData != Data() {
                chatSaves.loadHistory()
            }
        }
    }
}
