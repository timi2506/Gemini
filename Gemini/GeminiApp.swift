import SwiftUI
import AsyncButton

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ChatSaves.shared)
        }
    }
}
