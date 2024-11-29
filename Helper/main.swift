//
//  main.swift
//  Helper
//
//  Created by Tobias Almén on 2024-11-12.
//

import Foundation

Logger.shared.configure(subsystem: "com.github.macadmins.SupportCompanion.helper", category: "SupportCompanion.helper")
Logger.shared.logInfo("Support Companion Helper started.")
let helper = Helper()
helper.run()
