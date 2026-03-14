import Foundation
import XCTest
@testable import CSVtoSheets

final class AuthManagerTests: XCTestCase {
    func testRefreshTokenOmitsClientSecretWhenNil() async throws {
        let testID = UUID().uuidString
        defer { URLProtocolStub.removeHandler(testID: testID) }
        let store = InMemoryTokenStore()
        store.stored = OAuthToken(
            accessToken: "old",
            refreshToken: "refresh-token",
            expiresAt: Date().addingTimeInterval(-60),
            tokenType: "Bearer",
            scope: nil
        )
        var capturedBody = ""
        URLProtocolStub.registerHandler(testID: testID) { request in
            capturedBody = String(data: bodyData(from: request), encoding: .utf8) ?? ""
            let payload = #"{"access_token":"new","expires_in":3600,"token_type":"Bearer"}"#
            return (makeHTTPResponse(url: request.url!, statusCode: 200), Data(payload.utf8))
        }
        let config = OAuthConfig(clientID: "client-id", clientSecret: nil, scopes: ["scope"])
        let manager = AuthManager(session: makeStubSession(testID: testID), config: config, tokenStore: store)

        _ = try await manager.restoreToken()

        XCTAssertTrue(capturedBody.contains("client_id=client-id"))
        XCTAssertTrue(capturedBody.contains("refresh_token=refresh-token"))
        XCTAssertFalse(capturedBody.contains("client_secret="))
    }

    func testRefreshTokenIncludesClientSecretWhenPresent() async throws {
        let testID = UUID().uuidString
        defer { URLProtocolStub.removeHandler(testID: testID) }
        let store = InMemoryTokenStore()
        store.stored = OAuthToken(
            accessToken: "old",
            refreshToken: "refresh-token",
            expiresAt: Date().addingTimeInterval(-60),
            tokenType: "Bearer",
            scope: nil
        )
        var capturedBody = ""
        URLProtocolStub.registerHandler(testID: testID) { request in
            capturedBody = String(data: bodyData(from: request), encoding: .utf8) ?? ""
            let payload = #"{"access_token":"new","expires_in":3600,"token_type":"Bearer"}"#
            return (makeHTTPResponse(url: request.url!, statusCode: 200), Data(payload.utf8))
        }
        let config = OAuthConfig(clientID: "client-id", clientSecret: "secret", scopes: ["scope"])
        let manager = AuthManager(session: makeStubSession(testID: testID), config: config, tokenStore: store)

        _ = try await manager.restoreToken()

        XCTAssertTrue(capturedBody.contains("client_secret=secret"))
    }

    func testRefreshTokenInvalidGrantClearsStoreAndThrowsReauthError() async {
        let testID = UUID().uuidString
        defer { URLProtocolStub.removeHandler(testID: testID) }
        let store = InMemoryTokenStore()
        store.stored = OAuthToken(
            accessToken: "old",
            refreshToken: "refresh-token",
            expiresAt: Date().addingTimeInterval(-60),
            tokenType: "Bearer",
            scope: nil
        )
        URLProtocolStub.registerHandler(testID: testID) { request in
            let payload = #"{"error":"invalid_grant"}"#
            return (makeHTTPResponse(url: request.url!, statusCode: 400), Data(payload.utf8))
        }
        let config = OAuthConfig(clientID: "client-id", clientSecret: nil, scopes: ["scope"])
        let manager = AuthManager(session: makeStubSession(testID: testID), config: config, tokenStore: store)

        do {
            _ = try await manager.restoreToken()
            XCTFail("Expected invalid grant error")
        } catch {
            let message = (error as? AppError)?.errorDescription ?? error.localizedDescription
            XCTAssertTrue(message.contains("Saved Google session expired"))
            XCTAssertEqual(store.clearCount, 1)
        }
    }

    func testValidAccessTokenClearsSessionAndFallsBackToSignInOnNonKeychainAuthError() async throws {
        let store = InMemoryTokenStore()
        store.loadError = AppError.auth("invalid_grant")
        let expected = OAuthToken(
            accessToken: "fresh-token",
            refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(3600),
            tokenType: "Bearer",
            scope: nil
        )
        let config = OAuthConfig(clientID: "client-id", clientSecret: nil, scopes: ["scope"])
        let manager = AuthManager(
            session: makeStubSession(testID: UUID().uuidString),
            config: config,
            tokenStore: store,
            signInOverride: { expected }
        )

        let token = try await manager.validAccessToken()

        XCTAssertEqual(token, "fresh-token")
        XCTAssertEqual(store.clearCount, 1)
    }

    func testValidAccessTokenRethrowsFriendlyKeychainErrorWithoutClearing() async {
        let store = InMemoryTokenStore()
        store.loadError = AppError.auth("Keychain permission denied")
        let config = OAuthConfig(clientID: "client-id", clientSecret: nil, scopes: ["scope"])
        let manager = AuthManager(session: makeStubSession(testID: UUID().uuidString), config: config, tokenStore: store)

        do {
            _ = try await manager.validAccessToken()
            XCTFail("Expected keychain auth error")
        } catch {
            let message = (error as? AppError)?.errorDescription ?? error.localizedDescription
            XCTAssertTrue(message.contains("Could not access your Keychain token"))
            XCTAssertEqual(store.clearCount, 0)
        }
    }

    func testValidAccessTokenFallsBackToSignInWhenNoStoredToken() async throws {
        let store = InMemoryTokenStore()
        store.stored = nil
        let expected = OAuthToken(
            accessToken: "fresh-token",
            refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(3600),
            tokenType: "Bearer",
            scope: nil
        )
        let config = OAuthConfig(clientID: "client-id", clientSecret: nil, scopes: ["scope"])
        let manager = AuthManager(
            session: makeStubSession(testID: UUID().uuidString),
            config: config,
            tokenStore: store,
            signInOverride: { expected }
        )

        let token = try await manager.validAccessToken()

        XCTAssertEqual(token, "fresh-token")
    }

    func testOAuthTokenParametersOmitClientSecretWhenEmpty() {
        let config = OAuthConfig(clientID: "client-id", clientSecret: "", scopes: ["scope"])
        let manager = AuthManager(session: makeStubSession(testID: UUID().uuidString), config: config, tokenStore: InMemoryTokenStore())

        let params = manager.oauthTokenParameters(base: [
            "client_id": "client-id",
            "grant_type": "authorization_code",
            "code": "abc"
        ])

        XCTAssertNil(params["client_secret"])
    }

    func testOAuthTokenParametersIncludeClientSecretWhenPresent() {
        let config = OAuthConfig(clientID: "client-id", clientSecret: "secret", scopes: ["scope"])
        let manager = AuthManager(session: makeStubSession(testID: UUID().uuidString), config: config, tokenStore: InMemoryTokenStore())

        let params = manager.oauthTokenParameters(base: [
            "client_id": "client-id",
            "grant_type": "authorization_code",
            "code": "abc"
        ])

        XCTAssertEqual(params["client_secret"], "secret")
    }
}
