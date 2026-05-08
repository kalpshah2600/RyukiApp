import SwiftUI

struct WaveformView: View {
    let progress: Double
    let accent: Color
    let seed: String
    var barCount: Int = 60
    var height: CGFloat = 36
    var onScrub: ((Double) -> Void)?

    private var bars: [Double] {
        var h: UInt32 = 0
        for c in seed.unicodeScalars { h = h &* 31 &+ c.value }
        func rng() -> Double {
            h = h &* 1664525 &+ 1013904223
            return Double(h % 1000) / 1000.0
        }
        return (0..<barCount).map { i in
            let env = sin(Double(i) / Double(barCount) * .pi) * 0.7 + 0.3
            let noise = rng() * 0.6 + 0.2
            let peak = rng() > 0.85 ? 1.0 : 0.6 + rng() * 0.3
            return max(0.12, env * noise * peak)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            Canvas { ctx, size in
                let barW = (w * 0.7) / CGFloat(barCount)
                let gap  = w / CGFloat(barCount)

                for (i, v) in bars.enumerated() {
                    let pos    = (Double(i) + 0.5) / Double(barCount)
                    let played = pos <= progress
                    let barH   = max(2, CGFloat(v) * height * 0.9)
                    let x      = CGFloat(i) * gap
                    let y      = (height - barH) / 2
                    let rect   = CGRect(x: x, y: y, width: barW, height: barH)
                    let path   = Path(roundedRect: rect, cornerRadius: 2)
                    ctx.fill(path, with: .color(played ? accent.opacity(0.95) : Color.black.opacity(0.18 * 0.65)))
                }

                // Playhead
                let px = CGFloat(progress) * w
                var line = Path()
                line.move(to: CGPoint(x: px, y: 0))
                line.addLine(to: CGPoint(x: px, y: height))
                ctx.stroke(line, with: .color(accent), lineWidth: 2)
            }
            .frame(width: w, height: height)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in onScrub?(max(0, min(1, v.location.x / w))) }
            )
        }
        .frame(height: height)
    }
}

#Preview {
    WaveformView(progress: 0.4, accent: Color(hex: "#c45656"), seed: "pastel skies")
        .padding()
        .background(Color(hex: "#fdf6ec"))
}
