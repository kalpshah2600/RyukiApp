import SwiftUI

struct LoadingView: View {
    let message: String

    @State private var dot1 = false
    @State private var dot2 = false
    @State private var dot3 = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#fdf6ec"), Color(hex: "#fde8d8")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                VStack(spacing: 16) {
                    // Logo
                    ZStack {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(.white)
                            .frame(width: 100, height: 100)
                            .shadow(color: .black.opacity(0.12), radius: 20, y: 8)

                        CassetteIconShape()
                            .frame(width: 72, height: 45)
                    }
                    .scaleEffect(appeared ? 1 : 0.85)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: appeared)

                    Text("RYUKI")
                        .font(.system(.largeTitle, design: .monospaced).weight(.black))
                        .tracking(8)
                        .foregroundColor(.primary)

                    Text("your music, retro style")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                // Dots
                HStack(spacing: 8) {
                    ForEach(Array([dot1, dot2, dot3].enumerated()), id: \.offset) { _, active in
                        Circle()
                            .fill(Color(hex: "#f4a8a8"))
                            .frame(width: 8, height: 8)
                            .scaleEffect(active ? 1.3 : 0.8)
                            .opacity(active ? 1 : 0.3)
                    }
                }

                Text(message)
                    .font(.system(size: 13))
                    .foregroundColor(Color.secondary.opacity(0.7))
            }
        }
        .onAppear {
            appeared = true
            animateDots()
        }
    }

    private func animateDots() {
        func toggle(_ idx: Int, after delay: Double) {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    switch idx { case 0: dot1 = true; case 1: dot2 = true; default: dot3 = true }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        switch idx { case 0: dot1 = false; case 1: dot2 = false; default: dot3 = false }
                    }
                }
            }
        }
        func loop() {
            toggle(0, after: 0); toggle(1, after: 0.2); toggle(2, after: 0.4)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { loop() }
        }
        loop()
    }
}

private struct CassetteIconShape: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(hex: "#f4a8a8"))
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: "#fdf6ec"))
                    .frame(height: 13)
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                Spacer()
                HStack(spacing: 0) {
                    Spacer()
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.black.opacity(0.75))
                        .frame(width: 52, height: 18)
                    Spacer()
                }
                .padding(.bottom, 4)
            }
        }
    }
}

#Preview { LoadingView(message: "Loading…") }
