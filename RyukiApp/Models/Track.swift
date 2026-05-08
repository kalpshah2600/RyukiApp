import SwiftUI

struct Track: Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let color1: Color
    let color2: Color
    let accent: Color
    let label: String
    var albumArtURL: URL?
    var previewURL: URL?

    var spotifyURI: String { "spotify:track:\(id)" }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Track, rhs: Track) -> Bool { lhs.id == rhs.id }

    var durationFormatted: String {
        let m = Int(duration) / 60
        let s = Int(duration) % 60
        return String(format: "%d:%02d", m, s)
    }
}

struct RecentAlbum: Identifiable {
    let id: String
    let title: String
    let artist: String
    let color1: Color
    let color2: Color
    var imageURL: URL?
}
