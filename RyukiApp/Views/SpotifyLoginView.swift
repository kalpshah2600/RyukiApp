import SwiftUI

struct SpotifyLoginView: View {
    @EnvironmentObject var appVM: AppViewModel
    @State private var isConnecting = false
    @State private var errorMsg: String?

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#fdf6ec"), Color(hex: "#fde8d8")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Cassette logo
                VStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(.white)
                            .frame(width: 110, height: 110)
                            .shadow(color: .black.opacity(0.1), radius: 24, y: 10)
                        VStack(spacing: 4) {
                            Text("RYUKI")
                                .font(.system(.callout, design: .monospaced).weight(.black))
                                .tracking(4)
                            Image(systemName: "cassette")
                                .font(.system(size: 38))
                                .foregroundColor(Color(hex: "#f4a8a8"))
                        }
                    }

                    VStack(spacing: 6) {
                        Text("Welcome back")
                            .font(.system(size: 30, weight: .bold))
                            .tracking(-0.5)
                        Text("Log in to sync your Spotify library")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                }

                // Login button
                VStack(spacing: 16) {
                    Button {
                        isConnecting = true
                        errorMsg = nil
                        Task {
                            await appVM.startLogin()
                            if case .error(let msg) = appVM.phase {
                                errorMsg = msg
                            }
                            isConnecting = false
                        }
                    } label: {
                        HStack(spacing: 10) {
                            if isConnecting {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.85)
                            } else {
                                Image(systemName: "music.note.list")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            Text(isConnecting ? "Connecting…" : "Log in with Spotify")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(isConnecting ? Color(hex: "#158a3e") : Color(hex: "#1DB954"))
                                .shadow(color: Color(hex: "#1DB954").opacity(0.35), radius: 12, y: 6)
                        )
                    }
                    .disabled(isConnecting)

                    if let err = errorMsg {
                        Text(err)
                            .font(.system(size: 12))
                            .foregroundColor(.red.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 28)

                Spacer()

                // Change client ID
                Button {
                    appVM.resetToSetup()
                } label: {
                    Text("Change Client ID")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 32)
            }
        }
    }
}

#Preview {
    SpotifyLoginView().environmentObject(AppViewModel())
}
