import SwiftUI
import AsyncButton
import TipKit
import FoundationModels

@main
struct GeminiApp: App {
    @StateObject var themeManager = ThemeManager.shared
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
                    .tint(themeManager.accentColor)
            }
            .environmentObject(ChatSaves.shared)
            .task {
                try? Tips.configure()
            }
        }
    }
    
}
