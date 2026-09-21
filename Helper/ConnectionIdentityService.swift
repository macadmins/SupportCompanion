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
    /// - returns: The effective uid of the connecting process, as reported by the kernel.
    /// - throws: If validation failed.
    @discardableResult
    static func checkConnectionIsValid(connection: NSXPCConnection) throws -> uid_t {
        #if DEBUG
        Logger.shared.logDebug("🔍 Starting connection validation...")
        #endif
        
        let auditToken = try auditToken(in: connection)
        let tokenData = withUnsafeBytes(of: auditToken) { Data($0) }
        
        #if DEBUG
        Logger.shared.logDebug("✅ Got audit token data")
        #endif
        
        let secCode = try secCode(from: tokenData)
        
        #if DEBUG
        Logger.shared.logDebug("✅ Got SecCode from token")
        Logger.shared.logDebug("🔐 Verifying code signature...")
        #endif
        
        // Signature first: nothing read out of the client's signing information means anything
        // until the signature over it has been checked.
        try verifySecCode(secCode: secCode)
        
        try? logInfo(about: secCode)
        
        try verifyClientPolicy(secCode: secCode)
        
        #if DEBUG
        Logger.shared.logDebug("✅ Connection validated successfully!")
        #endif
        
        return audit_token_to_euid(auditToken)
    }
}

// MARK: - Token

extension ConnectionIdentityService {

    /// Get the property `auditToken` from a `NSXPCConnection`.
    ///
    /// - note: This is a hack, see [Woody's Findings](https://www.woodys-findings.com/posts/cocoa-implement-privileged-helper).
    private static func auditToken(in connection: NSXPCConnection) throws -> audit_token_t {
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
        guard let auditTokenOpaque = auditTokenValue.value(of: audit_token_t.self) else {
            throw SupportCompanionErrors.helperConnection("'\(property)' 'NSValue' is not of type 'audit_token_t'")
        }

        return auditTokenOpaque
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

// MARK: - Client policy

extension ConnectionIdentityService {

    /// Check the connecting client against the policy the signature cannot express.
    ///
    /// A valid signature only proves the caller is *a* Support Companion build signed by us. Every
    /// release we have ever shipped satisfies it, including builds that predate the administrator-managed
    /// gate on `IsPrivileged`, so on its own it lets a user keep an old copy around and use it to reach
    /// this helper. These three checks close that gap:
    ///
    /// - **Version floor.** Builds older than `HelperConstants.minimumClientVersion` honor `IsPrivileged`
    ///   from any preference domain, including one a standard user can write with `defaults write`.
    /// - **Hardened runtime.** Without it, a legitimate client can be injected into and used as a proxy.
    /// - **Install path.** `/Applications` is not writable by a standard user, so a downgraded copy run
    ///   from a home folder is rejected before the version even matters. Skipped in debug builds, which
    ///   run out of DerivedData.
    private static func verifyClientPolicy(secCode: SecCode) throws {
        let info = try signingInformation(about: secCode)

        try verifyClientVersion(info: info)
        try verifyHardenedRuntime(info: info)

        #if !DEBUG
        try verifyClientPath(info: info)
        #endif

        #if DEBUG
        Logger.shared.logDebug("✅ Client policy checks passed")
        #endif
    }

    private static func verifyClientVersion(info: NSDictionary) throws {
        guard let plist = info["info-plist"] as? NSDictionary else {
            throw SupportCompanionErrors.helperConnection("Unable to read the client's Info.plist to check its version")
        }

        let rawVersion = plist["CFBundleShortVersionString"] as? String
            ?? plist["CFBundleVersion"] as? String

        guard let rawVersion else {
            throw SupportCompanionErrors.helperConnection("Client reports no version")
        }

        let minimum = HelperConstants.minimumClientVersion

        // `a >= b` for version components, which Array does not provide directly
        let isOlder = versionComponents(rawVersion).lexicographicallyPrecedes(versionComponents(minimum))

        guard !isOlder else {
            throw SupportCompanionErrors.helperConnection(
                "Client version \(rawVersion) is older than the minimum supported version \(minimum)"
            )
        }
    }

    private static func verifyHardenedRuntime(info: NSDictionary) throws {
        guard let rawFlags = (info[kSecCodeInfoFlags as String] as? NSNumber)?.uint32Value else {
            throw SupportCompanionErrors.helperConnection("Unable to read the client's code signing flags")
        }

        guard SecCodeSignatureFlags(rawValue: rawFlags).contains(.runtime) else {
            throw SupportCompanionErrors.helperConnection("Client is not signed with the hardened runtime")
        }
    }

    private static func verifyClientPath(info: NSDictionary) throws {
        let executablePath: String?

        if let url = info[kSecCodeInfoMainExecutable as String] as? URL {
            executablePath = url.path
        } else {
            executablePath = info[kSecCodeInfoMainExecutable as String] as? String
        }

        guard let executablePath else {
            throw SupportCompanionErrors.helperConnection("Unable to read the client's executable path")
        }

        guard executablePath.hasPrefix(HelperConstants.appPath + "/") else {
            throw SupportCompanionErrors.helperConnection(
                "Client runs from \(executablePath) rather than \(HelperConstants.appPath)"
            )
        }
    }

    /// Leading numeric components of a version string, so that the four-component build version
    /// the release script writes ("3.0.0.81132") compares correctly against a three-component minimum.
    private static func versionComponents(_ version: String) -> [Int] {
        var components: [Int] = []

        for part in version.split(separator: ".") {
            guard let number = Int(part) else { break }
            components.append(number)
        }

        return components
    }

    private static func signingInformation(about secCode: SecCode) throws -> NSDictionary {
        var secStaticCode: SecStaticCode?
        var cfDictionary: CFDictionary?

        try SecCodeCopyStaticCode(secCode, [], &secStaticCode)
            .checkError("SecCodeCopyStaticCode")

        guard let secStaticCode else {
            throw SupportCompanionErrors.helperConnection("Unable to get a 'SecStaticCode' from 'SecCode'")
        }

        try SecCodeCopySigningInformation(secStaticCode, [], &cfDictionary)
            .checkError("SecCodeCopySigningInformation")

        guard let dictionary = cfDictionary as NSDictionary? else {
            throw SupportCompanionErrors.helperConnection("Unable to read the client's signing information")
        }

        return dictionary
    }
}
