import SwiftUI
import Combine

enum AppPhase: Equatable {
    case loading
    case setup
    case login
    case fetching
    case ready
    case error(String)
}

@MainActor
class AppViewModel: ObservableObject {
    @Published var phase: AppPhase = .loading
    @Published var tracks: [Track] = Track.mock
    @Published var recentAlbums: [RecentAlbum] = RecentAlbum.mock
    @Published var playlists: [Playlist] = Playlist.mock
    @Published var profile: SpotifyProfile?
    @Published var albumTracksCache: [String: [Track]] = [:]
    @Published var playlistTracksCache: [String: [Track]] = [:]
    @Published var isLoadingMore = false

    let auth = SpotifyAuth()

    // MARK: - Boot

    func boot() async {
        auth.loadSaved()
        guard !auth.savedClientId.isEmpty else { phase = .setup; return }

        if auth.isTokenValid || auth.hasRefreshToken {
            // Show home immediately with mock/cached data — no loading screen
            phase = .ready
            // Fetch real Spotify data entirely in the background
            Task { @MainActor [weak self] in
                guard let self else { return }
                if !auth.isTokenValid {
                    _ = await auth.refreshIfNeeded()
                }
                await loadSpotifyData()
            }
            return
        }

        phase = .login
    }

    // MARK: - Auth actions

    func saveClientId(_ id: String) {
        auth.saveClientId(id)
        phase = .login
    }

    func startLogin() async {
        do {
            try await auth.startAuth()
            phase = .fetching
            await loadSpotifyData()
        } catch SpotifyAuthError.cancelled {
            // stay on login screen
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    func disconnect() {
        auth.clearToken()
        tracks = []; recentAlbums = []; playlists = []; profile = nil
        albumTracksCache = [:]
        phase = .login
    }

    func resetToSetup() {
        auth.clearAll()
        tracks = []; recentAlbums = []; playlists = []; profile = nil
        phase = .setup
    }

    // MARK: - Data loading

    private func loadSpotifyData() async {
        guard let token = auth.token, !token.isEmpty else {
            // Only redirect to login if we aren't already showing the home screen
            if phase != .ready { phase = .login }
            return
        }

        do {
            let data = try await SpotifyAPI.fetchAll(token: token)

            // Only fall back to mock if the real fetch returned nothing at all
            tracks       = data.tracks.isEmpty       ? Track.mock        : data.tracks
            recentAlbums = data.recentAlbums.isEmpty ? RecentAlbum.mock  : data.recentAlbums
            playlists    = data.playlists.isEmpty    ? Playlist.mock     : data.playlists
            profile      = data.profile
            auth.profile = data.profile

        } catch {
            // Token error → refresh and retry once
            let refreshed = await auth.refreshIfNeeded()
            if refreshed, let newToken = auth.token {
                do {
                    let data = try await SpotifyAPI.fetchAll(token: newToken)
                    tracks       = data.tracks.isEmpty       ? Track.mock        : data.tracks
                    recentAlbums = data.recentAlbums.isEmpty ? RecentAlbum.mock  : data.recentAlbums
                    playlists    = data.playlists.isEmpty    ? Playlist.mock     : data.playlists
                    profile      = data.profile
                    auth.profile = data.profile
                } catch {
                    // Truly failed – show mock so the UI is not blank
                    tracks = Track.mock; recentAlbums = RecentAlbum.mock; playlists = Playlist.mock
                }
            } else {
                tracks = Track.mock; recentAlbums = RecentAlbum.mock; playlists = Playlist.mock
            }
        }
        phase = .ready
    }

    // MARK: - Album tracks

    func tracksForAlbum(_ album: RecentAlbum) -> [Track] {
        if let cached = albumTracksCache[album.id] { return cached }
        return tracks.filter { $0.album == album.title }
    }

    // MARK: - Playlist tracks

    func tracksForPlaylist(_ playlist: Playlist) -> [Track] {
        playlistTracksCache[playlist.id] ?? []
    }

    func loadPlaylistTracks(for playlist: Playlist) async {
        if playlistTracksCache[playlist.id] != nil { return }
        guard let token = auth.token else { return }
        do {
            let fetched = try await SpotifyAPI.fetchPlaylistTracks(
                playlistId: playlist.id, token: token)
            playlistTracksCache[playlist.id] = fetched
        } catch {
            playlistTracksCache[playlist.id] = []
        }
    }

    // MARK: - Album tracks

    func loadAlbumTracks(for album: RecentAlbum) async {
        if albumTracksCache[album.id] != nil { return }
        let local = tracks.filter { $0.album == album.title }
        if !local.isEmpty { albumTracksCache[album.id] = local; return }
        guard let token = auth.token else { return }
        do {
            let fetched = try await SpotifyAPI.fetchAlbumTracks(
                albumId: album.id, token: token,
                albumName: album.title, artistName: album.artist,
                imageURL: album.imageURL)
            albumTracksCache[album.id] = fetched.isEmpty ? [] : fetched
        } catch {
            albumTracksCache[album.id] = []
        }
    }
}
