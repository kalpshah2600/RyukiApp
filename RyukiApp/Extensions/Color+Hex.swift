import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

extension Color {
    static func pastelPair(seed: String) -> (Color, Color, Color) {
        var hash: UInt32 = 0
        for c in seed.unicodeScalars {
            hash = hash &* 31 &+ c.value
        }
        let hue = Double(hash % 360) / 360.0
        let c1 = Color(hue: hue, saturation: 0.45, brightness: 0.92)
        let c2 = Color(hue: hue, saturation: 0.3, brightness: 0.96)
        let accent = Color(hue: hue, saturation: 0.65, brightness: 0.6)
        return (c1, c2, accent)
    }
}
