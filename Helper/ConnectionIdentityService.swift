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
        let tokenData = try tokenData(in: connection)
        let secCode = try secCode(from: tokenData)
        try? logInfo(about: secCode)
        try verifySecCode(secCode: secCode)
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

        try SecRequirementCreateWithString(requirementString, [], &secRequirements)
            .checkError("SecRequirementCreateWithString")
        try SecCodeCheckValidity(secCode, [], secRequirements)
            .checkError("SecCodeCheckValidity")
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
