import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appVM: AppViewModel
    @EnvironmentObject var playerVM: PlayerViewModel

    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGFloat = 0
    @State private var searchOpen = false
    @State private var selectedAlbum: RecentAlbum? = nil

    private var tracks: [Track] { appVM.tracks }
    /// The track shown in the cassette and track-info section.
    /// Always follows the player — even for album/search tracks not in the library.
    private var currentTrack: Track? {
        playerVM.currentTrack ?? (tracks.isEmpty ? nil : tracks[currentIndex])
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: "#fdf6ec"), Color(hex: "#f5e6d3"), Color(hex: "#f0d9c0")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // Ambient blobs
            ambientBlobs

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    headerRow
                    cassetteCarousel
                    trackInfo
                    recentlyPlayedSection
                    tonightsMixSection
                    Color.clear.frame(height: 120)
                }
            }

            // Player bar overlay
            VStack {
                Spacer()
                PlayerBarView(searchOpen: $searchOpen)
                    .environmentObject(playerVM)
                    .environmentObject(appVM)
            }
            .ignoresSafeArea(edges: .bottom)

            // Search overlay
            if searchOpen {
                SearchView(isOpen: $searchOpen)
                    .environmentObject(appVM)
                    .environmentObject(playerVM)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
            }

            // Spotify connecting banner – appears only during initial link
            if playerVM.isConnectingSpotify {
                VStack {
                    HStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.75)
                            .tint(.white)
                        Text("Linking Spotify…")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        Capsule().fill(Color(hex: "#1DB954").opacity(0.92))
                            .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
                    )
                    .padding(.top, 56)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.4), value: playerVM.isConnectingSpotify)
                .zIndex(5)
                .allowsHitTesting(false)
            }
        }
        .animation(.spring(response: 0.4), value: searchOpen)
        .animation(.spring(response: 0.4), value: playerVM.isConnectingSpotify)
        .sheet(item: $selectedAlbum) { album in
            AlbumDetailView(album: album)
                .environmentObject(playerVM)
                .environmentObject(appVM)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .onAppear {
            playerVM.spotifyToken = appVM.auth.token
            playerVM.load(tracks: tracks)
            if let first = tracks.first, playerVM.currentTrack == nil {
                playerVM.play(first)
            }
        }
        .onChange(of: playerVM.currentTrack) { _, newTrack in
            // Scroll carousel to the playing track if it exists in the library
            if let newTrack, let idx = tracks.firstIndex(of: newTrack) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    currentIndex = idx
                }
            }
            // If track is NOT in the library, the active cassette slot still
            // renders it via the `currentTrack` computed property above —
            // so the cassette always reflects what's playing.
        }
        .onChange(of: appVM.auth.token) { _, newToken in
            playerVM.spotifyToken = newToken
        }
        .onChange(of: tracks) { _, newTracks in
            playerVM.spotifyToken = appVM.auth.token
            playerVM.load(tracks: newTracks)
            currentIndex = 0
            // Only auto-play if nothing is currently playing (first load)
            if playerVM.currentTrack == nil, let first = newTracks.first {
                playerVM.play(first)
            }
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Good \(timeOfDay)\(appVM.profile.map { ", \($0.displayName.split(separator: " ").first.map(String.init) ?? "")" } ?? "")")
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-0.6)
            }
            Spacer()
            Button {
                withAnimation { searchOpen = true }
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(.white.opacity(0.8))
                        .shadow(color: .black.opacity(0.08), radius: 6, y: 2))
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    // MARK: - Cassette carousel

    /// Only render the cassette at currentIndex ± 2 to avoid ZStack sizing issues
    /// and performance problems with large libraries (500+ tracks).
    private var carouselWindow: [(offset: Int, element: Track)] {
        guard !tracks.isEmpty else { return [] }
        let lo = max(0, currentIndex - 2)
        let hi = min(tracks.count - 1, currentIndex + 2)
        return (lo...hi).map { (offset: $0, element: tracks[$0]) }
    }

    private var cassetteCarousel: some View {
        VStack(spacing: 14) {
            ZStack {
                ForEach(carouselWindow, id: \.element.id) { item in
                    let i = item.offset
                    let isActive = i == currentIndex
                    // Active slot always shows the currently playing track
                    let displayTrack = isActive ? (currentTrack ?? item.element) : item.element
                    let xOffset = CGFloat(i - currentIndex) * UIScreen.main.bounds.width
                    CassetteView(track: displayTrack,
                                 playing: isActive && playerVM.isPlaying,
                                 width: 300)
                        .offset(x: xOffset + dragOffset)
                        .opacity(isActive ? 1 : 0.4)
                        .scaleEffect(isActive ? 1 : 0.88)
                        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: currentIndex)
                        .animation(.interactiveSpring(), value: dragOffset)
                }
            }
            .frame(width: UIScreen.main.bounds.width, height: 210)
            .clipped()
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { v in
                        if abs(v.translation.height) < abs(v.translation.width) {
                            dragOffset = v.translation.width
                        }
                    }
                    .onEnded { v in
                        let threshold: CGFloat = 60
                        if v.translation.width < -threshold && currentIndex < tracks.count - 1 {
                            let next = currentIndex + 1
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                currentIndex = next
                            }
                            playerVM.play(tracks[next])
                        } else if v.translation.width > threshold && currentIndex > 0 {
                            let prev = currentIndex - 1
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                currentIndex = prev
                            }
                            playerVM.play(tracks[prev])
                        }
                        withAnimation { dragOffset = 0 }
                    }
            )

            // Position indicator: dots for small libraries, counter for large
            if tracks.count <= 20 {
              HStack(spacing: 6) {
                ForEach(tracks.indices, id: \.self) { i in
                    Capsule()
                        .fill(i == currentIndex
                              ? (currentTrack?.accent ?? .primary)
                              : Color.black.opacity(0.18))
                        .frame(width: i == currentIndex ? 22 : 6, height: 6)
                        .animation(.spring(response: 0.3), value: currentIndex)
                        .onTapGesture {
                            currentIndex = i
                            playerVM.play(tracks[i])
                        }
                }
              }
            } else {
                // Large library: show "n / total" counter instead of 500 dots
                Text("\(currentIndex + 1) / \(tracks.count)")
                    .font(.system(.caption2, design: .monospaced).weight(.semibold))
                    .foregroundColor(.secondary)
                    .animation(.none, value: currentIndex)
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: - Track info + play button

    private var trackInfo: some View {
        VStack(spacing: 8) {
            if let track = currentTrack {
                Text("FEATURED MIXTAPE · \(track.label)")
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .tracking(2)
                    .foregroundColor(track.accent)

                Text(track.title)
                    .font(.system(size: 22, weight: .bold))
                    .tracking(-0.4)

                Text("\(track.artist) · \(track.album)")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                Button {
                    playerVM.togglePlayPause()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text(playerVM.isPlaying ? "Pause" : "Play this side")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Color(hex: "#1a1a1a"))
                        .shadow(color: .black.opacity(0.18), radius: 10, y: 4))
                }
                .padding(.top, 6)
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: - Recently played

    private var recentlyPlayedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recently played")
                .font(.system(size: 18, weight: .bold))
                .tracking(-0.3)
                .padding(.horizontal, 22)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(appVM.recentAlbums) { album in
                        Button {
                            selectedAlbum = album
                        } label: {
                            RecentAlbumCardView(album: album)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 12)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Tonight's mix

    private var tonightsMixSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tonight's mix")
                .font(.system(size: 18, weight: .bold))
                .tracking(-0.3)
                .padding(.horizontal, 22)

            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(colors: [Color(hex: "#c8b6e2"), Color(hex: "#f4a8a8")],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Slow burn radio")
                        .font(.system(size: 15, weight: .bold))
                        .tracking(-0.2)
                    Text("Pulled from your liked songs · 1h 24m")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    if let first = tracks.first { playerVM.play(first) }
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color(hex: "#1a1a1a")))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(.white.opacity(0.65))
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 2)
            )
            .padding(.horizontal, 22)
        }
        .padding(.top, 8)
    }

    // MARK: - Ambient

    private var ambientBlobs: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(hex: "#f4a8a8").opacity(0.55), .clear],
                                    center: .center, startRadius: 0, endRadius: 120))
                .frame(width: 240, height: 240)
                .blur(radius: 20)
                .offset(x: 80, y: -100)

            Circle()
                .fill(RadialGradient(colors: [Color(hex: "#a8d5e2").opacity(0.45), .clear],
                                    center: .center, startRadius: 0, endRadius: 110))
                .frame(width: 220, height: 220)
                .blur(radius: 20)
                .offset(x: -90, y: 80)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Helpers

    private var timeOfDay: String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 12 { return "morning" }
        if h < 17 { return "afternoon" }
        return "evening"
    }

}

private struct RecentAlbumCardView: View {
    let album: RecentAlbum

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(LinearGradient(colors: [album.color1, album.color2],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: .black.opacity(0.1), radius: 10, y: 4)

                // Mini cassette label
                VStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.55))
                        .frame(height: 18)
                        .padding(.horizontal, 10)
                        .padding(.top, 12)
                        .overlay(
                            Text(album.title.uppercased())
                                .font(.system(size: 7, design: .monospaced).weight(.bold))
                                .foregroundColor(.black.opacity(0.55))
                                .padding(.horizontal, 10)
                                .padding(.top, 12)
                        )
                    Spacer()
                    // Mini tape window
                    HStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.black.opacity(0.75))
                            .frame(width: 80, height: 22)
                        Spacer()
                    }
                    .padding(.bottom, 12)
                }

                if let url = album.imageURL {
                    AsyncImage(url: url) { img in img.resizable().scaledToFill() }
                    placeholder: { Color.clear }
                }
            }
            .frame(width: 130, height: 130)
            .clipShape(RoundedRectangle(cornerRadius: 18))

            Text(album.title)
                .font(.system(size: 13, weight: .semibold))
                .tracking(-0.2)
                .lineLimit(1)
            Text(album.artist)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(width: 130)
    }
}
