//
//  DeviceInfo.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-14.
//

import Foundation

struct DeviceInfo: Identifiable, Equatable {
    let id: UUID
    let hostName: String
    let osVersion: String
    let osBuild: String
    let cpuType: String
    let ram: String
    var ipAddress: String
    let serialNumber: String
    var lastRestart: Int
    let model: String
    
    static func == (lhs: DeviceInfo, rhs: DeviceInfo) -> Bool {
        return lhs.id == rhs.id
    }
    
    func toKeyValuePairs() -> [(key: String, display: String, value: InfoValue, category: String)] {
        return [
            // Hardware Specifications
            (
                key: Constants.DeviceInfo.Keys.hostName,
                display: Constants.DeviceInfo.Labels.hostName,
                value: .string(hostName).toUpper(),
                category: Constants.DeviceInfo.Categories.hardwareSpecs
            ),
            (
                key: Constants.DeviceInfo.Keys.serialNumber,
                display: Constants.DeviceInfo.Labels.serialNumber,
                value: .string(serialNumber),
                category: Constants.DeviceInfo.Categories.hardwareSpecs
            ),
            (
                key: Constants.DeviceInfo.Keys.model,
                display: Constants.DeviceInfo.Labels.model,
                value: .string(model),
                category: Constants.DeviceInfo.Categories.hardwareSpecs
            ),
            (
                key: Constants.DeviceInfo.Keys.processor,
                display: Constants.DeviceInfo.Labels.cpuType,
                value: .string(cpuType),
                category: Constants.DeviceInfo.Categories.hardwareSpecs
            ),
            (
                key: Constants.DeviceInfo.Keys.memory,
                display: Constants.DeviceInfo.Labels.ram,
                value: .string(ram),
                category: Constants.DeviceInfo.Categories.hardwareSpecs
            ),
            
            // System Details
            (
                key: Constants.DeviceInfo.Keys.osVersion,
                display: Constants.DeviceInfo.Labels.osVersion,
                value: .string(osVersion),
                category: Constants.DeviceInfo.Categories.systemInfo
            ),
            (
                key: Constants.DeviceInfo.Keys.osBuild,
                display: Constants.DeviceInfo.Labels.osBuild,
                value: .string(osBuild),
                category: Constants.DeviceInfo.Categories.systemInfo
            ),
            (
                key: Constants.DeviceInfo.Keys.lastRestart,
                display: Constants.DeviceInfo.Labels.lastRestart,
                value: .int(lastRestart),
                category: Constants.DeviceInfo.Categories.systemInfo
            ),
            
            // Network Information
            (
                key: Constants.DeviceInfo.Keys.ipAddress,
                display: Constants.DeviceInfo.Labels.ipAddress,
                value: .string(ipAddress),
                category: Constants.DeviceInfo.Categories.networkInfo
            )
        ]
    }
    
    func toKeyValuePairsCompact() -> [(key: String, display: String, value: InfoValue)] {
        return [
            (
                key: Constants.DeviceInfo.Keys.osVersion,
                display: Constants.DeviceInfo.Labels.osVersion,
                value: .string(osVersion)
            ),
            (
                key: Constants.DeviceInfo.Keys.osBuild,
                display: Constants.DeviceInfo.Labels.osBuild,
                value: .string(osBuild)
            ),
            (
                key: Constants.DeviceInfo.Keys.lastRestart,
                display: Constants.DeviceInfo.Labels.lastRestart,
                value: .int(lastRestart)
            )
        ]
    }
}
