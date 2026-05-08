import SwiftUI

struct SearchView: View {
    @EnvironmentObject var appVM: AppViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @Binding var isOpen: Bool

    @State private var query         = ""
    @State private var spotifyTracks: [Track] = []
    @State private var isSearching   = false
    @State private var isLoadingMore = false
    @State private var canLoadMore   = false
    @State private var searchError: String? = nil
    @State private var currentOffset = 0
    @State private var searchTask: Task<Void, Never>? = nil
    @FocusState private var focused: Bool

    private let pageSize = 20

    var body: some View {
        ZStack {
            Color(hex: "#fdf6ec").ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Search bar ──────────────────────────────────────────────
                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                        TextField("Search all of Spotify…", text: $query)
                            .font(.system(size: 15))
                            .focused($focused)
                            .submitLabel(.search)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onChange(of: query) { _, q in startSearch(q) }
                            .onSubmit { startSearch(query, immediate: true) }
                        if !query.isEmpty {
                            Button { query = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.07), radius: 4, y: 1)
                    )

                    Button("Cancel") {
                        withAnimation(.spring(response: 0.35)) { isOpen = false }
                    }
                    .font(.system(size: 14, weight: .semibold))
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 10)

                // ── Results ─────────────────────────────────────────────────
                if query.isEmpty {
                    // Browse mode: show liked library
                    libraryBrowseView
                } else {
                    // Active search: show Spotify catalog results
                    spotifySearchView
                }
            }
        }
        .onAppear { focused = true }
    }

    // MARK: - Browse (empty query) – liked library

    private var libraryBrowseView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hint banner
            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#1DB954"))
                Text("Type to search Spotify's full catalog of 100M+ songs")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "#1DB954").opacity(0.07))

            sectionHeader("Your Liked Songs · \(appVM.tracks.count)")

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(appVM.tracks) { track in
                        trackRow(track)
                    }
                    Color.clear.frame(height: 100)
                }
            }
        }
    }

    // MARK: - Spotify catalog search (non-empty query)

    private var spotifySearchView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack {
                if isSearching {
                    ProgressView().scaleEffect(0.75)
                    Text("Searching Spotify…")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                } else if let err = searchError {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 12))
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Button("Retry") { startSearch(query, immediate: true) }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "#1DB954"))
                } else {
                    sectionHeader("Spotify · \(spotifyTracks.count)\(canLoadMore ? "+" : "") results")
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(spotifyTracks) { track in
                        trackRow(track)
                    }

                    if !isSearching && searchError == nil && !spotifyTracks.isEmpty {
                        if canLoadMore {
                            Button {
                                loadNextPage()
                            } label: {
                                HStack(spacing: 8) {
                                    if isLoadingMore { ProgressView().scaleEffect(0.75) }
                                    Text(isLoadingMore ? "Loading…" : "Load more")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(Color(hex: "#1DB954"))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                            }
                            .disabled(isLoadingMore)
                        }
                    }

                    if !isSearching && searchError == nil && spotifyTracks.isEmpty {
                        Text("No results for \"\(query)\"")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    }

                    Color.clear.frame(height: 100)
                }
            }
        }
    }

    // MARK: - Shared track row

    private func trackRow(_ track: Track) -> some View {
        let playing = playerVM.currentTrack?.id == track.id && playerVM.isPlaying
        return Button {
            playerVM.play(track)
            withAnimation { isOpen = false }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(colors: [track.color1, track.color2],
                                            startPoint: .topLeading, endPoint: .bottomTrailing))
                    if let url = track.albumArtURL {
                        AsyncImage(url: url) { i in i.resizable().scaledToFill() }
                            placeholder: { Color.clear }
                    }
                    if playing {
                        Color.black.opacity(0.35)
                        Image(systemName: "waveform")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(playing ? track.accent : .primary)
                        .lineLimit(1)
                    Text("\(track.artist) · \(track.album)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: playing ? "waveform" : "play.circle.fill")
                    .font(.system(size: playing ? 13 : 20))
                    .foregroundColor(playing ? track.accent : Color(hex: "#1DB954").opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(playing ? track.accent.opacity(0.07) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Search logic

    private func startSearch(_ q: String, immediate: Bool = false) {
        searchTask?.cancel()
        // Keep stale results visible while new ones are loading (no empty flash)
        searchError   = nil
        canLoadMore   = false
        currentOffset = 0

        guard !q.isEmpty else {
            spotifyTracks = []
            isSearching   = false
            return
        }

        isSearching = true

        searchTask = Task { @MainActor in
            if !immediate {
                try? await Task.sleep(nanoseconds: 380_000_000)
                guard !Task.isCancelled else { return }
            }
            await fetchSpotify(query: q, offset: 0, appending: false)
        }
    }

    private func loadNextPage() {
        guard canLoadMore, !isLoadingMore else { return }
        isLoadingMore = true
        let q = query
        let next = currentOffset + pageSize
        Task { @MainActor in
            await fetchSpotify(query: q, offset: next, appending: true)
            isLoadingMore = false
        }
    }

    @MainActor
    private func fetchSpotify(query q: String, offset: Int, appending: Bool) async {
        // Silently refresh token if needed
        _ = await appVM.auth.refreshIfNeeded()

        guard let token = appVM.auth.token, !token.isEmpty else {
            searchError = "Not logged in to Spotify"
            isSearching = false
            return
        }

        do {
            let results = try await SpotifyAPI.searchTracks(
                query: q, token: token, offset: offset, limit: pageSize)

            guard !Task.isCancelled else { return }

            if appending {
                let existingIDs = Set(spotifyTracks.map { $0.id })
                spotifyTracks += results.filter { !existingIDs.contains($0.id) }
            } else {
                spotifyTracks = results
            }

            currentOffset = offset
            canLoadMore   = results.count == pageSize
            isSearching   = false
            searchError   = nil

        } catch {
            guard !Task.isCancelled else { return }

            // Retry once on any auth failure (HTTP 401 / expired token)
            let msg = error.localizedDescription
            let isAuthError = msg.contains("401") || msg.contains("token") || msg.lowercased().contains("unauthorized")
            if isAuthError {
                let refreshed = await appVM.auth.refreshIfNeeded()
                if refreshed, let newToken = appVM.auth.token, !newToken.isEmpty {
                    do {
                        let results = try await SpotifyAPI.searchTracks(
                            query: q, token: newToken, offset: offset, limit: pageSize)
                        guard !Task.isCancelled else { return }
                        if appending {
                            let existingIDs = Set(spotifyTracks.map { $0.id })
                            spotifyTracks += results.filter { !existingIDs.contains($0.id) }
                        } else {
                            spotifyTracks = results
                        }
                        currentOffset = offset
                        canLoadMore   = results.count == pageSize
                        isSearching   = false
                        searchError   = nil
                        return
                    } catch let retryError {
                        searchError = retryError.localizedDescription
                        isSearching = false
                        return
                    }
                }
            }

            searchError = error.localizedDescription
            isSearching = false
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(.caption, design: .monospaced).weight(.bold))
            .tracking(1.5)
            .foregroundColor(.secondary)
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
    }
}
