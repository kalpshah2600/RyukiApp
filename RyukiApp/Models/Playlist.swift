import SwiftUI

struct Playlist: Identifiable {
    let id: String
    let name: String
    let trackCount: Int
    let color1: Color
    let color2: Color
    var imageURL: URL?
}

struct SpotifyProfile: Equatable {
    let id: String
    let displayName: String
    let email: String
    var avatarURL: URL?
}
