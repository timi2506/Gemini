import SwiftUI
import AsyncButton
import TipKit
import FoundationModels

@main
struct MyApp: App {
    var intelligenceAvailable: Bool {
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.isAvailable
        } else {
            return false
        }
    }
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView()
            }
            .environmentObject(ChatSaves.shared)
            .task {
                try? Tips.configure()
            }
        }
    }
}
