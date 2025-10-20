//
//  HelperRemoteProvider.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-12.
//

import Foundation
import ServiceManagement

// MARK: - HelperRemoteProvider

/// Provide a `HelperProtocol` object to request the helper.
enum HelperRemoteProvider {

    // MARK: Computed

    private static var isHelperInstalled: Bool { FileManager.default.fileExists(atPath: HelperConstants.helperPath) }
    
    // MARK: Exported app proxy for XPC (optional but safer than exporting the enum type)
    private final class RemoteAppProxy: NSObject, RemoteApplicationProtocol {}
    private static let exportedAppProxy = RemoteAppProxy()
}

// MARK: - Remote

extension HelperRemoteProvider {

    static func remote() async throws -> some HelperProtocol {
        let connection = try connection()

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<any HelperProtocol, Error>) in
            let continuationResume = ContinuationResume()

            // Setup the error handler
            let helper = connection.remoteObjectProxyWithErrorHandler { error in
                if continuationResume.shouldResume() {
                    continuation.resume(throwing: error)
                }
            }

            // Attempt to unwrap the helper
            guard let unwrappedHelper = helper as? HelperProtocol else {
                if continuationResume.shouldResume() {
                    // If helper is invalid, throw a custom error
                    let error = SupportCompanionErrors.helperConnection("Unable to get a valid 'HelperProtocol' object for an unknown reason")
                    continuation.resume(throwing: error)
                }
                return
            }

            // Success: Return the unwrapped helper
            if continuationResume.shouldResume() {
                continuation.resume(returning: unwrappedHelper)
            }
        }
    }
}

// MARK: - Install helper

extension HelperRemoteProvider {

    /// Install the Helper in the privileged helper tools folder and register the daemon using SMAppService
    private static func installHelperModern() throws {
        do {
			let service = SMAppService.daemon(plistName: HelperConstants.domain)
            try service.register()
        } catch {
            Logger.shared.logError("SMAppService register failed: \(error.localizedDescription)")
            throw SupportCompanionErrors.helperInstallation("Error while installing the Helper: \(error.localizedDescription)")
        }
    }

    private static func installHelper() throws {
		try installHelperModern()
    }
}

// MARK: - Connection

extension HelperRemoteProvider {

    static private func connection() throws -> NSXPCConnection {
        if !isHelperInstalled {
            try installHelper()
        }
        return createConnection()
    }

    private static func createConnection() -> NSXPCConnection {
        let connection = NSXPCConnection(machServiceName: HelperConstants.domain, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)
        connection.exportedInterface = NSXPCInterface(with: RemoteApplicationProtocol.self)
        connection.exportedObject = exportedAppProxy

        connection.invalidationHandler = {
            if isHelperInstalled {
                Logger.shared.logError("Unable to connect to Helper although it is installed")
            } else {
                Logger.shared.logError("Helper is not installed")
            }
        }

        connection.resume()

        return connection
    }
}

// MARK: - ContinuationResume

extension HelperRemoteProvider {

    /// Helper class to safely access a boolean when using a continuation to get the remote.
    private final class ContinuationResume: @unchecked Sendable {

        // MARK: Properties

        private let unfairLockPointer: UnsafeMutablePointer<os_unfair_lock_s>
        private var alreadyResumed = false

        // MARK: Computed

        /// `true` if the continuation should resume.
        func shouldResume() -> Bool {
            os_unfair_lock_lock(unfairLockPointer)
            defer { os_unfair_lock_unlock(unfairLockPointer) }

            if alreadyResumed {
                return false
            } else {
                alreadyResumed = true
                return true
            }
        }

        // MARK: Init

        init() {
            unfairLockPointer = UnsafeMutablePointer<os_unfair_lock_s>.allocate(capacity: 1)
            unfairLockPointer.initialize(to: os_unfair_lock())
        }

        deinit {
            unfairLockPointer.deallocate()
        }
    }
}
