import SwiftUI

private enum BarState { case collapsed, expanded }

struct PlayerBarView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appVM: AppViewModel
    @Binding var searchOpen: Bool

    @State private var barState: BarState = .collapsed
    @State private var dragOffset: CGFloat = 0
    @State private var selectedTab: Int = 0
    @State private var selectedPlaylist: Playlist? = nil

    private let collapsedH: CGFloat = 86
    private let expandedH: CGFloat  = UIScreen.main.bounds.height * 0.72

    // Height that tracks both resting state and live drag
    private var sheetHeight: CGFloat {
        let base = barState == .expanded ? expandedH : collapsedH
        let delta = barState == .expanded ? max(0, dragOffset) : min(0, dragOffset)
        return max(collapsedH, min(expandedH, base - delta))
    }

    // 0 = fully collapsed, 1 = fully expanded
    private var revealProgress: CGFloat {
        let span = expandedH - collapsedH
        guard span > 0 else { return barState == .expanded ? 1 : 0 }
        return max(0, min(1, (sheetHeight - collapsedH) / span))
    }

    // Derived animation values
    private var miniOpacity: Double       { Double(max(0, 1 - revealProgress * 5)) }
    // Fades in from 50 % open → 100 %, and out from 50 % → 0 % — content gone in first half of collapse
    private var expandedOpacity: Double   { Double(max(0, min(1, (revealProgress - 0.5) / 0.5))) }
    private var expandedSlideDown: CGFloat { max(0, (1 - revealProgress) * 52) }

    // Pan gesture — @State dragOffset so reset + barState change happen in the same
    // withAnimation call, eliminating the one-frame flash caused by @GestureState
    // auto-resetting before the state transition fires.
    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                dragOffset = value.translation.height
            }
            .onEnded { value in
                // Use velocity prediction for a flick-to-open/close feel
                let vel = value.predictedEndTranslation.height
                let dist = value.translation.height
                let threshold: CGFloat = 44
                withAnimation(.spring(response: 0.36, dampingFraction: 0.72, blendDuration: 0.08)) {
                    if barState == .collapsed && (dist < -threshold || vel < -threshold) {
                        barState = .expanded
                    } else if barState == .expanded && (dist > threshold || vel > threshold) {
                        barState = .collapsed
                    }
                    dragOffset = 0
                }
            }
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Background
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color(hex: "#fdf6ec").opacity(0.5))
                )

            VStack(spacing: 0) {
                // Drag handle — always tappable to toggle
                DragHandle()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                            barState = barState == .collapsed ? .expanded : .collapsed
                        }
                    }

                // Content layers — both always in hierarchy, revealed progressively
                ZStack(alignment: .top) {
                    // Mini player fades away as the sheet rises
                    miniPlayer
                        .opacity(miniOpacity)
                        .allowsHitTesting(revealProgress < 0.35)

                    // Expanded content slides up and fades in as the sheet rises
                    if revealProgress > 0.42 {
                        expandedContent
                            .opacity(expandedOpacity)
                            .offset(y: expandedSlideDown)
                            .allowsHitTesting(revealProgress >= 0.5)
                    }
                }
            }
        }
        .frame(height: sheetHeight, alignment: .top)
        // Tight interactiveSpring keeps height glued to the finger during drag.
        // withAnimation in onEnded overrides this for the snappy release.
        .animation(.interactiveSpring(response: 0.14, dampingFraction: 0.88, blendDuration: 0.04),
                   value: dragOffset)
        .animation(.spring(response: 0.36, dampingFraction: 0.72, blendDuration: 0.08),
                   value: barState)
        .contentShape(Rectangle())
        .gesture(panGesture)
        .shadow(color: .black.opacity(0.12), radius: 24, y: -4)
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    // MARK: - Mini player

    private var miniPlayer: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(colors: [playerVM.currentTrack?.color1 ?? .gray,
                                                  playerVM.currentTrack?.color2 ?? .gray],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                if let url = playerVM.currentTrack?.albumArtURL {
                    AsyncImage(url: url) { img in img.resizable().scaledToFill() }
                    placeholder: { Color.clear }
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(playerVM.currentTrack?.title ?? "No track")
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text(playerVM.currentTrack?.artist ?? "")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()

            HStack(spacing: 8) {
                Button { playerVM.previous() } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.primary)
                }
                Button { playerVM.togglePlayPause() } label: {
                    Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.primary)
                }
                Button { playerVM.next() } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 24)
    }

    // MARK: - Expanded

    private var expandedContent: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                if let track = playerVM.currentTrack {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(LinearGradient(colors: [track.color1, track.color2],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                            if let url = track.albumArtURL {
                                AsyncImage(url: url) { img in img.resizable().scaledToFill() }
                                placeholder: { Color.clear }
                            }
                        }
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(track.title)
                                .font(.system(size: 16, weight: .bold))
                                .lineLimit(1)
                            Text("\(track.artist) · \(track.album)")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                    }

                    WaveformView(
                        progress: playerVM.progress,
                        accent: track.accent,
                        seed: track.id,
                        onScrub: { playerVM.scrub(to: $0) }
                    )
                    .frame(height: 40)

                    HStack {
                        Text(timeString(playerVM.progress * track.duration))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(track.durationFormatted)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }

                TransportButtonsView(
                    playing: playerVM.isPlaying,
                    onPlayPause: { playerVM.togglePlayPause() },
                    onPrev: { playerVM.previous() },
                    onNext: { playerVM.next() }
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            Divider().opacity(0.3)

            HStack(spacing: 0) {
                ForEach(["Library", "Playlists"].indices, id: \.self) { i in
                    Button {
                        withAnimation(.spring(response: 0.3)) { selectedTab = i }
                    } label: {
                        VStack(spacing: 4) {
                            Text(["Library", "Playlists"][i])
                                .font(.system(size: 13, weight: selectedTab == i ? .bold : .regular))
                                .foregroundColor(selectedTab == i ? .primary : .secondary)
                            Capsule()
                                .fill(selectedTab == i ? Color.primary : Color.clear)
                                .frame(height: 2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                }
            }
            .padding(.horizontal, 20)

            ScrollView {
                if selectedTab == 0 {
                    libraryTab
                } else {
                    playlistsTab
                }
            }
            .background(Color(hex: "#fdf6ec").opacity(0.6))
        }
    }

    private var libraryTab: some View {
        LazyVStack(spacing: 0) {
            ForEach(appVM.tracks) { track in
                Button {
                    playerVM.play(track)
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                        barState = .collapsed
                    }
                } label: {
                    TrackRowView(track: track, isPlaying: playerVM.currentTrack == track && playerVM.isPlaying)
                }
                .buttonStyle(.plain)
                Divider().opacity(0.25).padding(.leading, 74)
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 40)
    }

    private var playlistsTab: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(appVM.playlists) { playlist in
                Button {
                    selectedPlaylist = playlist
                } label: {
                    PlaylistCardView(playlist: playlist)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .padding(.bottom, 40)
        .sheet(item: $selectedPlaylist) { playlist in
            PlaylistDetailView(playlist: playlist)
                .environmentObject(playerVM)
                .environmentObject(appVM)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
    }

    private func timeString(_ t: Double) -> String {
        let s = Int(max(0, t))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

private struct DragHandle: View {
    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.black.opacity(0.2))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

struct TrackRowView: View {
    let track: Track
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: [track.color1, track.color2],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                if let url = track.albumArtURL {
                    AsyncImage(url: url) { img in img.resizable().scaledToFill() }
                    placeholder: { Color.clear }
                }
                if isPlaying {
                    Color.black.opacity(0.35)
                    Image(systemName: "waveform")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isPlaying ? track.accent : .primary)
                    .lineLimit(1)
                Text("\(track.artist) · \(track.durationFormatted)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(isPlaying ? track.accent.opacity(0.15) : Color(hex: "#fdf6ec"))
    }
}

struct PlaylistCardView: View {
    let playlist: Playlist

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(colors: [playlist.color1, playlist.color2],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                if let url = playlist.imageURL {
                    AsyncImage(url: url) { img in img.resizable().scaledToFill() }
                    placeholder: { Color.clear }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 6, y: 3)

            Text(playlist.name)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            Text("\(playlist.trackCount) tracks")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
}

struct TransportButtonsView: View {
    let playing: Bool
    let onPlayPause: () -> Void
    let onPrev: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onPrev) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.primary)
                    .frame(width: 52, height: 52)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.85)))
                    .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
            }

            Button(action: onPlayPause) {
                Image(systemName: playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 64, height: 64)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color(hex: "#1a1a1a")))
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
            }

            Button(action: onNext) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.primary)
                    .frame(width: 52, height: 52)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.85)))
                    .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
            }
        }
    }
}
