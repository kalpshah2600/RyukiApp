import Foundation

/// Controls Spotify playback via the Web API Player endpoints.
/// Requires Spotify Premium. Full tracks are played through the Spotify app on the user's device.
struct SpotifyPlayerService {

    // MARK: - Smart play (device-aware)

    /// Plays a track on the best available Spotify device.
    /// Flow: get devices → prefer active/phone → transfer if needed → play.
    static func playTrack(_ track: Track, token: String) async throws {
        let devices = (try? await getDevices(token: token)) ?? []

        // Priority: active device > smartphone > computer > other
        let best = devices.first(where: { $0.isActive })
                ?? devices.first(where: { $0.type.lowercased() == "smartphone" })
                ?? devices.first(where: { $0.type.lowercased() == "computer" })
                ?? devices.first

        if let device = best {
            // Transfer playback to device (keeps it active for future calls)
            if !device.isActive {
                try? await transferPlayback(to: device.id, token: token)
                // Brief pause so Spotify registers the transfer
                try? await Task.sleep(for: .milliseconds(300))
            }
            try await playURIs([track.spotifyURI], deviceId: device.id, token: token)
        } else {
            // No devices found — try without device_id (uses last active device)
            try await playURIs([track.spotifyURI], deviceId: nil, token: token)
        }
    }

    // MARK: - Playback controls

    static func resume(token: String) async throws {
        try await put("https://api.spotify.com/v1/me/player/play", body: [:], token: token)
    }

    static func pause(token: String) async throws {
        try await put("https://api.spotify.com/v1/me/player/pause", body: nil, token: token)
    }

    static func next(token: String) async throws {
        try await post("https://api.spotify.com/v1/me/player/next", token: token)
    }

    static func previous(token: String) async throws {
        try await post("https://api.spotify.com/v1/me/player/previous", token: token)
    }

    static func seek(toMs ms: Int, token: String) async throws {
        try await put(
            "https://api.spotify.com/v1/me/player/seek?position_ms=\(ms)",
            body: nil, token: token
        )
    }

    // MARK: - Devices

    static func getDevices(token: String) async throws -> [SpotifyDevice] {
        guard let url = URL(string: "https://api.spotify.com/v1/me/player/devices") else { return [] }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let devs = json["devices"] as? [[String: Any]] else { return [] }
        return devs.compactMap { SpotifyDevice(json: $0) }
    }

    static func transferPlayback(to deviceId: String, token: String) async throws {
        try await put(
            "https://api.spotify.com/v1/me/player",
            body: ["device_ids": [deviceId], "play": false],
            token: token
        )
    }

    // MARK: - Playback state

    static func getPlaybackState(token: String) async throws -> SpotifyPlaybackState? {
        guard let url = URL(string: "https://api.spotify.com/v1/me/player") else { return nil }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }   // 204 = no active device
        return SpotifyPlaybackState(json: json)
    }

    // MARK: - Private helpers

    private static func playURIs(_ uris: [String], deviceId: String?, token: String) async throws {
        var urlStr = "https://api.spotify.com/v1/me/player/play"
        if let deviceId { urlStr += "?device_id=\(deviceId)" }
        try await put(urlStr, body: ["uris": uris], token: token)
    }

    @discardableResult
    private static func put(_ urlString: String, body: [String: Any]?, token: String) async throws -> Data {
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...204).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw SpotifyPlayerError.httpError(code)
        }
        return data
    }

    @discardableResult
    private static func post(_ urlString: String, token: String) async throws -> Data {
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...204).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw SpotifyPlayerError.httpError(code)
        }
        return data
    }
}

// MARK: - Models

struct SpotifyPlaybackState {
    let isPlaying: Bool
    let progressMs: Int
    let durationMs: Int
    let trackId: String?
    let deviceId: String?

    init?(json: [String: Any]) {
        guard let item = json["item"] as? [String: Any] else { return nil }
        self.isPlaying  = json["is_playing"] as? Bool ?? false
        self.progressMs = json["progress_ms"] as? Int ?? 0
        self.durationMs = item["duration_ms"] as? Int ?? 0
        self.trackId    = item["id"] as? String
        self.deviceId   = (json["device"] as? [String: Any])?["id"] as? String
    }
}

struct SpotifyDevice: Identifiable {
    let id: String
    let name: String
    let type: String
    let isActive: Bool
    let volumePercent: Int

    init?(json: [String: Any]) {
        guard let id = json["id"] as? String else { return nil }
        self.id            = id
        self.name          = json["name"] as? String ?? "Unknown"
        self.type          = json["type"] as? String ?? "Unknown"
        self.isActive      = json["is_active"] as? Bool ?? false
        self.volumePercent = json["volume_percent"] as? Int ?? 100
    }
}

enum SpotifyPlayerError: LocalizedError {
    case httpError(Int)
    case noDevice

    var errorDescription: String? {
        switch self {
        case .httpError(401): return "Spotify session expired. Please log in again."
        case .httpError(403): return "Spotify Premium required for full playback."
        case .httpError(404): return "No active Spotify device found. Open the Spotify app first, play anything briefly, then return here."
        case .httpError(429): return "Too many requests. Please wait a moment."
        case .httpError(let c): return "Spotify error \(c)."
        case .noDevice: return "No Spotify device available."
        }
    }
}
