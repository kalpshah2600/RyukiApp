import SwiftUI

struct ContentView: View {
    @StateObject private var appVM = AppViewModel()
    @StateObject private var playerVM = PlayerViewModel()

    var body: some View {
        Group {
            switch appVM.phase {
            case .loading:
                LoadingView(message: "Starting up…")

            case .setup:
                SpotifySetupView()
                    .environmentObject(appVM)

            case .login:
                SpotifyLoginView()
                    .environmentObject(appVM)

            case .fetching:
                LoadingView(message: "Syncing your library…")

            case .ready:
                HomeView()
                    .environmentObject(appVM)
                    .environmentObject(playerVM)

            case .error(let msg):
                ErrorView(message: msg) {
                    Task { await appVM.boot() }
                }
            }
        }
        .task { await appVM.boot() }
        .onChange(of: appVM.auth.token) { _, token in
            let cid = appVM.auth.savedClientId
            guard !cid.isEmpty else { return }

            // Configure App Remote with the client ID
            playerVM.configureRemote(clientID: cid)

            guard let token else { return }
            playerVM.spotifyToken = token

            // Connect to Spotify silently.
            // If Spotify is running in background → connects immediately (no UI).
            // If not running → opens Spotify briefly once to authorize,
            //   then deep-links back here. All future plays are invisible.
            playerVM.connectOrAuthorize()
        }
        .onChange(of: appVM.phase) { _, phase in
            // Re-attempt silent reconnect when app enters ready phase
            // (e.g., after token refresh or app resume from background)
            if phase == .ready, appVM.auth.token != nil {
                playerVM.connectRemote()
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
        ) { _ in
            // Silently reconnect App Remote whenever app comes back to foreground
            if appVM.auth.token != nil {
                playerVM.connectRemote()
            }
        }
    }
}

private struct ErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ZStack {
            Color(hex: "#fdf6ec").ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 48))
                    .foregroundColor(Color(hex: "#f4a8a8"))
                Text("Something went wrong")
                    .font(.system(size: 20, weight: .bold))
                Text(message)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Button("Try again", action: retry)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Color(hex: "#1a1a1a")))
            }
        }
    }
}

#Preview { ContentView() }
