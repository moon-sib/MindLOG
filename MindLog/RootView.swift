import SwiftUI
import SwiftData

/// Если профиля ещё нет — один раз показываем знакомство, дальше всегда главный экран.
struct RootView: View {
    @Query private var profiles: [UserProfile]

    var body: some View {
        Group {
            if profiles.isEmpty {
                SetupView()
            } else {
                HomeView()
            }
        }
        .preferredColorScheme(.dark)
        .animation(.smooth, value: profiles.isEmpty)
    }
}
