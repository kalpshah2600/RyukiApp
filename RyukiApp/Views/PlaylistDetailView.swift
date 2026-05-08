import SwiftUI

struct PlaylistDetailView: View {
    let playlist: Playlist
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appVM: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var tracks: [Track] = []
    @State private var isLoading = true

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [playlist.color1.opacity(0.25), Color(hex: "#fdf6ec")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(LinearGradient(colors: [playlist.color1, playlist.color2],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .shadow(color: playlist.color1.opacity(0.4), radius: 10, y: 4)
                        if let url = playlist.imageURL {
                            AsyncImage(url: url) { img in img.resizable().scaledToFill() }
                                placeholder: { Color.clear }
                        } else {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 28))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(playlist.name)
                            .font(.system(size: 18, weight: .bold))
                            .tracking(-0.4)
                            .lineLimit(2)
                        Text(isLoading ? "Loading…" : "\(tracks.count) tracks")
                            .font(.system(size: 12, design: .monospaced).weight(.semibold))
                            .foregroundColor(playlist.color1.opacity(0.8))
                    }

                    Spacer()

                    if !tracks.isEmpty {
                        Button {
                            if let first = tracks.first { playerVM.play(first) }
                            dismiss()
                        } label: {
                            Image(systemName: "play.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 42, height: 42)
                                .background(
                                    Circle()
                                        .fill(LinearGradient(colors: [playlist.color1, playlist.color2],
                                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .shadow(color: playlist.color1.opacity(0.5), radius: 8, y: 3)
                                )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                Divider().opacity(0.25).padding(.horizontal, 20)

                if isLoading {
                    Spacer()
                    ProgressView().tint(playlist.color1)
                    Spacer()
                } else if tracks.isEmpty {
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
                            ForEach(Array(tracks.enumerated()), id: \.element.id) { idx, track in
                                let playing = playerVM.currentTrack?.id == track.id && playerVM.isPlaying
                                HStack(spacing: 14) {
                                    ZStack {
                                        if playing {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(playlist.color1.opacity(0.15))
                                                .frame(width: 40, height: 40)
                                            Image(systemName: "waveform")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(playlist.color1)
                                        } else {
                                            Text("\(idx + 1)")
                                                .font(.system(size: 14, design: .monospaced).weight(.semibold))
                                                .foregroundColor(.secondary)
                                                .frame(width: 40)
                                        }
                                    }
                                    .frame(width: 40)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(track.title)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(playing ? playlist.color1 : .primary)
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
                                .background(playing ? playlist.color1.opacity(0.06) : Color.clear)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    playerVM.play(track)
                                    dismiss()
                                }

                                if idx < tracks.count - 1 {
                                    Divider().padding(.leading, 70).opacity(0.15)
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
            isLoading = true
            await appVM.loadPlaylistTracks(for: playlist)
            tracks = appVM.tracksForPlaylist(playlist)
            isLoading = false
        }
    }
}
