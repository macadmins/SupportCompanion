//
//  FleetSSOTests.swift
//  SupportCompanionTests
//

import Foundation
import Testing
@testable import SupportCompanion

@Suite("Fleet Desktop SSO")
struct FleetSSOTests {

    private let server = URL(string: "https://fleet.example.com")!

    private func response(setCookie: String?) -> HTTPURLResponse {
        var fields: [String: String] = ["Content-Type": "application/json"]
        if let setCookie { fields["Set-Cookie"] = setCookie }
        return HTTPURLResponse(url: server, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: fields)!
    }

    // MARK: - The handshake cookie

    /// Exactly what Fleet 4.92 sends on POST /device/{token}/sso.
    @Test func readsFleetsHandshakeCookie() throws {
        let cookie = try #require(FleetClient.handshakeCookie(
            from: response(setCookie: "__Host-FLEETSSOSESSIONID=abc123; Path=/; Max-Age=300; HttpOnly; Secure"),
            server: server
        ))

        #expect(cookie.name == "__Host-FLEETSSOSESSIONID")
        #expect(cookie.value == "abc123")
        // __Host- cookies are pinned to the host and path, and the web view must be handed them that way
        #expect(cookie.path == "/")
        #expect(cookie.isSecure)
        #expect(cookie.domain.contains("fleet.example.com"))
    }

    @Test func ignoresOtherCookies() {
        let cookie = FleetClient.handshakeCookie(
            from: response(setCookie: "__Host-FLEET_DESKTOP_SESSION=xyz; Path=/; Secure"),
            server: server
        )
        #expect(cookie == nil)
    }

    @Test func toleratesNoCookieAtAll() {
        #expect(FleetClient.handshakeCookie(from: response(setCookie: nil), server: server) == nil)
    }

    @Test func decodesTheIdentityProviderURL() throws {
        let json = #"{"url":"https://login.microsoftonline.com/x/saml2?SAMLRequest=abc"}"#
        let decoded = try JSONDecoder.fleet.decode(FleetSSOInitiationResponse.self, from: Data(json.utf8))
        #expect(decoded.url == "https://login.microsoftonline.com/x/saml2?SAMLRequest=abc")
    }

    // MARK: - Fleet's failure redirect

    @Test func readsTheErrorFleetRedirectsWith() throws {
        let url = URL(string: "https://fleet.example.com/device/tok?sso_error=sso_disabled")!
        #expect(FleetSSOController.ssoErrorReason(in: url) == "sso_disabled")
    }

    @Test func aPlainDevicePageIsNotAnError() {
        let url = URL(string: "https://fleet.example.com/device/tok")!
        #expect(FleetSSOController.ssoErrorReason(in: url) == nil)
    }

    /// An empty value is Fleet saying nothing, not Fleet reporting a failure with no reason.
    @Test func anEmptyErrorIsNotAnError() {
        let url = URL(string: "https://fleet.example.com/device/tok?sso_error=")!
        #expect(FleetSSOController.ssoErrorReason(in: url) == nil)
    }

    // MARK: - Reusing a stored session

    private func session(host: String, expiresAt: Date?) -> FleetSSOSessionStore.Session {
        .init(cookie: "session-value", host: host, expiresAt: expiresAt)
    }

    @Test func aFreshSessionIsUsed() {
        let stored = session(host: "fleet.example.com", expiresAt: Date().addingTimeInterval(5 * 24 * 3600))
        #expect(stored.isUsable(on: "fleet.example.com"))
    }

    @Test func hostsAreComparedCaseInsensitively() {
        let stored = session(host: "Fleet.Example.com", expiresAt: nil)
        #expect(stored.isUsable(on: "fleet.example.com"))
    }

    /// A Mac repointed at another Fleet server signs in again rather than offering the old session.
    @Test func aSessionFromAnotherServerIsRefused() {
        let stored = session(host: "old.example.com", expiresAt: Date().addingTimeInterval(3600))
        #expect(!stored.isUsable(on: "fleet.example.com"))
    }

    @Test func anExpiredSessionIsRefused() {
        let stored = session(host: "fleet.example.com", expiresAt: Date().addingTimeInterval(-1))
        #expect(!stored.isUsable(on: "fleet.example.com"))
    }

    /// Sending a session that expires mid-flight just earns an SSO prompt, so it's dropped early.
    @Test func aSessionAboutToExpireIsRefused() {
        let stored = session(host: "fleet.example.com", expiresAt: Date().addingTimeInterval(30))
        #expect(!stored.isUsable(on: "fleet.example.com"))
    }

    @Test func aSessionSurvivesEncoding() throws {
        let expiry = Date(timeIntervalSince1970: 1_800_000_000)
        let stored = session(host: "fleet.example.com", expiresAt: expiry)
        let decoded = try JSONDecoder().decode(
            FleetSSOSessionStore.Session.self,
            from: JSONEncoder().encode(stored)
        )
        #expect(decoded == stored)
    }
}
