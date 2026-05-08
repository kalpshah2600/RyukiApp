import SwiftUI

struct AlbumDetailView: View {
    let album: RecentAlbum
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appVM: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var albumTracks: [Track] = []
    @State private var isLoading = true

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [album.color1.opacity(0.25), Color(hex: "#fdf6ec")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                albumHeader

                Divider().opacity(0.25).padding(.horizontal, 20)

                // Track list
                if isLoading {
                    Spacer()
                    ProgressView()
                        .tint(album.color1)
                    Spacer()
                } else if albumTracks.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary)
                        Text("No tracks found")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(albumTracks.enumerated()), id: \.element.id) { idx, track in
                                AlbumTrackRowView(
                                    track: track,
                                    trackNumber: idx + 1,
                                    isPlaying: playerVM.currentTrack == track && playerVM.isPlaying,
                                    accent: album.color1
                                )
                                .onTapGesture {
                                    playerVM.play(track)
                                    dismiss()
                                }

                                if idx < albumTracks.count - 1 {
                                    Divider()
                                        .padding(.leading, 70)
                                        .opacity(0.15)
                                }
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .task {
            await loadTracks()
        }
    }

    private var albumHeader: some View {
        HStack(spacing: 16) {
            // Album art
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(colors: [album.color1, album.color2],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: album.color1.opacity(0.4), radius: 10, y: 4)

                // Mini cassette label stripe
                VStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.5))
                        .frame(height: 14)
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                    Spacer()
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.black.opacity(0.7))
                        .frame(height: 18)
                        .padding(.horizontal, 6)
                        .padding(.bottom, 8)
                }

                if let url = album.imageURL {
                    AsyncImage(url: url) { img in img.resizable().scaledToFill() }
                    placeholder: { Color.clear }
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 4) {
                Text(album.title)
                    .font(.system(size: 18, weight: .bold))
                    .tracking(-0.4)
                    .lineLimit(2)
                Text(album.artist)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                if !albumTracks.isEmpty {
                    Text("\(albumTracks.count) tracks")
                        .font(.system(size: 11, design: .monospaced).weight(.semibold))
                        .foregroundColor(album.color1.opacity(0.8))
                        .padding(.top, 2)
                }
            }

            Spacer()

            // Play all button
            if !albumTracks.isEmpty {
                Button {
                    if let first = albumTracks.first { playerVM.play(first) }
                    dismiss()
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 42, height: 42)
                        .background(
                            Circle()
                                .fill(LinearGradient(colors: [album.color1, album.color2],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                .shadow(color: album.color1.opacity(0.5), radius: 8, y: 3)
                        )
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    private func loadTracks() async {
        isLoading = true
        await appVM.loadAlbumTracks(for: album)
        albumTracks = appVM.tracksForAlbum(album)
        isLoading = false
    }
}

private struct AlbumTrackRowView: View {
    let track: Track
    let trackNumber: Int
    let isPlaying: Bool
    let accent: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                if isPlaying {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(accent.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "waveform")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(accent)
                } else {
                    Text("\(trackNumber)")
                        .font(.system(size: 14, design: .monospaced).weight(.semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 40)
                }
            }
            .frame(width: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isPlaying ? accent : .primary)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(track.durationFormatted)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(isPlaying ? accent.opacity(0.06) : Color.clear)
        .contentShape(Rectangle())
    }
}
