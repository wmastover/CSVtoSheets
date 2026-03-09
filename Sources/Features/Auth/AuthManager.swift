import AppKit
import CryptoKit
import Foundation
import Network

struct OAuthConfig: Decodable {
    let clientID: String
    let scopes: [String]
}

final class AuthManager {
    private let tokenStore = KeychainTokenStore()
    private let session: URLSession
    private let config: OAuthConfig
    private let callbackHost = "127.0.0.1"

    init(session: URLSession = .shared, config: OAuthConfig) {
        self.session = session
        self.config = config
    }

    static func loadConfig() throws -> OAuthConfig {
        let path = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Resources/OAuthConfig.json")
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw AppError.auth("Missing Resources/OAuthConfig.json. Copy Resources/OAuthConfig.example.json and set clientID.")
        }
        let data = try Data(contentsOf: path)
        return try JSONDecoder().decode(OAuthConfig.self, from: data)
    }

    func hasSession() -> Bool {
        (try? tokenStore.load()) != nil
    }

    func restoreToken() async throws -> OAuthToken? {
        guard let token = try tokenStore.load() else { return nil }
        if token.expiresAt > Date().addingTimeInterval(60) {
            return token
        }
        guard token.refreshToken != nil else { return nil }
        let refreshed = try await refreshToken()
        return refreshed
    }

    func signIn() async throws -> OAuthToken {
        let codeVerifier = PKCE.codeVerifier()
        let challenge = PKCE.codeChallenge(from: codeVerifier)
        let callbackServer = try OAuthCallbackServer()
        try callbackServer.start()
        defer { callbackServer.stop() }

        let redirectURI = "http://\(callbackHost):\(callbackServer.port)/oauth2callback"
        guard var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth") else {
            throw AppError.auth("Unable to build OAuth URL.")
        }
        components.queryItems = [
            URLQueryItem(name: "client_id", value: config.clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: config.scopes.joined(separator: " ")),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]

        guard let authURL = components.url else {
            throw AppError.auth("Unable to build OAuth authorization URL.")
        }

        NSWorkspace.shared.open(authURL)
        let code = try await callbackServer.waitForCode(timeout: 180)
        let token = try await exchangeCodeForToken(
            code: code,
            redirectURI: redirectURI,
            codeVerifier: codeVerifier
        )
        try tokenStore.save(token: token)
        return token
    }

    func signOut() throws {
        try tokenStore.clear()
    }

    func validAccessToken() async throws -> String {
        if let token = try await restoreToken() {
            return token.accessToken
        }
        let token = try await signIn()
        return token.accessToken
    }

    func fetchAccountEmail(accessToken: String) async -> String? {
        guard let url = URL(string: "https://www.googleapis.com/oauth2/v3/userinfo") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            let profile = try JSONDecoder().decode(UserInfoResponse.self, from: data)
            return profile.email
        } catch {
            return nil
        }
    }

    private func refreshToken() async throws -> OAuthToken {
        guard let existing = try tokenStore.load(), let refresh = existing.refreshToken else {
            throw AppError.auth("No refresh token available.")
        }
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else {
            throw AppError.auth("Unable to build token endpoint URL.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formEncoded([
            "client_id": config.clientID,
            "grant_type": "refresh_token",
            "refresh_token": refresh
        ])

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AppError.auth("Invalid token refresh response.")
        }
        if http.statusCode != 200 {
            throw AppError.auth("Google token refresh failed (\(http.statusCode)).")
        }
        let refreshed = try JSONDecoder().decode(TokenResponse.self, from: data)
        let token = OAuthToken(
            accessToken: refreshed.accessToken,
            refreshToken: refresh,
            expiresAt: Date().addingTimeInterval(TimeInterval(refreshed.expiresIn)),
            tokenType: refreshed.tokenType,
            scope: refreshed.scope
        )
        try tokenStore.save(token: token)
        return token
    }

    private func exchangeCodeForToken(
        code: String,
        redirectURI: String,
        codeVerifier: String
    ) async throws -> OAuthToken {
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else {
            throw AppError.auth("Unable to build token endpoint URL.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formEncoded([
            "client_id": config.clientID,
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI,
            "code_verifier": codeVerifier
        ])

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AppError.auth("Invalid token exchange response.")
        }
        if http.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? "unknown error"
            throw AppError.auth("Google token exchange failed (\(http.statusCode)): \(body)")
        }
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        let token = OAuthToken(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn)),
            tokenType: tokenResponse.tokenType,
            scope: tokenResponse.scope
        )
        return token
    }

    private func formEncoded(_ params: [String: String]) -> Data {
        let body = params
            .map { key, value in
                "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value)"
            }
            .joined(separator: "&")
        return Data(body.utf8)
    }
}

private struct TokenResponse: Decodable {
    let accessToken: String
    let expiresIn: Int
    let refreshToken: String?
    let scope: String?
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
        case tokenType = "token_type"
    }
}

private struct UserInfoResponse: Decodable {
    let email: String?
}

private enum PKCE {
    static func codeVerifier() -> String {
        let charset = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return String((0..<64).map { _ in charset.randomElement()! })
    }

    static func codeChallenge(from verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private final class OAuthCallbackServer {
    let port: UInt16

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "oauth-callback-server")
    private var continuation: CheckedContinuation<String, Error>?

    init(port: UInt16 = 53682) throws {
        guard let endpointPort = NWEndpoint.Port(rawValue: port) else {
            throw AppError.auth("Invalid OAuth callback port.")
        }
        self.listener = try NWListener(using: .tcp, on: endpointPort)
        self.port = port
    }

    func start() throws {
        guard let listener else { throw AppError.auth("Unable to start OAuth callback listener.") }
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection: connection)
        }
        listener.start(queue: queue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    func waitForCode(timeout: TimeInterval) async throws -> String {
        try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { continuation in
                    self.continuation = continuation
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw AppError.auth("Sign-in timed out. Please try again.")
            }
            let code = try await group.next()!
            group.cancelAll()
            return code
        }
    }

    private func handle(connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, error in
            defer { connection.cancel() }
            if let error {
                self?.continuation?.resume(throwing: AppError.auth("OAuth callback failed: \(error.localizedDescription)"))
                self?.continuation = nil
                return
            }
            guard let data, let request = String(data: data, encoding: .utf8) else {
                self?.continuation?.resume(throwing: AppError.auth("Unable to read OAuth callback request."))
                self?.continuation = nil
                return
            }
            let code = Self.extractCode(from: request)
            let response: String
            if let code {
                response = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\nSign-in complete. You can close this tab."
                self?.continuation?.resume(returning: code)
            } else {
                response = "HTTP/1.1 400 Bad Request\r\nContent-Type: text/html\r\n\r\nNo authorization code found."
                self?.continuation?.resume(throwing: AppError.auth("OAuth callback missing authorization code."))
            }
            self?.continuation = nil
            connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in })
        }
    }

    private static func extractCode(from request: String) -> String? {
        guard let firstLine = request.split(separator: "\r\n").first else { return nil }
        let pieces = firstLine.split(separator: " ")
        guard pieces.count >= 2 else { return nil }
        guard let components = URLComponents(string: "http://local\(pieces[1])") else { return nil }
        return components.queryItems?.first(where: { $0.name == "code" })?.value
    }
}
