//
//  FleetClient.swift
//  SupportCompanion
//
//  Client for Fleet's device-authenticated API.
//
//  Fleet bans a client's public IP after repeated failed requests to device endpoints, which would lock
//  out every Mac behind the same NAT. So this client never retries in a loop: after a failure it refuses
//  requests locally until a backoff deadline, and while Fleet requires SSO it sends nothing gated at all.
//

import Foundation

enum FleetError: Error, Equatable, LocalizedError {
    /// No Fleet server or device token on this Mac.
    case notConfigured
    /// Fleet Desktop SSO is enabled and there's no valid session; sign in via FleetSSOController.
    case ssoRequired
    /// The device token was rejected.
    case unauthorized
    /// Requests are paused after earlier failures.
    case backingOff(until: Date)
    case rateLimited
    case server(status: Int, message: String)
    case network(String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Fleet isn't set up on this Mac."
        case .ssoRequired:
            return "Sign in to continue."
        case .unauthorized:
            return "Fleet didn't accept this Mac's device token."
        case .backingOff(let until):
            return "Fleet is temporarily unavailable. Retrying \(until.formatted(date: .omitted, time: .shortened))."
        case .rateLimited:
            return "Too many requests to Fleet. Try again later."
        case .server(let status, let message):
            return message.isEmpty ? "Fleet returned an error (\(status))." : message
        case .network(let message):
            return message
        case .decoding(let message):
            return "Unexpected response from Fleet: \(message)"
        }
    }
}

actor FleetClient {
    static let shared = FleetClient()

    /// Name of the cookie Fleet sets after Fleet Desktop SSO.
    static let ssoSessionCookieName = "__Host-FLEET_DESKTOP_SESSION"

    private let session: URLSession
    private var token: FleetDeviceIdentity.Token?
    private var ssoSessionCookie: String?

    private(set) var isSSORequired = false
    private var consecutiveFailures = 0
    private var blockedUntil: Date?

    private static let minimumBackoff: TimeInterval = 60
    private static let maximumBackoff: TimeInterval = 30 * 60

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        // The SSO cookie is attached explicitly; nothing else should be stored or sent
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        session = URLSession(configuration: configuration)
    }

    // MARK: - Configuration

    nonisolated var configurationProblem: String? {
        FleetDeviceIdentity.configurationProblem()
    }

    /// Fleet's "My device" page for this Mac, used for the SSO sign-in web view.
    func deviceWebURL() -> URL? {
        guard let server = FleetDeviceIdentity.serverURL(), let token = currentToken() else { return nil }
        return server.appending(path: "device").appending(path: token.value)
    }

    /// Stores the Fleet Desktop SSO session and lifts the SSO and backoff pauses.
    func setSSOSessionCookie(_ value: String?) {
        ssoSessionCookie = value
        if value != nil {
            isSSORequired = false
            resetBackoff()
        }
    }

    func resetBackoff() {
        consecutiveFailures = 0
        blockedUntil = nil
    }

    // MARK: - Endpoints

    /// All self-service software titles for this Mac.
    func selfServiceSoftware() async throws -> [FleetSoftwareTitle] {
        var titles: [FleetSoftwareTitle] = []
        let pageSize = 100
        for page in 0..<20 {
            let response: FleetSoftwareListResponse = try await get("software", query: [
                "self_service": "true",
                "page": String(page),
                "per_page": String(pageSize),
            ])
            titles += response.software
            if response.meta?.hasNextResults != true || response.software.count < pageSize {
                break
            }
        }
        return titles
    }

    func selfServiceCategories() async throws -> [FleetSoftwareCategory] {
        let response: FleetCategoriesResponse = try await get("software/self_service_categories")
        return response.selfServiceCategories
    }

    func install(titleID: Int) async throws {
        try await send("POST", "software/install/\(titleID)")
    }

    func uninstall(titleID: Int) async throws {
        try await send("POST", "software/uninstall/\(titleID)")
    }

    func installResult(installUUID: String) async throws -> FleetInstallResult? {
        let response: FleetInstallResultsResponse = try await get("software/install/\(installUUID)/results")
        return response.results
    }

    func uninstallResult(executionID: String) async throws -> FleetScriptResult {
        try await get("software/uninstall/\(executionID)/results")
    }

    func icon(titleID: Int) async throws -> Data {
        try await request("GET", "software/titles/\(titleID)/icon", gated: true)
    }

    func policies() async throws -> [FleetPolicy] {
        let response: FleetPoliciesResponse = try await get("policies")
        return response.policies
    }

    /// Not behind the SSO gate, so it also works before sign-in.
    func desktopSummary() async throws -> FleetDesktopSummary {
        try await get("desktop", gated: false)
    }

    /// Asks Fleet to refresh this Mac's inventory, e.g. after an install.
    func refetch() async throws {
        try await send("POST", "refetch")
    }

    // MARK: - Requests

    private func get<Response: Decodable>(_ path: String, query: [String: String] = [:], gated: Bool = true) async throws -> Response {
        let data = try await request("GET", path, query: query, gated: gated)
        do {
            return try JSONDecoder.fleet.decode(Response.self, from: data)
        } catch {
            Logger.shared.logError("Fleet: couldn't decode \(Response.self) from \(path): \(error)")
            throw FleetError.decoding(String(describing: error))
        }
    }

    private func send(_ method: String, _ path: String) async throws {
        _ = try await request(method, path, gated: true)
    }

    /// Sends a request, retrying once with a re-read token if Fleet rejects a rotated one.
    private func request(_ method: String, _ path: String, query: [String: String] = [:], gated: Bool) async throws -> Data {
        guard let server = FleetDeviceIdentity.serverURL() else { throw FleetError.notConfigured }
        if gated && isSSORequired { throw FleetError.ssoRequired }
        if let blockedUntil, blockedUntil > Date() { throw FleetError.backingOff(until: blockedUntil) }

        var retriedWithNewToken = false
        while true {
            guard let token = currentToken() else { throw FleetError.notConfigured }
            let (data, response) = try await perform(method, path, query: query, server: server, token: token.value)

            switch response.statusCode {
            case 200..<300:
                consecutiveFailures = 0
                blockedUntil = nil
                return data

            case 401:
                let body = try? JSONDecoder.fleet.decode(FleetErrorResponse.self, from: data)
                if body?.ssoRequired == true {
                    Logger.shared.logDebug("Fleet: \(method) \(path) requires Fleet Desktop SSO")
                    isSSORequired = true
                    throw FleetError.ssoRequired
                }
                // The token may have rotated since it was read; re-read and retry exactly once
                if !retriedWithNewToken, reloadToken() != token {
                    retriedWithNewToken = true
                    continue
                }
                registerFailure("\(method) \(path) returned 401")
                throw FleetError.unauthorized

            case 429:
                registerFailure("\(method) \(path) returned 429", minimum: Self.maximumBackoff / 2)
                throw FleetError.rateLimited

            default:
                let message = (try? JSONDecoder.fleet.decode(FleetErrorResponse.self, from: data))?.summary ?? ""
                registerFailure("\(method) \(path) returned \(response.statusCode) \(message)")
                throw FleetError.server(status: response.statusCode, message: message)
            }
        }
    }

    private func perform(_ method: String, _ path: String, query: [String: String], server: URL, token: String) async throws -> (Data, HTTPURLResponse) {
        var components = URLComponents(url: server, resolvingAgainstBaseURL: false)
        var basePath = components?.path ?? ""
        while basePath.hasSuffix("/") { basePath.removeLast() }
        components?.path = "\(basePath)/api/v1/fleet/device/\(token)/\(path)"
        if !query.isEmpty {
            components?.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components?.url else { throw FleetError.notConfigured }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let ssoSessionCookie {
            request.setValue("\(Self.ssoSessionCookieName)=\(ssoSessionCookie)", forHTTPHeaderField: "Cookie")
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw FleetError.network("Invalid response from Fleet")
            }
            Logger.shared.logDebug("Fleet: \(method) \(path) -> \(http.statusCode)")
            return (data, http)
        } catch let error as FleetError {
            throw error
        } catch {
            // The token is part of the URL, so never log the URL itself
            registerFailure("\(method) \(path) failed: \((error as NSError).localizedDescription)")
            throw FleetError.network((error as NSError).localizedDescription)
        }
    }

    // MARK: - Token and backoff

    private func currentToken() -> FleetDeviceIdentity.Token? {
        if let token, FleetDeviceIdentity.tokenModificationDate() == token.modified {
            return token
        }
        return reloadToken()
    }

    @discardableResult
    private func reloadToken() -> FleetDeviceIdentity.Token? {
        token = FleetDeviceIdentity.readToken()
        return token
    }

    private func registerFailure(_ reason: String, minimum: TimeInterval = FleetClient.minimumBackoff) {
        consecutiveFailures += 1
        let delay = min(max(minimum, Self.minimumBackoff * pow(2, Double(consecutiveFailures - 1))), Self.maximumBackoff)
        blockedUntil = Date().addingTimeInterval(delay)
        Logger.shared.logError("Fleet: \(reason); pausing requests for \(Int(delay))s")
    }
}
