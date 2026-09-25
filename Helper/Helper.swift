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

// MARK: - Run

extension Helper {

    func run() {
        // Take back any administrator rights that outlived the last run before accepting connections
        ElevationCoordinator.shared.reconcileOnLaunch()

        // Clear staged installers, and any disk image still attached, that a previous run left behind
        InstallCoordinator.shared.reconcileOnLaunch()

        // start listening on new connections
        listener.resume()

        // prevent the terminal application to exit
        RunLoop.current.run()
    }
}


// MARK: - NSXPCListenerDelegate

extension Helper: NSXPCListenerDelegate {

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        let clientUID: uid_t

        do {
            clientUID = try ConnectionIdentityService.checkConnectionIsValid(connection: newConnection)
        } catch {
            Logger.shared.logError("🛑 Connection \(newConnection) has not been validated. \(error.localizedDescription)")
            return false
        }

        guard let clientUserName = HelperService.userName(forUID: clientUID) else {
            Logger.shared.logError("🛑 Connection \(newConnection) has no user account behind uid \(clientUID)")
            return false
        }

        newConnection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        newConnection.remoteObjectInterface = NSXPCInterface(with: RemoteApplicationProtocol.self)

        // One service object per connection, carrying the identity the kernel vouched for, so that
        // operations act on the user who actually connected.
        newConnection.exportedObject = HelperService(clientUID: clientUID, clientUserName: clientUserName)

        newConnection.resume()
        return true
    }
}
