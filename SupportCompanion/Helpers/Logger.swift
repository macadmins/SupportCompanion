//
//  Logger.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-15.
//

import Foundation

import os

class Logger {
    static let shared = Logger()
    private var logger: OSLog

    private init() {
        let subsystem = Bundle.main.bundleIdentifier ?? "com.github.macadmins.SupportCompanion"
        let category = "SupportCompanion"
        logger = OSLog(subsystem: subsystem, category: category)
    }

    func configure(subsystem: String, category: String) {
        logger = OSLog(subsystem: subsystem, category: category)
    }

    func logInfo(_ message: String) {
        os_log("%{public}@", log: logger, type: .info, message)
    }

    func logError(_ message: String) {
        os_log("%{public}@", log: logger, type: .error, message)
    }
    
    func logDebug(_ message: String) {
        os_log("%{public}@", log: logger, type: .debug, message)
    }
}
