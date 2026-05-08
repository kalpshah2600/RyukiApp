import SwiftUI
import Combine
import AVFoundation

private enum PlaybackMode {
    case appRemote        // full song via Spotify iOS SDK (preferred)
    case avPlayer         // 30-sec preview via AVPlayer (fallback if App Remote unavailable)
    case simulatedTimer   // no audio (mock / no preview URL)
}

@MainActor
class PlayerViewModel: ObservableObject {

    @Published var currentTrack: Track?
    @Published var isPlaying: Bool = false
    @Published var progress: Double = 0.0
    @Published var connectError: String? = nil
    @Published var isConnectingSpotify: Bool = false

    var spotifyToken: String?

    private var tracks: [Track] = []
    private var mode: PlaybackMode = .simulatedTimer

    private var audioPlayer: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var simulationTimer: AnyCancellable?

    // Position estimator for App Remote — the SDK only fires state changes on
    // events, not continuously, so we interpolate locally between callbacks.
    private var positionTimer: AnyCancellable?
    private var lastKnownPositionMs: Int = 0
    private var lastKnownPositionDate: Date = Date()

    // MARK: - Init

    init() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { print("AVAudioSession: \(error)") }

        // Wire App Remote player-state callbacks → local published state
        SpotifyAppRemoteService.shared.onPlayerStateChange = {
            [weak self] uri, trackName, artistName, posMs, playing, durationMs in
            guard let self else { return }
            self.isPlaying           = playing
            self.isConnectingSpotify = false

            // Use the real duration supplied by the SDK for accurate seeking
            let realDuration = durationMs > 0 ? Double(durationMs) / 1000.0
                                              : (self.currentTrack?.duration ?? 0)

            // Anchor the local estimator to this exact position
            self.lastKnownPositionMs   = posMs
            self.lastKnownPositionDate = Date()

            // Immediately update progress from the SDK's authoritative position
            if realDuration > 0 {
                self.progress = min(1, Double(posMs) / (realDuration * 1000.0))
            }

            // Start / stop the local estimator depending on play state
            if playing {
                self.startPositionTimer()
            } else {
                self.stopPositionTimer()
            }

            // Sync currentTrack when Spotify changes it
            let id = uri.replacingOccurrences(of: "spotify:track:", with: "")

            // Patch duration on the existing track if it was 0 (first state callback)
            if id == self.currentTrack?.id {
                if let cur = self.currentTrack, cur.duration == 0, realDuration > 0 {
                    self.currentTrack = Track(
                        id: cur.id, title: cur.title, artist: cur.artist,
                        album: cur.album, duration: realDuration,
                        color1: cur.color1, color2: cur.color2, accent: cur.accent,
                        label: cur.label, albumArtURL: cur.albumArtURL,
                        previewURL: cur.previewURL)
                }
                return
            }

            if let matched = self.tracks.first(where: { $0.id == id }) {
                let dur = matched.duration > 0 ? matched.duration : realDuration
                if dur != matched.duration {
                    self.currentTrack = Track(
                        id: matched.id, title: matched.title, artist: matched.artist,
                        album: matched.album, duration: dur,
                        color1: matched.color1, color2: matched.color2, accent: matched.accent,
                        label: matched.label, albumArtURL: matched.albumArtURL,
                        previewURL: matched.previewURL)
                } else {
                    self.currentTrack = matched
                }
            } else {
                let (c1, c2, accent) = Color.pastelPair(seed: id)
                let placeholder = Track(
                    id: id, title: trackName, artist: artistName, album: "",
                    duration: realDuration, color1: c1, color2: c2, accent: accent,
                    label: "SIDE A", albumArtURL: nil, previewURL: nil)
                self.currentTrack = placeholder

                // Backfill full metadata (album art, exact duration) from Spotify API
                Task { [weak self] in
                    guard let self, let token = self.spotifyToken, !token.isEmpty else { return }
                    if let full = try? await SpotifyAPI.fetchTrack(id: id, token: token),
                       self.currentTrack?.id == id {
                        self.currentTrack = full
                    }
                }
            }
        }
    }

    // MARK: - Library

    func load(tracks: [Track]) {
        self.tracks = tracks
        if currentTrack == nil { currentTrack = tracks.first }
    }

    func configureRemote(clientID: String) {
        SpotifyAppRemoteService.shared.configure(clientID: clientID)
    }

    func connectRemote() {
        guard let token = spotifyToken else { return }
        SpotifyAppRemoteService.shared.reconnect(token: token)
    }

    func connectOrAuthorize() {
        guard let token = spotifyToken else { return }
        SpotifyAppRemoteService.shared.connectOrAuthorize(token: token)
    }

    // MARK: - Play

    func play(_ track: Track) {
        currentTrack = track
        progress     = 0
        isPlaying    = true
        connectError = nil
        stopAll()

        // Reset estimator for new track
        lastKnownPositionMs   = 0
        lastKnownPositionDate = Date()

        let remote = SpotifyAppRemoteService.shared

        if remote.isConnected {
            remote.play(uri: track.spotifyURI)
            mode = .appRemote
            isConnectingSpotify = false
            startPositionTimer()
        } else {
            Task {
                isConnectingSpotify = true
                if let token = spotifyToken {
                    let connected = await remote.tryConnect(token: token)
                    if connected {
                        remote.play(uri: track.spotifyURI)
                        mode = .appRemote
                        isConnectingSpotify = false
                        self.startPositionTimer()
                        return
                    }
                }
                remote.play(uri: track.spotifyURI)
                mode = .appRemote
                self.startPositionTimer()
            }
        }
    }

    // MARK: - Controls

    func togglePlayPause() {
        isPlaying.toggle()
        switch mode {
        case .appRemote:
            if isPlaying {
                SpotifyAppRemoteService.shared.resume()
                lastKnownPositionDate = Date()  // restart estimator clock
                startPositionTimer()
            } else {
                SpotifyAppRemoteService.shared.pause()
                stopPositionTimer()
            }
        case .avPlayer:
            isPlaying ? audioPlayer?.play() : audioPlayer?.pause()
        case .simulatedTimer:
            isPlaying ? startSimulationTimer() : stopSimulationTimer()
        }
    }

    func next() {
        nextInLibrary()
    }

    func previous() {
        prevInLibrary()
    }

    func scrub(to fraction: Double) {
        progress = max(0, min(1, fraction))
        switch mode {
        case .appRemote:
            if let dur = currentTrack?.duration {
                let ms = Int(fraction * dur * 1000)
                SpotifyAppRemoteService.shared.seek(toMs: ms)
                // Anchor estimator to the scrubbed position immediately
                lastKnownPositionMs   = ms
                lastKnownPositionDate = Date()
            }
        case .avPlayer:
            if let dur = currentTrack?.duration {
                audioPlayer?.seek(to: CMTime(seconds: fraction * dur, preferredTimescale: 1000))
            }
        case .simulatedTimer: break
        }
    }

    // MARK: - App Remote position estimator
    //
    // The Spotify SDK fires playerStateDidChange only on events (play/pause/seek/
    // track-change), NOT on a continuous clock. This timer interpolates position
    // locally between SDK callbacks so the seeker always moves smoothly.

    private func startPositionTimer() {
        stopPositionTimer()
        positionTimer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self,
                          self.mode == .appRemote,
                          self.isPlaying,
                          let dur = self.currentTrack?.duration, dur > 0 else { return }

                    let elapsed = Date().timeIntervalSince(self.lastKnownPositionDate)
                    let estimatedMs = self.lastKnownPositionMs + Int(elapsed * 1000)
                    let newProgress = min(1.0, Double(estimatedMs) / (dur * 1000.0))
                    self.progress = newProgress

                    if newProgress >= 1.0 { self.nextInLibrary() }
                }
            }
    }

    private func stopPositionTimer() {
        positionTimer?.cancel()
        positionTimer = nil
    }

    // MARK: - AVPlayer (30-sec preview fallback)

    private func startAVPlayer(url: URL) {
        mode = .avPlayer
        clearAVObservers()
        let item = AVPlayerItem(url: url)
        if audioPlayer == nil { audioPlayer = AVPlayer(playerItem: item) }
        else                  { audioPlayer?.replaceCurrentItem(with: item) }
        audioPlayer?.play()
        attachAVObservers()
    }

    private func attachAVObservers() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = audioPlayer?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self, self.mode == .avPlayer,
                      let dur = self.currentTrack?.duration, dur > 0 else { return }
                self.progress = time.seconds / dur
            }
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: audioPlayer?.currentItem,
            queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.nextInLibrary() }
        }
    }

    // MARK: - Simulation timer

    private func startSimulationTimer() {
        stopSimulationTimer()
        mode = .simulatedTimer
        simulationTimer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, let track = self.currentTrack else { return }
                    self.progress = min(1.0, self.progress + 0.5 / max(track.duration, 1))
                    if self.progress >= 1.0 { self.nextInLibrary() }
                }
            }
    }

    // MARK: - Stop helpers

    private func stopAll() {
        stopPositionTimer()
        stopSimulationTimer()
        clearAVObservers()
        audioPlayer?.pause()
    }
    private func stopSimulationTimer() { simulationTimer?.cancel(); simulationTimer = nil }
    private func clearAVObservers() {
        if let o = timeObserver { audioPlayer?.removeTimeObserver(o); timeObserver = nil }
        if let o = endObserver  { NotificationCenter.default.removeObserver(o); endObserver = nil }
    }
    private func nextInLibrary() {
        guard let c = currentTrack, !tracks.isEmpty, let i = tracks.firstIndex(of: c) else { return }
        play(tracks[(i + 1) % tracks.count])
    }
    private func prevInLibrary() {
        guard let c = currentTrack, !tracks.isEmpty, let i = tracks.firstIndex(of: c) else { return }
        play(tracks[(i - 1 + tracks.count) % tracks.count])
    }

    deinit {
        if let o = timeObserver { audioPlayer?.removeTimeObserver(o) }
        if let o = endObserver  { NotificationCenter.default.removeObserver(o) }
        audioPlayer?.pause()
    }
}
