import Foundation
import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// SpotifyAppRemoteService  –  Full-song playback via Spotify iOS SDK
//
// Flow:
//   SETUP (once, during/after login):
//     connectOrAuthorize() → checks if Spotify is running
//       ┣ Running   → appRemote.connect()  (silent, user stays in Ryuki)
//       ┗ Not running → authorizeAndPlayURI("") (Spotify opens ~0.5s, no song
//                        plays, redirects back via ryuki://callback)
//
//   PLAYBACK (every time user taps a song):
//     play(uri:) → appRemote is already connected → playerAPI.play(uri)
//                   Spotify stays invisible in background. Full song plays.
// ─────────────────────────────────────────────────────────────────────────────

#if canImport(SpotifyiOS)
import SpotifyiOS

@MainActor
final class SpotifyAppRemoteService: NSObject, ObservableObject {

    static let shared = SpotifyAppRemoteService()

    @Published var isConnected   = false
    @Published var isConnecting  = false
    @Published var errorMessage: String?

    /// Called whenever Spotify reports a player-state change.
    /// Parameters: (trackURI, trackName, artistName, positionMs, isPlaying, durationMs)
    var onPlayerStateChange: ((String, String, String, Int, Bool, Int) -> Void)?

    private var appRemote: SPTAppRemote?
    private var pendingURI: String?

    // Set to true when connectOrAuthorize() triggers a connect attempt so that
    // if the silent connect fails we know to call authorizeAndPlayURI("").
    private var pendingSetupAuthorization = false

    // Continuation used by tryConnect(token:) to await connection result
    private var connectionContinuation: CheckedContinuation<Bool, Never>?
    private var connectionTimeoutTask: Task<Void, Never>?

    // MARK: - Configure

    func configure(clientID: String) {
        guard appRemote == nil else { return }
        let cfg = SPTConfiguration(clientID: clientID,
                                   redirectURL: URL(string: "ryuki://callback")!)
        let remote = SPTAppRemote(configuration: cfg, logLevel: .none)
        remote.delegate = self
        appRemote = remote
    }

    // MARK: - Setup: connect or authorize once

    /// Call this right after the user logs in.
    /// Tries a silent `connect()` first. If Spotify isn't running, the
    /// delegate `didFailConnectionAttemptWithError` fires and we fall back to
    /// `authorizeAndPlayURI("")` — which opens Spotify for ~0.5 s to grant
    /// permission, then deep-links straight back to Ryuki. No song plays.
    /// After this one-time setup all future plays are fully invisible.
    func connectOrAuthorize(token: String) {
        guard let remote = appRemote, !remote.isConnected, !isConnecting else { return }
        isConnecting = true
        pendingSetupAuthorization = true
        remote.connectionParameters.accessToken = token
        remote.connect()
    }

    // MARK: - Async silent connect (used before each play attempt)

    /// Tries to connect silently. Returns true if connected within timeout.
    func tryConnect(token: String) async -> Bool {
        guard let remote = appRemote else { return false }
        if remote.isConnected { return true }

        remote.connectionParameters.accessToken = token
        isConnecting = true

        return await withCheckedContinuation { continuation in
            // Cancel any existing continuation first
            connectionContinuation?.resume(returning: false)
            connectionContinuation = continuation

            remote.connect()

            // 4-second timeout
            connectionTimeoutTask?.cancel()
            connectionTimeoutTask = Task {
                try? await Task.sleep(for: .seconds(4))
                await MainActor.run {
                    if let cont = self.connectionContinuation {
                        self.connectionContinuation = nil
                        self.isConnecting = false
                        cont.resume(returning: false)
                    }
                }
            }
        }
    }

    // MARK: - Playback

    func play(uri: String) {
        guard let remote = appRemote else {
            errorMessage = "App Remote not configured – call configure(clientID:) first"
            return
        }
        if remote.isConnected {
            remote.playerAPI?.play(uri) { [weak self] _, err in
                if let e = err {
                    Task { @MainActor in self?.errorMessage = e.localizedDescription }
                }
            }
        } else {
            // Store URI; will play once connection is established via
            // authorizeAndPlayURI redirect → handleURL → connect → delegate
            pendingURI = uri
            remote.authorizeAndPlayURI(uri)
        }
    }

    // Reconnect silently after app resumes (does NOT open Spotify)
    func reconnect(token: String) {
        guard let remote = appRemote, !remote.isConnected else { return }
        remote.connectionParameters.accessToken = token
        remote.connect()
    }

    func disconnect() {
        appRemote?.disconnect()
        isConnected = false
    }

    // Handle ryuki://callback URL from Spotify
    @discardableResult
    func handleURL(_ url: URL) -> Bool {
        guard let remote = appRemote else { return false }
        let params = remote.authorizationParameters(from: url)
        if let token = params?[SPTAppRemoteAccessTokenKey] {
            remote.connectionParameters.accessToken = token
            remote.connect()
            return true
        }
        if let err = params?[SPTAppRemoteErrorDescriptionKey] {
            Task { @MainActor in self.errorMessage = err }
        }
        return false
    }

    // MARK: - Playback controls

    func resume()    { appRemote?.playerAPI?.resume(nil) }
    func pause()     { appRemote?.playerAPI?.pause(nil) }
    func next()      { appRemote?.playerAPI?.skip(toNext: nil) }
    func previous()  { appRemote?.playerAPI?.skip(toPrevious: nil) }
    func seek(toMs ms: Int) { appRemote?.playerAPI?.seek(toPosition: ms, callback: nil) }
}

// MARK: – SPTAppRemoteDelegate

extension SpotifyAppRemoteService: SPTAppRemoteDelegate {
    nonisolated func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        Task { @MainActor in
            self.isConnected              = true
            self.isConnecting             = false
            self.pendingSetupAuthorization = false
            self.errorMessage             = nil
            appRemote.playerAPI?.delegate = self
            appRemote.playerAPI?.subscribe(toPlayerState: { _, _ in })

            // Resume any continuation waiting for connection
            if let cont = self.connectionContinuation {
                self.connectionContinuation = nil
                self.connectionTimeoutTask?.cancel()
                cont.resume(returning: true)
            }

            // Play any URI that was queued while we were connecting
            if let uri = self.pendingURI {
                self.pendingURI = nil
                appRemote.playerAPI?.play(uri, callback: nil)
            }
        }
    }

    nonisolated func appRemote(_ appRemote: SPTAppRemote,
                                didDisconnectWithError error: Error?) {
        Task { @MainActor in
            self.isConnected  = false
            self.isConnecting = false
        }
    }

    nonisolated func appRemote(_ appRemote: SPTAppRemote,
                                didFailConnectionAttemptWithError error: Error?) {
        Task { @MainActor in
            self.isConnected  = false
            self.isConnecting = false

            // Resume continuation with failure
            if let cont = self.connectionContinuation {
                self.connectionContinuation = nil
                self.connectionTimeoutTask?.cancel()
                cont.resume(returning: false)
            }

            // If this was the one-time setup attempt and Spotify wasn't running,
            // open Spotify briefly (no playback) to grant App Remote permission.
            if self.pendingSetupAuthorization {
                self.pendingSetupAuthorization = false
                appRemote.authorizeAndPlayURI("")
            } else {
                self.errorMessage = error?.localizedDescription ?? "Spotify connection failed"
            }
        }
    }
}

// MARK: – SPTAppRemotePlayerStateDelegate

extension SpotifyAppRemoteService: SPTAppRemotePlayerStateDelegate {
    nonisolated func playerStateDidChange(_ state: SPTAppRemotePlayerState) {
        let uri        = state.track.uri
        let trackName  = state.track.name
        let artistName = state.track.artist.name
        let pos        = Int(state.playbackPosition)
        let playing    = !state.isPaused
        let durationMs = Int(state.track.duration)   // ms — always present in SDK
        Task { @MainActor in
            self.onPlayerStateChange?(uri, trackName, artistName, pos, playing, durationMs)
        }
    }
}

#else
// ─── Stub when SpotifyiOS.xcframework is not linked ──────────────────────────
@MainActor
final class SpotifyAppRemoteService: NSObject, ObservableObject {
    static let shared = SpotifyAppRemoteService()
    @Published var isConnected   = false
    @Published var isConnecting  = false
    @Published var errorMessage: String?
    var onPlayerStateChange: ((String, String, String, Int, Bool, Int) -> Void)?
    func configure(clientID: String) {}
    func connectOrAuthorize(token: String) {}
    func tryConnect(token: String) async -> Bool { return false }
    func play(uri: String)           {}
    func reconnect(token: String)    {}
    func disconnect()                {}
    @discardableResult
    func handleURL(_ url: URL) -> Bool { return false }
    func resume()           {}
    func pause()            {}
    func next()             {}
    func previous()         {}
    func seek(toMs ms: Int) {}
}
#endif
