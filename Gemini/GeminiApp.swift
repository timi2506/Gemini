import SwiftUI
import AsyncButton
import TipKit

@main
struct MyApp: App {
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
