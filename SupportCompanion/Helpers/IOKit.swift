//
//  IOKit.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-15.
//

import Foundation
import IOKit

func getPropertyValue(forKey key: String, service: String) -> String? {
    let keyCF = key as CFString
    
    // Attempt to match the service using IOServiceMatching
    var platformExpert = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(service))
    if platformExpert == MACH_PORT_NULL {
        // Fallback to IOServiceNameMatching if the initial match fails
        platformExpert = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceNameMatching(service))
    }
    
    guard platformExpert != MACH_PORT_NULL else {
        return nil
    }
    
    defer {
        IOObjectRelease(platformExpert)
    }

    if let property = IORegistryEntryCreateCFProperty(platformExpert, keyCF, kCFAllocatorDefault, 0)?.takeRetainedValue() {
        if CFGetTypeID(property) == CFStringGetTypeID() {
            return property as? String
        } else if CFGetTypeID(property) == CFDataGetTypeID() {
            let data = property as! Data
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters)
        }
    }
    
    return nil
}
