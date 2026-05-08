import SwiftUI

struct SpotifySetupView: View {
    @EnvironmentObject var appVM: AppViewModel
    @State private var clientId = ""
    @State private var copied = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#fdf6ec"), Color(hex: "#fde8d8")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [Color(hex: "#1DB954"), Color(hex: "#158a3e")],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 72, height: 72)
                            Image(systemName: "music.note")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Text("Connect Spotify")
                            .font(.system(size: 28, weight: .bold, design: .default))
                            .tracking(-0.5)
                        Text("Enter your Spotify app Client ID to get started.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.top, 48)

                    // Instructions card
                    VStack(alignment: .leading, spacing: 14) {
                        Text("SETUP STEPS")
                            .font(.system(.caption, design: .monospaced).weight(.bold))
                            .tracking(1.5)
                            .foregroundColor(.secondary)

                        ForEach(steps, id: \.number) { step in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(step.number)")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                    .frame(width: 22, height: 22)
                                    .background(Circle().fill(Color(hex: "#1DB954")))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(step.title)
                                        .font(.system(size: 14, weight: .semibold))
                                    Text(step.detail)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        // Redirect URI copy row
                        HStack {
                            Text(SpotifyAuth.redirectURI)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(Color(hex: "#1DB954"))
                                .lineLimit(1)
                            Spacer()
                            Button {
                                UIPasteboard.general.string = SpotifyAuth.redirectURI
                                copied = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                            } label: {
                                Text(copied ? "Copied!" : "Copy")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(copied ? .white : Color(hex: "#1DB954"))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule().fill(copied ? Color(hex: "#1DB954") : Color(hex: "#1DB954").opacity(0.12))
                                    )
                            }
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: "#1DB954").opacity(0.06)))
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.white.opacity(0.7))
                            .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
                    )
                    .padding(.horizontal, 20)

                    // Client ID field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CLIENT ID")
                            .font(.system(.caption, design: .monospaced).weight(.bold))
                            .tracking(1.5)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)

                        TextField("Paste your Client ID here", text: $clientId)
                            .font(.system(size: 14, design: .monospaced))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(.white.opacity(0.85))
                                    .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
                            )
                    }
                    .padding(.horizontal, 20)

                    // Continue button
                    Button {
                        let trimmed = clientId.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        appVM.saveClientId(trimmed)
                    } label: {
                        Text("Continue")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(clientId.trimmingCharacters(in: .whitespaces).isEmpty
                                          ? Color.gray.opacity(0.3)
                                          : Color(hex: "#1a1a1a"))
                            )
                    }
                    .disabled(clientId.trimmingCharacters(in: .whitespaces).isEmpty)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private struct Step { let number: Int; let title: String; let detail: String }
    private let steps = [
        Step(number: 1, title: "Open Spotify Developer Dashboard", detail: "Go to developer.spotify.com/dashboard"),
        Step(number: 2, title: "Create an app",                   detail: "Click \"Create App\" and fill in a name"),
        Step(number: 3, title: "Add the redirect URI",            detail: "In Settings → Redirect URIs, add:"),
        Step(number: 4, title: "Copy the Client ID",              detail: "Find it on your app's dashboard page"),
    ]
}

#Preview {
    SpotifySetupView().environmentObject(AppViewModel())
}
