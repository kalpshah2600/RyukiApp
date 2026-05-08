import Foundation
import SwiftUI

struct SpotifyAPIError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct SpotifyData {
    let tracks: [Track]
    let recentAlbums: [RecentAlbum]
    let playlists: [Playlist]
    let profile: SpotifyProfile
}

class SpotifyAPI {

    // MARK: - Aggregate fetch (resilient: sub-fetches tolerate individual failures)

    static func fetchAll(token: String) async throws -> SpotifyData {
        // Profile is required – if it fails the token is bad
        let profile = try await fetchProfile(token: token)

        // All other fetches run concurrently; individual failures return empty
        async let likedTask    = fetchLikedTracks(token: token)
        async let recentTask   = fetchRecentlyPlayed(token: token)
        async let playlistTask = fetchPlaylists(token: token)

        let liked     = (try? await likedTask)    ?? []
        let recent    = (try? await recentTask)   ?? []
        let playlists = (try? await playlistTask) ?? []

        return SpotifyData(tracks: liked, recentAlbums: recent,
                           playlists: playlists, profile: profile)
    }

    // MARK: - Profile

    static func fetchProfile(token: String) async throws -> SpotifyProfile {
        let data = try await get("https://api.spotify.com/v1/me", token: token)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SpotifyAPIError(message: "Bad profile response")
        }
        let images    = json["images"] as? [[String: Any]]
        let avatarURL = images?.first.flatMap { $0["url"] as? String }.flatMap { URL(string: $0) }
        return SpotifyProfile(
            id:          json["id"] as? String ?? "",
            displayName: json["display_name"] as? String ?? "Spotify User",
            email:       json["email"] as? String ?? "",
            avatarURL:   avatarURL)
    }

    // MARK: - Liked tracks (paginated up to 500)

    static func fetchLikedTracks(token: String) async throws -> [Track] {
        var all: [Track] = []
        var offset = 0
        let limit  = 50
        let maxTracks = 500

        repeat {
            let url  = "https://api.spotify.com/v1/me/tracks?limit=\(limit)&offset=\(offset)"
            let data = try await get(url, token: token)
            guard let json  = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = json["items"] as? [[String: Any]] else { break }
            let batch = items.compactMap { mapTrack($0["track"] as? [String: Any]) }
            all.append(contentsOf: batch)
            if batch.count < limit { break }         // last page
            offset += limit
            if all.count >= maxTracks { break }
        } while true

        return all
    }

    // MARK: - Recently played

    static func fetchRecentlyPlayed(token: String) async throws -> [RecentAlbum] {
        let data = try await get(
            "https://api.spotify.com/v1/me/player/recently-played?limit=50", token: token)
        guard let json  = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else { return [] }

        var seen = Set<String>()
        return items.compactMap { item -> RecentAlbum? in
            guard let track  = item["track"] as? [String: Any],
                  let album  = track["album"] as? [String: Any],
                  let albumId = album["id"] as? String,
                  !seen.contains(albumId) else { return nil }
            seen.insert(albumId)
            let name   = album["name"] as? String ?? "Unknown"
            let artist = (track["artists"] as? [[String: Any]])?.first?["name"] as? String ?? ""
            let imgURL = (album["images"] as? [[String: Any]])?.first
                            .flatMap { $0["url"] as? String }.flatMap { URL(string: $0) }
            let (c1, c2, _) = Color.pastelPair(seed: albumId)
            return RecentAlbum(id: albumId, title: name, artist: artist,
                               color1: c1, color2: c2, imageURL: imgURL)
        }
    }

    // MARK: - Playlists

    static func fetchPlaylists(token: String) async throws -> [Playlist] {
        let data = try await get(
            "https://api.spotify.com/v1/me/playlists?limit=50", token: token)
        guard let json  = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else { return [] }
        return items.compactMap { p -> Playlist? in
            guard let id   = p["id"] as? String,
                  let name = p["name"] as? String else { return nil }
            let tracksObj = p["tracks"] as? [String: Any]
            // total can come back as Int or Double depending on JSON parser
            let count = (tracksObj?["total"] as? Int)
                     ?? (tracksObj?["total"] as? Double).map { Int($0) }
                     ?? 0
            let imgURL = (p["images"] as? [[String: Any]])?.first
                            .flatMap { $0["url"] as? String }.flatMap { URL(string: $0) }
            let (c1, c2, _) = Color.pastelPair(seed: id)
            return Playlist(id: id, name: name, trackCount: count,
                            color1: c1, color2: c2, imageURL: imgURL)
        }
    }

    // MARK: - Album tracks

    static func fetchAlbumTracks(albumId: String, token: String,
                                  albumName: String, artistName: String,
                                  imageURL: URL?) async throws -> [Track] {
        let data = try await get(
            "https://api.spotify.com/v1/albums/\(albumId)/tracks?limit=50", token: token)
        guard let json  = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else { return [] }
        return items.compactMap { t -> Track? in
            guard let id   = t["id"] as? String,
                  let name = t["name"] as? String else { return nil }
            let artist   = (t["artists"] as? [[String: Any]])?.first?["name"] as? String ?? artistName
            let duration = ((t["duration_ms"] as? NSNumber)?.doubleValue ?? 0) / 1000
            let preview  = (t["preview_url"] as? String).flatMap { URL(string: $0) }
            let (c1, c2, accent) = Color.pastelPair(seed: id)
            return Track(id: id, title: name, artist: artist, album: albumName, duration: duration,
                         color1: c1, color2: c2, accent: accent, label: "SIDE A",
                         albumArtURL: imageURL, previewURL: preview)
        }
    }

    // MARK: - Playlist tracks

    static func fetchPlaylistTracks(playlistId: String, token: String) async throws -> [Track] {
        let data = try await get(
            "https://api.spotify.com/v1/playlists/\(playlistId)/tracks?limit=50", token: token)
        guard let json  = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else { return [] }
        return items.compactMap { mapTrack($0["track"] as? [String: Any]) }
    }

    // MARK: - Single track fetch (used to backfill album art for App Remote tracks)

    static func fetchTrack(id: String, token: String) async throws -> Track? {
        let data = try await get("https://api.spotify.com/v1/tracks/\(id)", token: token)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return mapTrack(json)
    }

    // MARK: - Search

    static func searchTracks(query: String, token: String,
                              offset: Int = 0, limit: Int = 20) async throws -> [Track] {
        let safeLimit  = max(1, min(50, limit))
        let safeOffset = max(0, offset)

        // Encode ONLY unreserved chars (RFC 3986) so & = + ? # are all escaped
        let unreserved = CharacterSet(
            charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        let encodedQ = query.addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""

        let urlStr = "https://api.spotify.com/v1/search?q=\(encodedQ)&type=track&limit=\(safeLimit)&offset=\(safeOffset)"
        guard let url = URL(string: urlStr) else {
            throw SpotifyAPIError(message: "Could not build search URL for: \(query)")
        }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token.trimmingCharacters(in: .whitespacesAndNewlines))",
                     forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            let body   = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let errMsg = (body?["error"] as? [String: Any])?["message"] as? String ?? ""
            throw SpotifyAPIError(message: "HTTP \(status)\(errMsg.isEmpty ? "" : ": \(errMsg)")")
        }
        guard let json  = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let outer = json["tracks"] as? [String: Any],
              let items = outer["items"] as? [[String: Any]] else { return [] }
        return items.compactMap { mapTrack($0) }
    }

    // MARK: - Helpers

    private static func mapTrack(_ t: [String: Any]?) -> Track? {
        guard let t,
              let id   = t["id"] as? String,
              let name = t["name"] as? String else { return nil }
        let artist   = (t["artists"] as? [[String: Any]])?.first?["name"] as? String ?? ""
        let album    = (t["album"] as? [String: Any])?["name"] as? String ?? ""
        // JSONSerialization returns duration_ms as NSNumber (int); bridge via NSNumber
        let durationMs = (t["duration_ms"] as? NSNumber)?.doubleValue ?? 0
        let duration   = durationMs / 1000
        let imgURL   = ((t["album"] as? [String: Any])?["images"] as? [[String: Any]])?.first
                          .flatMap { $0["url"] as? String }.flatMap { URL(string: $0) }
        let preview  = (t["preview_url"] as? String).flatMap { URL(string: $0) }
        let (c1, c2, accent) = Color.pastelPair(seed: id)
        return Track(id: id, title: name, artist: artist, album: album, duration: duration,
                     color1: c1, color2: c2, accent: accent, label: "SIDE A",
                     albumArtURL: imgURL, previewURL: preview)
    }

    private static func get(_ urlString: String, token: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw SpotifyAPIError(message: "Invalid URL: \(urlString)")
        }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            // Include Spotify's error description if present
            let body = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
            let spotifyMsg = (body?["error"] as? [String: Any])?["message"] as? String
                          ?? body?["error_description"] as? String
            let detail = spotifyMsg.map { ": \($0)" } ?? ""
            throw SpotifyAPIError(message: "HTTP \(status)\(detail)")
        }
        return data
    }
}
