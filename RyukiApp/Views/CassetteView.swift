import SwiftUI

struct CassetteView: View {
    let track: Track
    let playing: Bool
    let width: CGFloat

    @State private var rotX: Double = -14
    @State private var rotY: Double = 18

    // Real cassette photo aspect ratio (≈ 1.45 : 1)
    var height: CGFloat { width * 0.69 }

    var body: some View {
        ZStack {
            // ── Cassette photo ──────────────────────────────────────
            Image("cassette-tape")
                .resizable()
                .scaledToFit()
                .frame(width: width, height: height)

            // ── Album art — placed inside the white label, clear of the corner ─
            let artSize: CGFloat = width * 0.138
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(LinearGradient(colors: [track.color1, track.color2],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                if let url = track.albumArtURL {
                    AsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Color.clear
                    }
                }
            }
            .frame(width: artSize, height: artSize)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.leading, width * 0.096)   // moved right, away from the black corner
            .padding(.top,    height * 0.132)   // moved down into the label proper

            // ── White block erases the printed lines behind our text ───
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(0.88))
                .frame(width: width * 0.595, height: height * 0.205)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, width * 0.258)
                .padding(.top,    height * 0.110)

            // ── Handwritten song name + artist on the now-clean white area ───
            VStack(alignment: .leading, spacing: height * 0.025) {
                Text(track.title)
                    .font(Font.custom("Bradley Hand", size: width * 0.052))
                    .foregroundColor(Color(red: 0.12, green: 0.08, blue: 0.04))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(track.artist)
                    .font(Font.custom("Bradley Hand", size: width * 0.034))
                    .foregroundColor(Color(red: 0.12, green: 0.08, blue: 0.04).opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: width * 0.565, alignment: .leading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.leading, width * 0.268)
            .padding(.top,    height * 0.126)

            // ── Spinning reel overlays — pixel-measured from the cassette photo ──
            // Photo is ~700 × 483 px. Left reel centre ≈ (215, 315) → 30.7 %, 65.2 %
            // Right reel centre ≈ (490, 315) → 70 %, 65.2 %. Reel diameter ≈ 17 % w.
            // ZStack anchor = centre of the (width × height) frame.
            // Left reel: x = 30.7 % × 300 − 150 = −57.9  →  −width × 0.193
            //            y = 65.2 % × 207 − 103.5 = +31.4 →  +height × 0.152
            ReelSpinOverlay(size: width * 0.172, playing: playing)
                .offset(x: -width * 0.193, y: height * 0.152)

            // Right reel: x = 70 % × 300 − 150 = +60     →  +width × 0.200
            ReelSpinOverlay(size: width * 0.172, playing: playing)
                .offset(x: width * 0.200, y: height * 0.152)
        }
        .frame(width: width, height: height)
        .rotation3DEffect(.degrees(rotX), axis: (1, 0, 0), perspective: 0.5)
        .rotation3DEffect(.degrees(rotY), axis: (0, 1, 0), perspective: 0.5)
        .shadow(color: .black.opacity(0.30), radius: 22, y: 14)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    rotX = rotX.clamped(-60, 60) - v.velocity.height * 0.0015
                    rotY = rotY.clamped(-60, 60) + v.velocity.width * 0.0015
                }
                .onEnded { _ in
                    withAnimation(.interactiveSpring(response: 1.5, dampingFraction: 0.6)) {
                        rotX = -14; rotY = 18
                    }
                }
        )
        .onAppear { startIdleAnimation() }
    }

    private func startIdleAnimation() {
        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
            rotX = -14 + 3
        }
    }
}

// Transparent spinning spoke disc — blends with the real reel in the photo
private struct ReelSpinOverlay: View {
    let size: CGFloat
    let playing: Bool

    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            // Six spokes radiating from center
            ForEach(0..<6) { i in
                Capsule()
                    .fill(Color(red: 0.16, green: 0.11, blue: 0.05).opacity(0.42))
                    .frame(width: size * 0.095, height: size * 0.38)
                    .offset(y: -(size * 0.17))
                    .rotationEffect(.degrees(Double(i) * 60))
            }
            // Center hub
            Circle()
                .fill(Color(red: 0.14, green: 0.10, blue: 0.05).opacity(0.52))
                .frame(width: size * 0.24, height: size * 0.24)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(rotation))
        .onAppear { if playing { startSpin() } }
        .onChange(of: playing) { _, nowPlaying in
            if nowPlaying { startSpin() } else { stopSpin() }
        }
    }

    private func startSpin() {
        withAnimation(.linear(duration: 2.2).repeatForever(autoreverses: false)) {
            rotation = 360
        }
    }

    private func stopSpin() {
        withAnimation(.easeOut(duration: 0.9)) {
            rotation = rotation.truncatingRemainder(dividingBy: 360)
        }
    }
}

extension Double {
    func clamped(_ low: Double, _ high: Double) -> Double {
        min(max(self, low), high)
    }
}

#Preview {
    CassetteView(track: Track.mock[0], playing: true, width: 300)
        .padding()
        .background(Color(hex: "#fdf6ec"))
}
