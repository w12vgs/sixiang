import SwiftUI

struct RootView: View {
    @Environment(AuthManager.self) private var auth

    var body: some View {
        Group {
            if auth.isLoggedIn {
                MainTabView()
            } else {
                AuthView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: auth.isLoggedIn)
    }
}
