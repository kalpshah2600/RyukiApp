import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

enum SpotifyAuthError: LocalizedError {
    case noCode, noVerifier, tokenExchangeFailed(String), cancelled

    var errorDescription: String? {
        switch self {
        case .noCode:           return "No authorization code in callback."
        case .noVerifier:       return "Missing PKCE code verifier."
        case .tokenExchangeFailed(let msg): return "Token exchange failed: \(msg)"
        case .cancelled:        return "Authentication was cancelled."
        }
    }
}

@MainActor
class SpotifyAuth: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {

    static let redirectURI = "ryuki://callback"
    static let scopes = [
        "user-read-recently-played",
        "user-library-read",
        "user-read-playback-state",
        "user-modify-playback-state",
        "user-read-currently-playing",
        "streaming",
        "app-remote-control",        // required for Spotify iOS SDK App Remote
        "user-read-private",
        "user-read-email",
        "playlist-read-private",
        "playlist-read-collaborative",
    ].joined(separator: " ")

    @Published var token: String?
    @Published var tokenExpiry: Date?
    @Published var profile: SpotifyProfile?

    private var clientId: String = ""
    private var verifier: String?
    private var refreshToken: String?
    private var authSession: ASWebAuthenticationSession?

    // MARK: - Persistence

    func loadSaved() {
        clientId     = UserDefaults.standard.string(forKey: "ryuki_client_id") ?? ""
        token        = UserDefaults.standard.string(forKey: "ryuki_token")
        refreshToken = UserDefaults.standard.string(forKey: "ryuki_refresh_token")
        if let exp = UserDefaults.standard.object(forKey: "ryuki_token_expiry") as? Date {
            tokenExpiry = exp
        }
    }

    func saveClientId(_ id: String) {
        clientId = id
        UserDefaults.standard.set(id, forKey: "ryuki_client_id")
    }

    var savedClientId: String {
        UserDefaults.standard.string(forKey: "ryuki_client_id") ?? ""
    }

    var isTokenValid: Bool {
        guard let token, !token.isEmpty,
              let expiry = tokenExpiry else { return false }
        return expiry > Date().addingTimeInterval(60)
    }

    var hasRefreshToken: Bool {
        guard let rt = refreshToken else { return false }
        return !rt.isEmpty
    }

    func clearToken() {
        token = nil; tokenExpiry = nil; refreshToken = nil; profile = nil
        UserDefaults.standard.removeObject(forKey: "ryuki_token")
        UserDefaults.standard.removeObject(forKey: "ryuki_token_expiry")
        UserDefaults.standard.removeObject(forKey: "ryuki_refresh_token")
    }

    func clearAll() {
        clearToken()
        clientId = ""
        UserDefaults.standard.removeObject(forKey: "ryuki_client_id")
    }

    // MARK: - Token refresh

    @discardableResult
    func refreshIfNeeded() async -> Bool {
        if isTokenValid { return true }
        guard let rt = refreshToken, !rt.isEmpty else { return false }
        do { try await exchangeRefreshToken(rt); return true }
        catch { return false }
    }

    // MARK: - PKCE OAuth

    func startAuth() async throws {
        guard !clientId.isEmpty else { throw SpotifyAuthError.noVerifier }
        let v = generateVerifier()
        verifier = v
        let challenge = generateChallenge(from: v)

        var comps = URLComponents(string: "https://accounts.spotify.com/authorize")!
        comps.queryItems = [
            .init(name: "client_id",            value: clientId),
            .init(name: "response_type",         value: "code"),
            .init(name: "redirect_uri",          value: Self.redirectURI),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "code_challenge",        value: challenge),
            .init(name: "scope",                 value: Self.scopes),
        ]

        let authURL = comps.url!
        let code = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "ryuki") { [weak self] url, error in
                self?.authSession = nil
                if let e = error as? ASWebAuthenticationSessionError, e.code == .canceledLogin {
                    cont.resume(throwing: SpotifyAuthError.cancelled); return
                }
                if let error { cont.resume(throwing: error); return }
                guard let url,
                      let c = URLComponents(url: url, resolvingAgainstBaseURL: true),
                      let code = c.queryItems?.first(where: { $0.name == "code" })?.value
                else { cont.resume(throwing: SpotifyAuthError.noCode); return }
                cont.resume(returning: code)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            authSession = session
            session.start()
        }
        try await exchangeCode(code)
    }

    // MARK: - Token exchange

    private func exchangeCode(_ code: String) async throws {
        guard let verifier else { throw SpotifyAuthError.noVerifier }
        let params: [String: String] = [
            "grant_type":    "authorization_code",
            "code":          code,
            "redirect_uri":  Self.redirectURI,
            "client_id":     clientId,
            "code_verifier": verifier,
        ]
        let json = try await postToken(params: params)
        try saveTokens(from: json)
        self.verifier = nil
    }

    private func exchangeRefreshToken(_ rt: String) async throws {
        let params: [String: String] = [
            "grant_type":    "refresh_token",
            "refresh_token": rt,
            "client_id":     clientId,
        ]
        let json = try await postToken(params: params)
        try saveTokens(from: json)
    }

    private func postToken(params: [String: String]) async throws -> [String: Any] {
        var req = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SpotifyAuthError.tokenExchangeFailed("Invalid response")
        }
        return json
    }

    private func saveTokens(from json: [String: Any]) throws {
        guard let at = json["access_token"] as? String else {
            let msg = json["error_description"] as? String ?? json["error"] as? String ?? "Unknown"
            throw SpotifyAuthError.tokenExchangeFailed(msg)
        }
        let exp = json["expires_in"] as? TimeInterval ?? 3600
        token = at
        tokenExpiry = Date().addingTimeInterval(exp)
        UserDefaults.standard.set(at, forKey: "ryuki_token")
        UserDefaults.standard.set(tokenExpiry, forKey: "ryuki_token_expiry")
        if let rt = json["refresh_token"] as? String {
            refreshToken = rt
            UserDefaults.standard.set(rt, forKey: "ryuki_refresh_token")
        }
    }

    // MARK: - PKCE Helpers

    private func generateVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Presentation

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        }
    }
}
