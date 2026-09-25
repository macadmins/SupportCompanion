//
//  FleetSSOController.swift
//  SupportCompanion
//
//  Drives Fleet Desktop SSO sign-in (Fleet 4.92 and later).
//
//  The flow, all of it Fleet's:
//   1. POST /device/{token}/sso answers with the identity provider's URL and sets a handshake cookie.
//   2. The user signs in at the identity provider, which posts the SAML assertion back to Fleet.
//   3. Fleet's callback sets __Host-FLEET_DESKTOP_SESSION and redirects to this Mac's device page.
//
//  Steps 1 and 3 happen on Fleet, step 2 at the identity provider, so the sign-in runs in a web view
//  rather than in the app: the assertion is between the user and their identity provider, and this
//  app only ever sees the session cookie at the end of it. That cookie is HttpOnly, so it's read from
//  the web view's cookie store rather than from the page.
//

import Foundation
import Observation
import WebKit

@MainActor
@Observable
final class FleetSSOController: NSObject {
    enum Phase: Equatable {
        /// Nothing in flight.
        case idle
        /// Asking Fleet where to send the user.
        case starting
        /// The identity provider's page is up and it's the user's turn.
        case signingIn
        /// Fleet handed back a session and it's being stored.
        case completing
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    /// Whether the sign-in sheet is on screen.
    var isPresented = false
    private(set) var webView: WKWebView?

    /// Called once a sign-in succeeds, so the Fleet pages reload what they couldn't fetch before.
    @ObservationIgnored var onSignedIn: (() -> Void)?

    @ObservationIgnored private let client: FleetClient
    @ObservationIgnored private var isFinishing = false
    /// Reading the cookie store suspends, and both navigation callbacks check, so checks are serialised.
    @ObservationIgnored private var isCheckingForSession = false

    init(client: FleetClient = .shared) {
        self.client = client
        super.init()
    }

    // MARK: - Presenting

    /// Opens the sheet and asks Fleet for the identity provider's URL.
    func present() {
        guard !isPresented else { return }
        isPresented = true
        Task { await start() }
    }

    func cancel() {
        isPresented = false
        teardown()
        isFinishing = false
        phase = .idle
    }

    /// Clears the session so the next gated request asks for sign-in again.
    func signOut() async {
        await client.signOutSSO()
        await Self.clearFleetCookies()
        phase = .idle
    }

    // MARK: - The flow

    func start() async {
        teardown()
        // A previous attempt may have ended in an error, which leaves this set
        isFinishing = false
        phase = .starting

        let initiation: FleetSSOInitiation
        do {
            initiation = try await client.initiateSSO()
        } catch {
            Logger.shared.logError("Fleet: couldn't start Fleet Desktop SSO: \(error.localizedDescription)")
            phase = .failed(error.localizedDescription)
            return
        }

        // The sheet may have been cancelled while Fleet was answering
        guard isPresented else { return }

        // A sign-in that was interrupted can leave Fleet cookies behind, and a stale session cookie
        // would be taken for this one's result before the user has typed anything, so the slate is
        // wiped first: anything found from here on was set by this sign-in.
        await Self.clearFleetCookies()

        guard isPresented else { return }

        // The web view has its own cookie store, so Fleet's handshake cookie has to be planted there
        // or its callback has nothing to match the assertion against and the sign-in loops.
        let dataStore = WKWebsiteDataStore.default()
        if let handshake = initiation.handshakeCookie {
            await dataStore.httpCookieStore.setCookie(handshake)
        } else {
            Logger.shared.logError("Fleet: Fleet Desktop SSO started without a handshake cookie")
        }

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = dataStore
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        phase = .signingIn
        webView.load(URLRequest(url: initiation.idpURL))
    }

    /// Looks for the session Fleet's callback sets, and for the error it redirects with instead.
    private func checkForSession() async {
        guard !isFinishing, !isCheckingForSession, let webView else { return }
        isCheckingForSession = true
        defer { isCheckingForSession = false }

        if let url = webView.url, let reason = Self.ssoErrorReason(in: url) {
            Logger.shared.logError("Fleet: Fleet Desktop SSO failed: \(reason)")
            isFinishing = true
            phase = .failed(Self.message(forErrorReason: reason))
            teardown()
            return
        }

        let cookies = await webView.configuration.websiteDataStore.httpCookieStore.allCookies()
        guard let session = cookies.first(where: { $0.name == FleetClient.ssoSessionCookieName }),
              !session.value.isEmpty else {
            return
        }

        isFinishing = true
        phase = .completing
        await client.completeSSO(cookie: session.value, expiresAt: session.expiresDate)
        // The session is in the keychain now; the web view's copy would be a second, weaker one
        await Self.clearFleetCookies()
        teardown()
        phase = .idle
        isPresented = false
        isFinishing = false
        Logger.shared.logDebug("Fleet: signed in with Fleet Desktop SSO")
        onSignedIn?()
    }

    /// Fleet redirects to the device page with `sso_error=<reason>` when the callback couldn't mint a
    /// session, e.g. because an admin turned the feature off mid-flow.
    nonisolated static func ssoErrorReason(in url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name == "sso_error" }?
            .value
            .flatMap { $0.isEmpty ? nil : $0 }
    }

    private static func message(forErrorReason reason: String) -> String {
        switch reason {
        case "sso_disabled": return Constants.Fleet.ssoDisabled
        default: return Constants.Fleet.ssoFailed
        }
    }

    /// Removes the Fleet cookies from the web view's store, leaving the identity provider's own so a
    /// later sign-in can still be silent.
    private static func clearFleetCookies() async {
        let store = WKWebsiteDataStore.default().httpCookieStore
        for cookie in await store.allCookies()
        where cookie.name == FleetClient.ssoSessionCookieName || cookie.name == FleetClient.ssoHandshakeCookieName {
            await store.deleteCookie(cookie)
        }
    }

    private func teardown() {
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView = nil
    }
}

extension FleetSSOController: WKNavigationDelegate {
    /// Checked as each response arrives rather than only when a page finishes: Fleet's callback sets
    /// the session on a redirect, and the device page it redirects to can take a while to render.
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        Task { await checkForSession() }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { await checkForSession() }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        fail(with: error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        fail(with: error)
    }

    private func fail(with error: Error) {
        // A cancelled load is the redirect chain moving on, not a failure
        guard (error as NSError).code != NSURLErrorCancelled, !isFinishing else { return }
        Logger.shared.logError("Fleet: the Fleet Desktop SSO page failed to load: \(error.localizedDescription)")
        phase = .failed(error.localizedDescription)
    }
}
