import SwiftUI
import SwiftData

@main
struct MindLogApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [UserProfile.self, CheckIn.self, ChatMessage.self])
    }
}
