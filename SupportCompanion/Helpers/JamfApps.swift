//
//  JamfApps.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2025-10-13.
//

import Foundation

extension DateFormatter {
    static let shortDayMonth: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX") // stable month abbreviations
        df.setLocalizedDateFormatFromTemplate("d MMM")
        return df
    }()
}

// MARK: - Date helpers (CoreData XML uses absolute seconds since 2001-01-01 a lot)
extension Date {
    static func fromCoreDataEpochSeconds(_ s: String) -> Date? {
        guard let d = Double(s) else { return nil }
        return Date(timeIntervalSinceReferenceDate: d) // 2001-01-01 00:00:00 +0000
    }
}

extension String {
	var normalizedAppName: String {
		trimmingCharacters(in: .whitespacesAndNewlines)
			.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
	}
}

// MARK: - Tiny XML parser (sax-style)

final class SSPlusParser: NSObject, XMLParserDelegate {
    private(set) var policies: [Policy] = []
    private(set) var patches: [Patch] = []

    // parser state
    private var currentObjectType: String? // SSPOLICY, SSPATCH, ...
    private var currentAttributes: [String:String] = [:]
    private var currentAttributeName: String?
    private var currentText = ""

    func parse() async -> Bool {
		let path = (Constants.Paths.jamfSelfServiceData as NSString).expandingTildeInPath
		guard let data = FileManager.default.contents(atPath: path) else {
			Logger.shared.logError("Failure to read storedata file")
			return false
		}
		policies.removeAll()
		patches.removeAll()
		let p = XMLParser(data: data)
        p.delegate = self
        return p.parse()
    }

    // MARK: XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement name: String,
                namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {

        if name == "object" {
            currentObjectType = attributeDict["type"] // e.g. "SSPOLICY"
            currentAttributes = [:]
        } else if name == "attribute" {
            currentAttributeName = attributeDict["name"] // e.g. "name", "version"
            currentText = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText.append(string)
    }

    func parser(_ parser: XMLParser, didEndElement name: String,
                namespaceURI: String?, qualifiedName qName: String?) {

        if name == "attribute" {
            if let key = currentAttributeName {
                // Trim whitespace/newlines — sample has newlines and long spaces.
                currentAttributes[key] = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            currentAttributeName = nil
            currentText = ""
        } else if name == "object" {
            commitCurrentObject()
            currentObjectType = nil
            currentAttributes = [:]
        }
    }

    private func commitCurrentObject() {
        guard let t = currentObjectType else { return }

        switch t {
        case "SSPOLICY":
			let name = (currentAttributes["name"] ?? "").normalizedAppName
            // Extract "#### Version: X" from serverdescription (defensive)
            let desc = currentAttributes["serverdescription"] ?? ""
            let policyVersion = SSPlusParser.extractVersionFromPolicyDescription(desc)

            let installedDate = Date.fromCoreDataEpochSeconds(currentAttributes["installedorupdateddate"] ?? "")
            let installStatus = Int(currentAttributes["installstatus"] ?? "")
			let iconUrl = currentAttributes["iconurl"] ?? ""
            let id = Int(currentAttributes["id"] ?? "") ?? 0
			let postInstallText = currentAttributes["postinstalltext"] ?? ""
            // store policy info
            policies.append(Policy(id: id,
                                   name: name,
                                   policyVersion: policyVersion,
                                   installedOrUpdated: installedDate,
								   installStatus: installStatus,
								   iconUrl: iconUrl,
								   postInstallText: postInstallText))

        case "SSPATCH":
			let name = (currentAttributes["name"] ?? "").normalizedAppName
            guard let version = currentAttributes["version"], !version.isEmpty else { return }
			
			let id = Int(currentAttributes["id"] ?? "") ?? 0
            let available = Date.fromCoreDataEpochSeconds(currentAttributes["availabledate"] ?? "")
            let deadline = Date.fromCoreDataEpochSeconds(currentAttributes["deadline"] ?? "")
            let button = currentAttributes["buttontext"]
            let installStatus = Int(currentAttributes["installstatus"] ?? "")
			
			patches.append(Patch(id: id,
								 name: name,
                                 version: version,
                                 availableDate: available,
                                 deadlineDate: deadline,
                                 buttonText: button,
                                 installStatus: installStatus))

        default:
            break
        }
    }

    private static func extractVersionFromPolicyDescription(_ text: String) -> String? {
        // Example: "#### Version: 139.1.81.137\n\nBrave is ..."
        // Simple, forgiving regex:
        let pattern = #"(?i)\bversion:\s*([0-9A-Za-z\.\-\+_]+)"#
        guard let r = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = text as NSString
        if let m = r.firstMatch(in: text, range: NSMakeRange(0, ns.length)), m.numberOfRanges >= 2 {
            return ns.substring(with: m.range(at: 1))
        }
        return nil
    }
}

// MARK: - “Update available?” logic

enum UpdateLabel: CustomStringConvertible {
    case notYetAvailable(Date)
    case dueBy(Date)
    case overdue(Date)
    case upToDate
    case dueNoDeadline
    case unknown(String)

    var description: String {
        switch self {
        case .notYetAvailable(let a): 
            return "Not yet available (available at \(ISO8601DateFormatter().string(from: a)))"
        case .dueBy(let d):          
            return "Due by \(ISO8601DateFormatter().string(from: d))"
        case .overdue(let d):        
            return "OVERDUE since \(ISO8601DateFormatter().string(from: d))"
        case .upToDate:              
            return "Up to date (by dates)"
        case .dueNoDeadline:         
            return "Due (no deadline)"
        case .unknown(let why):     
            return "Unknown (\(why))"
        }
    }
}

/// If `requireVersionMismatch` is true, we only flag "needed" when the policy version != patch version.
/// If false, we rely on dates alone (recommended when policyVersion can be missing/noisy).
func evaluateUpdate(policy: Policy, patch: Patch, now: Date = .init()) -> (needed: Bool, label: UpdateLabel) {

    func due(_ deadline: Date?) -> UpdateLabel {
        deadline.map { .dueBy($0) } ?? .dueNoDeadline
    }

    // 1. Missing availability → version-only check
    guard let avail = patch.availableDate else {
        if let pv = policy.policyVersion {
            return (pv != patch.version, pv != patch.version ? due(nil) : .upToDate)
        }
        return (false, .unknown("missing availableDate"))
    }

    // 2. Overdue beats everything
    if let d = patch.deadlineDate, now >= d {
		// first try version matching
		
        return (true, .overdue(d))
    }

    // 3. Not yet available
    if now < avail {
        return (false, .notYetAvailable(avail))
    }

    // 4. Facts
    let installedAfterAvail = (policy.installedOrUpdated ?? .distantPast) >= avail
    let versionMatches = policy.policyVersion.map { $0 == patch.version } // Optional<Bool>

    // 5. Installed after availability
    if installedAfterAvail {
        switch versionMatches {
        case .some(false): return (true, due(patch.deadlineDate))   // known mismatch
        default:            return (false, .upToDate)               // match or nil → trust the date
        }
    }

    // 6. Installed before availability or unknown install time
    if let d = patch.deadlineDate {
        return (true, .dueBy(d)) // deadline drives even without version
    }

    switch versionMatches {
    case .some(true):  return (false, .upToDate)
    case .some(false): return (true, .dueNoDeadline)
    case .none:        return (false, .unknown("missing policyVersion past availability"))
    }
}

func computeUpdates(policies: [Policy],
                    patches: [Patch],
					now: Date = Date()) async -> ([PendingJamfUpdate], Int, Int) {

    // MARK: - Non-hardcoded fuzzy name matching helpers
    func canonicalTokens(_ s: String) -> [String] {
        // Lowercase and remove non-alphanumerics to get stable tokens
        let lowered = s.lowercased()
        let cleaned = lowered.replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression)
        let tokens = cleaned.split(separator: " ").map(String.init)
        // Remove very short/common tokens to reduce false positives
        let stop: Set<String> = ["client", "for", "the", "and", "app", "apps", "application", "meetings", "installer", "update", "patch"]
        return tokens.filter { $0.count >= 3 && !stop.contains($0) }
    }

    func fuzzyMatchPolicy(for patchName: String, in dict: [String: Policy]) -> Policy? {
        let pTokens = Set(canonicalTokens(patchName))
        guard !pTokens.isEmpty else { return nil }

        var best: (policy: Policy, score: Double)?
        for (policyName, policy) in dict {
            let t = Set(canonicalTokens(policyName))
            if t.isEmpty { continue }
            let overlap = Double(pTokens.intersection(t).count)
            let denom = Double(min(pTokens.count, t.count))
            let score = denom > 0 ? overlap / denom : 0
            // Threshold tuned for distinctive names like "zoom", "slack", "chrome".
            if score >= 0.5 {
                if let current = best {
                    if score > current.score {
                        best = (policy, score)
                    } else if score == current.score {
                        // Tie-break using existing recency/priority logic
                        let s0 = policy.installStatus ?? 0
                        let s1 = current.policy.installStatus ?? 0
                        if s0 > s1 || (s0 == s1 && (policy.installedOrUpdated ?? .distantPast) > (current.policy.installedOrUpdated ?? .distantPast)) {
                            best = (policy, score)
                        }
                    }
                } else {
                    best = (policy, score)
                }
            }
        }
        return best?.policy
    }

	// Keep one policy per name: the newest (by installedOrUpdated date)
	let policiesByName: [String: Policy] = Dictionary(grouping: policies, by: { $0.name })
		.compactMapValues { group in
			group.sorted {
				let s0 = $0.installStatus ?? 0, s1 = $1.installStatus ?? 0
				if s0 != s1 { return s0 > s1 }
				return ($0.installedOrUpdated ?? .distantPast) > ($1.installedOrUpdated ?? .distantPast)
			}.first
		}
    var results: [PendingJamfUpdate] = []
    var matchedPolicyNames = Set<String>()
    var updateCount = 0
    var upToDateCount = 0

    for patch in patches {
        // Try exact match by normalized name first
        var matchedPolicy: Policy? = policiesByName[patch.name]
        // Fallback to fuzzy token-based match if exact match fails
        if matchedPolicy == nil {
            matchedPolicy = fuzzyMatchPolicy(for: patch.name, in: policiesByName)
        }
        guard let policy = matchedPolicy else { continue }
        matchedPolicyNames.insert(policy.name)

        let (needed, label) = evaluateUpdate(policy: policy, patch: patch, now: now)
        let details = "available=\(patch.availableDate?.description ?? "nil"), " +
                      "deadline=\(patch.deadlineDate?.description ?? "nil"), " +
                      "lastInstall=\(policy.installedOrUpdated?.description ?? "nil"), " +
                      "policyVersion=\(policy.policyVersion ?? "nil"), " +
                      "patchVersion=\(patch.version)"
		if needed {
			results.append(PendingJamfUpdate(
				id: UUID(),
				name: patch.name,
				version: patch.version,
				needsUpdate: needed,
				label: label,
				details: details,
				showInfoIcon: !details.isEmpty,
				dueBy: patch.deadlineDate.map { DateFormatter.shortDayMonth.string(from: $0) },
				patchId: patch.id,
				policyName: policy.name
			))
		}

        // Count how many updates we have versus how many apps are up to date
        if needed {
            updateCount += 1
        } else {
            upToDateCount += 1
        }
    }

    // Fallback: if there are no patches (or some policies have no corresponding patch),
    // treat installed policies (installStatus == 4) as up-to-date so the overall percent
    // does not show 0% patched purely due to missing patch objects.
    if patches.isEmpty {
        for (_, policy) in policiesByName {
            if (policy.installStatus ?? 0) == 4 {
                upToDateCount += 1
            }
        }
    } else {
        // Also count installed policies that did not have a matching patch name.
        for (name, policy) in policiesByName where !matchedPolicyNames.contains(name) {
            if (policy.installStatus ?? 0) == 4 {
                upToDateCount += 1
            }
        }
    }

    return (results, updateCount, upToDateCount)
}

func getInstalledJamfAppsFromStore() async -> [String: Any] {
	let path = (Constants.Paths.jamfSelfServiceData as NSString).expandingTildeInPath
    guard let _ = FileManager.default.contents(atPath: path) else {
        Logger.shared.logError("Failure to read storedata file")
        return [:]
    }
    var apps: [String: Any] = [:]
    let parser = SSPlusParser()
    let parsed = await parser.parse()
    if !parsed {
        Logger.shared.logError("Failed to parse Jamf storedata XML")
        return [:]
    }
    for policy in parser.policies {
		if policy.installStatus == 4 {
            // verify the app exists in /Applications or ~/Applications
            let appPath1 = "/Applications/\(policy.name).app"
            let appPath2 = ("~/Applications/\(policy.name).app" as NSString).expandingTildeInPath
            if !FileManager.default.fileExists(atPath: appPath1) && !FileManager.default.fileExists(atPath: appPath2) {
                continue
            }
            // if policy.policyVersion is nil or empty, try to get version from app's Info.plist
            var policyVersion = policy.policyVersion
            if (policyVersion ?? "").isEmpty {
                let plistPath = FileManager.default.fileExists(atPath: appPath1) ? "\(appPath1)/Contents/Info.plist" : "\(appPath2)/Contents/Info.plist"
				policyVersion = getAppVersion(plistPath: plistPath)
			}
			// store app info
			apps[policy.name] = [
                "id": policy.id,
				"name": policy.name,
				"version": policyVersion ?? "",
				"iconUrl": policy.iconUrl ?? "",
				"postInstallText": policy.postInstallText ?? ""
			]
		}
    }
    return apps
}

func downloadAppIcon(forApp: InstalledApp) async -> String {
	guard let url = URL(string: forApp.iconUrl ?? "") else { return "" }

    // first try to load from cache
    let fileManager = FileManager.default
    guard let appSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
        Logger.shared.logError("Failed to locate Application Support directory.")
        return ""
    }

    let appSupportJamfDirURL = appSupportDirectory.appendingPathComponent("SupportCompanion/JamfIcons")
    let cachedIcons = (try? fileManager.contentsOfDirectory(at: appSupportJamfDirURL, includingPropertiesForKeys: nil, options: [])) ?? []
    for icon in cachedIcons {
        if icon.lastPathComponent.contains(forApp.name) {
            Logger.shared.logDebug("Using cached icon for \(forApp.name) at \(icon.path)")
            return icon.path
        }
    }

    // get icon data
    guard let (iconData, response) = try? await URLSession.shared.data(from: url),
          let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
        Logger.shared.logError("Failed to download icon from \(forApp.iconUrl ?? "nil")")
        return ""
    }

    // Ensure directory exists
    if !fileManager.fileExists(atPath: appSupportJamfDirURL.path) {
        do {
            try fileManager.createDirectory(at: appSupportJamfDirURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            Logger.shared.logError("Failed to create app support dir: \(error.localizedDescription)")
            return ""
        }
    }

    // Save the icon data to a file
    let iconFileURL = appSupportJamfDirURL.appendingPathComponent("\(forApp.name).png")
    do {
        Logger.shared.logDebug("Saving icon for \(forApp.name) to \(iconFileURL.path)")
        try iconData.write(to: iconFileURL)
    } catch {
        Logger.shared.logError("Failed to save app icon: \(error.localizedDescription)")
        return ""
    }
    return iconFileURL.path
}

