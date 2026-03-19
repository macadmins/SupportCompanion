//
//  ConnectionIdentityService.swift
//  com.github.macadmins.SupportCompanion.helper
//
//  Created by Tobias Almén on 2024-11-12.
//

import Foundation

// MARK: - ConnectionIdentityService

enum ConnectionIdentityService {

    // MARK: Constants
    #if DEBUG
    static private let requirementString: CFString = {
        return """
        identifier "\(HelperConstants.bundleID)" and anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = \(HelperConstants.debugSubject)
        """ as CFString
    }()
    #else
    static private let requirementString: CFString = {
        return """
        identifier "\(HelperConstants.bundleID)" and anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = \(HelperConstants.subject)
        """ as CFString
    }()
    #endif
}

// MARK: - Check

extension ConnectionIdentityService {

    /// Check that the connection originates from the client app.
    ///
    /// - throws: If validation failed.
    static func checkConnectionIsValid(connection: NSXPCConnection) throws {
        #if DEBUG
        Logger.shared.logDebug("🔍 Starting connection validation...")
        #endif
        
        let tokenData = try tokenData(in: connection)
        
        #if DEBUG
        Logger.shared.logDebug("✅ Got audit token data")
        #endif
        
        let secCode = try secCode(from: tokenData)
        
        #if DEBUG
        Logger.shared.logDebug("✅ Got SecCode from token")
        #endif
        
        try? logInfo(about: secCode)
        
        #if DEBUG
        Logger.shared.logDebug("🔐 Verifying code signature...")
        #endif
        
        try verifySecCode(secCode: secCode)
        
        #if DEBUG
        Logger.shared.logDebug("✅ Connection validated successfully!")
        #endif
    }
}

// MARK: - Token

extension ConnectionIdentityService {

    /// Get the property `auditToken` from a `NSXPCConnection`.
    ///
    /// - note: This is a hack, see [Woody's Findings](https://www.woodys-findings.com/posts/cocoa-implement-privileged-helper).
    private static func tokenData(in connection: NSXPCConnection) throws -> Data {
        let property = "auditToken"

        guard connection.responds(to: NSSelectorFromString(property)) else {
            throw SupportCompanionErrors.helperConnection("'NSXPCConnection' has no member '\(property)'")
        }
        guard let auditToken = connection.value(forKey: property) else {
            throw SupportCompanionErrors.helperConnection("'\(property)' from connection is 'nil'")
        }
        guard let auditTokenValue = auditToken as? NSValue else {
            throw SupportCompanionErrors.helperConnection("Unable to get 'NSValue' from '\(property)' in 'NSXPCConnection'")
        }
        guard var auditTokenOpaque = auditTokenValue.value(of: audit_token_t.self) else {
            throw SupportCompanionErrors.helperConnection("'\(property)' 'NSValue' is not of type 'audit_token_t'")
        }

        return Data(bytes: &auditTokenOpaque, count: MemoryLayout<audit_token_t>.size)
    }
}

// MARK: - SecCode

extension ConnectionIdentityService {

    private static func secCode(from token: Data) throws -> SecCode {
        let attributesDict = [kSecGuestAttributeAudit: token]

        var secCode: SecCode?
        try SecCodeCopyGuestWithAttributes(nil, attributesDict as CFDictionary, [], &secCode)
            .checkError("SecCodeCopyGuestWithAttributes")

        guard let secCode else {
            throw SupportCompanionErrors.helperConnection("Unable to get secCode from token using 'SecCodeCopyGuestWithAttributes'")
        }

        return secCode
    }

    private static func verifySecCode(secCode: SecCode) throws {
        var secRequirements: SecRequirement?
        
        // Log the expected requirement for debugging
        #if DEBUG
        Logger.shared.logDebug("📋 Expected requirement string: \(requirementString)")
        #endif

        let createStatus = SecRequirementCreateWithString(requirementString, [], &secRequirements)
        
        #if DEBUG
        if createStatus != errSecSuccess {
            Logger.shared.logError("❌ Failed to create requirement from string. Status: \(createStatus)")
        } else {
            Logger.shared.logDebug("✅ Requirement created successfully")
        }
        #endif
        
        try createStatus.checkError("SecRequirementCreateWithString")
        
        // Log the actual requirement for debugging
        #if DEBUG
        do {
            var secStaticCode: SecStaticCode?
            try SecCodeCopyStaticCode(secCode, [], &secStaticCode).checkError("SecCodeCopyStaticCode for requirement")
            
            if let staticCode = secStaticCode {
                var actualRequirement: SecRequirement?
                let status = SecCodeCopyDesignatedRequirement(staticCode, [], &actualRequirement)
                if status == errSecSuccess, let req = actualRequirement {
                    var reqString: CFString?
                    SecRequirementCopyString(req, [], &reqString)
                    if let str = reqString as String? {
                        Logger.shared.logDebug("📋 Actual designated requirement from app: \(str)")
                    }
                } else {
                    Logger.shared.logDebug("⚠️ Could not get designated requirement. Status: \(status)")
                }
            }
        } catch {
            Logger.shared.logDebug("⚠️ Could not get actual requirement: \(error)")
        }
        #endif
        
        let validityStatus = SecCodeCheckValidity(secCode, [], secRequirements)
        
        #if DEBUG
        if validityStatus != errSecSuccess {
            Logger.shared.logError("❌ SecCodeCheckValidity failed. Status: \(validityStatus)")
        } else {
            Logger.shared.logDebug("✅ Code signature validation passed")
        }
        #endif
        
        try validityStatus.checkError("SecCodeCheckValidity")
    }

    private static func logInfo(about secCode: SecCode) throws {
        var secStaticCode: SecStaticCode?
        var cfDictionary: CFDictionary?

        try SecCodeCopyStaticCode(secCode, [], &secStaticCode)
            .checkError("SecCodeCopyStaticCode")

        guard let secStaticCode else {
            throw SupportCompanionErrors.helperConnection("Unable to get a 'SecStaticCode' from 'SecCode'")
        }

        try SecCodeCopySigningInformation(secStaticCode, [], &cfDictionary)
            .checkError("SecCodeCopySigningInformation")

        guard
            let dict = cfDictionary as NSDictionary?,
            let info = dict["info-plist"] as? NSDictionary
        else { return }

        let bundleID = info[kCFBundleIdentifierKey as String] as? NSString ?? "Unknown"
        Logger.shared.logDebug("Received connection request from app with bundle ID '\(bundleID)'")
    }
}
