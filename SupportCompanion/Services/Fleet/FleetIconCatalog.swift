//
//  FleetIconCatalog.swift
//  SupportCompanion
//
//  Icons for titles Fleet has no icon for, from the icon set Fleet's own web pages use.
//
//  Fleet's My Device page doesn't get these icons from the API: it matches the software name against
//  icons compiled into the page (frontend/pages/SoftwarePage/components/icons/index.ts in fleetdm/fleet).
//  This reads that index from GitHub, matches names the way Fleet does, and downloads only the icons of
//  titles in this Mac's catalog. Icons Fleet draws in code rather than as PNGs (e.g. Slack) aren't covered.
//  Turn it off with `FleetIconsFromGitHub = false`.
//

import AppKit
import Foundation

@MainActor
final class FleetIconCatalog {
    static let shared = FleetIconCatalog()

    private static let base = "https://raw.githubusercontent.com/fleetdm/fleet/main/frontend/pages/SoftwarePage/components/icons/"
    private static let indexRefreshInterval: TimeInterval = 7 * 24 * 3600

    private struct Index: Codable {
        let fetchedAt: Date
        /// Lowercased name prefix → PNG file name.
        let files: [String: String]
    }

    private let session: URLSession
    private let directory: URL?
    private var index: Index?
    private var indexTask: Task<Index?, Never>?
    private var indexUnavailable = false

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.httpCookieStorage = nil
        session = URLSession(configuration: configuration)
        directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("SupportCompanion/FleetIcons", isDirectory: true)
    }

    static var isEnabled: Bool {
        DefaultsStore.value(forKey: "FleetIconsFromGitHub", default: true)
    }

    /// The PNG to download for a title, or nil when Fleet's icon set has none for it.
    func iconURL(for title: FleetSoftwareTitle) async -> URL? {
        guard Self.isEnabled, let index = await loadIndex() else { return nil }
        let names = [title.name, title.title].map(Self.normalized)
        for name in names {
            if let file = Self.match(name, in: index.files),
               let encoded = file.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {
                return URL(string: Self.base + "png/" + encoded)
            }
        }
        return nil
    }

    func download(_ url: URL) async -> Data? {
        guard let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return data
    }

    // MARK: - Matching

    /// Like Fleet's `matchLoosePrefixToKey`: the longest key that is the whole name or a prefix followed by a space.
    static func match(_ name: String, in files: [String: String]) -> String? {
        guard !name.isEmpty else { return nil }
        let key = files.keys
            .filter { name == $0 || name.hasPrefix($0 + " ") }
            .max { $0.count < $1.count }
        return key.flatMap { files[$0] }
    }

    private static func normalized(_ name: String) -> String {
        var name = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if name.hasSuffix(".app") { name.removeLast(4) }
        return name
    }

    /// Reads `SOFTWARE_NAME_TO_ICON_MAP` and the PNG imports it refers to from Fleet's icons/index.ts.
    static func parseIndex(_ source: String) -> [String: String] {
        var pngByVariable: [String: String] = [:]
        // NSRegularExpression rather than regex literals, which older Xcode versions only accept with a
        // compiler flag in Swift 5 mode
        guard let importPattern = try? NSRegularExpression(
                  pattern: #"^import\s+(\w+)\s+from\s+"\./png/([A-Za-z0-9._@+\-]+\.png)";$"#),
              let entryPattern = try? NSRegularExpression(
                  pattern: #"^\s*(?:"([^"]+)"|([A-Za-z0-9_]+))\s*:\s*(\w+)\s*,?\s*$"#) else {
            return [:]
        }

        var files: [String: String] = [:]
        var inMap = false
        for line in source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if let groups = captures(of: importPattern, in: line) {
                if let variable = groups[0], let file = groups[1] {
                    pngByVariable[variable] = file
                }
            } else if line.hasPrefix("export const SOFTWARE_NAME_TO_ICON_MAP") {
                inMap = true
            } else if inMap {
                if line.hasPrefix("}") { break }
                if let groups = captures(of: entryPattern, in: line),
                   let variable = groups[2], let file = pngByVariable[variable] {
                    let key = (groups[0] ?? groups[1] ?? "").trimmingCharacters(in: .whitespaces).lowercased()
                    if !key.isEmpty { files[key] = file }
                }
            }
        }
        return files
    }

    /// The capture groups of a match covering the whole line, or nil if the line doesn't match.
    private static func captures(of pattern: NSRegularExpression, in line: String) -> [String?]? {
        let range = NSRange(line.startIndex..., in: line)
        guard let match = pattern.firstMatch(in: line, range: range), match.range == range else { return nil }
        return (1..<match.numberOfRanges).map { index in
            Range(match.range(at: index), in: line).map { String(line[$0]) }
        }
    }

    // MARK: - Index

    private var indexFile: URL? { directory?.appendingPathComponent("github-index.json") }

    private func loadIndex() async -> Index? {
        if let index, Date().timeIntervalSince(index.fetchedAt) < Self.indexRefreshInterval { return index }
        if index == nil, let indexFile, let data = try? Data(contentsOf: indexFile),
           let saved = try? JSONDecoder().decode(Index.self, from: data) {
            index = saved
            if Date().timeIntervalSince(saved.fetchedAt) < Self.indexRefreshInterval { return saved }
        }
        // Try GitHub once per launch at most; a stale index is still better than none
        guard !indexUnavailable else { return index }
        if let indexTask { return await indexTask.value }

        let task = Task<Index?, Never> { [session] in
            guard let url = URL(string: Self.base + "index.ts"),
                  let (data, response) = try? await session.data(from: url),
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  let source = String(data: data, encoding: .utf8) else { return nil }
            let files = Self.parseIndex(source)
            return files.isEmpty ? nil : Index(fetchedAt: Date(), files: files)
        }
        indexTask = task
        let fetched = await task.value
        indexTask = nil

        guard let fetched else {
            Logger.shared.logDebug("Fleet: couldn't load Fleet's icon index from GitHub")
            indexUnavailable = true
            return index
        }
        index = fetched
        if let directory, let indexFile, let data = try? JSONEncoder().encode(fetched) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? data.write(to: indexFile)
        }
        return fetched
    }
}
