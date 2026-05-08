import SwiftUI

@main
struct RyukiApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
                .onOpenURL { url in
                    // Hand the callback URL to App Remote (Spotify iOS SDK)
                    // and to the PKCE auth flow via SpotifyAuth.
                    _ = SpotifyAppRemoteService.shared.handleURL(url)
                }
        }
    }
}
