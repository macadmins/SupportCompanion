//
//  Helper.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-12.
//

import Foundation

// MARK: - Helper

final class Helper: NSObject {

    // MARK: Properties

    let listener: NSXPCListener

    // MARK: Init

    override init() {
        listener = NSXPCListener(machServiceName: HelperConstants.domain)
        super.init()
        listener.delegate = self
    }
}

// MARK: - HelperProtocol

extension Helper: HelperProtocol {

    func executeScript(at path: String) async throws -> String {
        Logger.shared.logDebug("Executing script at \(path)")
        do {
            return try await ExecutionService.executeScript(at: path)
        } catch {
            Logger.shared.logError("Error: \(error.localizedDescription)")
            throw error
        }
    }
    
    func executeCommand(_ command: String, with arguments: [String] = []) async throws -> String {
        Logger.shared.logDebug("Executing command \(command) with arguments: \(arguments)")
        do {
            return try await ExecutionService.executeCommand(command, with: arguments)
        } catch {
            Logger.shared.logError("Error: \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - Run

extension Helper {

    func run() {
        // start listening on new connections
        listener.resume()

        // prevent the terminal application to exit
        RunLoop.current.run()
    }
}


// MARK: - NSXPCListenerDelegate

extension Helper: NSXPCListenerDelegate {

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        do {
            try ConnectionIdentityService.checkConnectionIsValid(connection: newConnection)
        } catch {
            Logger.shared.logError("🛑 Connection \(newConnection) has not been validated. \(error.localizedDescription)")
            return false
        }

        newConnection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        newConnection.remoteObjectInterface = NSXPCInterface(with: RemoteApplicationProtocol.self)
        newConnection.exportedObject = self

        newConnection.resume()
        return true
    }
}
