import SwiftUI

extension Track {
    static let mock: [Track] = [
        Track(id: "t1", title: "Pastel Skies",   artist: "Marina Vega",    album: "Soft Hours",       duration: 218, color1: Color(hex: "#f4a8a8"), color2: Color(hex: "#f5c6c6"), accent: Color(hex: "#c45656"), label: "PINK"),
        Track(id: "t2", title: "Lemon Tide",      artist: "Koa Bloom",      album: "Citrus Sessions",  duration: 184, color1: Color(hex: "#f6d365"), color2: Color(hex: "#fda085"), accent: Color(hex: "#b8721b"), label: "CITRUS"),
        Track(id: "t3", title: "Mint Mirage",     artist: "Halcyon Park",   album: "Greenhouse",       duration: 245, color1: Color(hex: "#a8d5e2"), color2: Color(hex: "#c8e7e0"), accent: Color(hex: "#3a7d8a"), label: "AQUA"),
        Track(id: "t4", title: "Velvet Dunes",    artist: "Solene Marais",  album: "Late Bloom",       duration: 201, color1: Color(hex: "#d4a5d8"), color2: Color(hex: "#e8c5e8"), accent: Color(hex: "#7a4885"), label: "LILAC"),
        Track(id: "t5", title: "Midnight Peach",  artist: "Juno Wave",      album: "After Hours",      duration: 232, color1: Color(hex: "#ffb5a7"), color2: Color(hex: "#fcd5ce"), accent: Color(hex: "#b8553f"), label: "PEACH"),
        Track(id: "t6", title: "Sage in June",    artist: "Linnea Holt",    album: "Garden State",     duration: 198, color1: Color(hex: "#b8d8b8"), color2: Color(hex: "#d4e5d4"), accent: Color(hex: "#4d6b4d"), label: "SAGE"),
        Track(id: "t7", title: "Powder Room",     artist: "Iris Mori",      album: "Soft Hours",       duration: 176, color1: Color(hex: "#f7c5d3"), color2: Color(hex: "#fce0e7"), accent: Color(hex: "#a84865"), label: "BLUSH"),
        Track(id: "t8", title: "Cobalt Dream",    artist: "Halcyon Park",   album: "Greenhouse",       duration: 267, color1: Color(hex: "#9ec5e8"), color2: Color(hex: "#c2dbed"), accent: Color(hex: "#345d82"), label: "COBALT"),
    ]
}

extension RecentAlbum {
    static let mock: [RecentAlbum] = [
        RecentAlbum(id: "r1", title: "Soft Hours",       artist: "Marina Vega",   color1: Color(hex: "#f4a8a8"), color2: Color(hex: "#f5c6c6")),
        RecentAlbum(id: "r2", title: "After Hours",      artist: "Juno Wave",     color1: Color(hex: "#ffb5a7"), color2: Color(hex: "#fcd5ce")),
        RecentAlbum(id: "r3", title: "Greenhouse",       artist: "Halcyon Park",  color1: Color(hex: "#a8d5e2"), color2: Color(hex: "#c8e7e0")),
        RecentAlbum(id: "r4", title: "Late Bloom",       artist: "Solene Marais", color1: Color(hex: "#d4a5d8"), color2: Color(hex: "#e8c5e8")),
        RecentAlbum(id: "r5", title: "Citrus Sessions",  artist: "Koa Bloom",     color1: Color(hex: "#f6d365"), color2: Color(hex: "#fda085")),
        RecentAlbum(id: "r6", title: "Garden State",     artist: "Linnea Holt",   color1: Color(hex: "#b8d8b8"), color2: Color(hex: "#d4e5d4")),
    ]
}

extension Playlist {
    static let mock: [Playlist] = [
        Playlist(id: "p1", name: "Morning Soft",     trackCount: 24, color1: Color(hex: "#f7c5d3"), color2: Color(hex: "#f4a8a8")),
        Playlist(id: "p2", name: "Focus / Cassette", trackCount: 41, color1: Color(hex: "#c8b6e2"), color2: Color(hex: "#a8d5e2")),
        Playlist(id: "p3", name: "Sunday Drive",     trackCount: 18, color1: Color(hex: "#f6d365"), color2: Color(hex: "#fda085")),
        Playlist(id: "p4", name: "Late Night Tape",  trackCount: 32, color1: Color(hex: "#9ec5e8"), color2: Color(hex: "#345d82")),
    ]
}
