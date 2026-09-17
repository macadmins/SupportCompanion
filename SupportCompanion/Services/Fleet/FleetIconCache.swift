//
//  FleetIconCache.swift
//  SupportCompanion
//

import AppKit
import CryptoKit
import Foundation

/// Icons for Fleet software titles, in order of preference:
/// 1. The custom or App Store icon Fleet has for the title (`icon_url`), cached on disk.
/// 2. The icon of the installed app, or the one saved the last time it was seen installed.
/// 3. The icon Fleet's own web pages would show, from Fleet's icon set on GitHub (see FleetIconCatalog).
///
/// Only titles with an `icon_url` are requested from Fleet: a request for a title without an icon would
/// fail, and failed requests count toward Fleet's IP ban.
@MainActor
final class FleetIconCache {
    static let shared = FleetIconCache()

    private var memory: [String: NSImage] = [:]
    private var inFlight: [String: Task<NSImage?, Never>] = [:]
    private var failedKeys: Set<String> = []
    private let directory: URL? = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
        .appendingPathComponent("SupportCompanion/FleetIcons", isDirectory: true)

    /// Icon available without a network request, for the first render.
    func cachedIcon(for title: FleetSoftwareTitle) -> NSImage? {
        if let key = cacheKey(for: title), let image = storedImage(forKey: key) {
            return image
        }
        return installedAppIcon(for: title) ?? storedImage(forKey: catalogKey(for: title))
    }

    func icon(for title: FleetSoftwareTitle) async -> NSImage? {
        if let key = cacheKey(for: title), let image = await download(key: key, { try? await FleetClient.shared.icon(titleID: title.id) }) {
            return image
        }
        if let image = installedAppIcon(for: title) {
            return image
        }
        return await download(key: catalogKey(for: title)) {
            guard let url = await FleetIconCatalog.shared.iconURL(for: title) else { return nil }
            return await FleetIconCatalog.shared.download(url)
        }
    }

    /// Returns the stored image for `key`, or downloads and stores it. A key that failed isn't retried this session.
    private func download(key: String, _ fetch: @escaping @MainActor () async -> Data?) async -> NSImage? {
        if let image = storedImage(forKey: key) { return image }
        if failedKeys.contains(key) { return nil }
        if let task = inFlight[key] { return await task.value }

        let task = Task<NSImage?, Never> { [directory] in
            guard let data = await fetch(), let image = NSImage(data: data) else { return nil }
            if let directory {
                try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try? data.write(to: directory.appendingPathComponent("\(key).png"))
            }
            return image
        }
        inFlight[key] = task
        let image = await task.value
        inFlight[key] = nil
        if let image {
            memory[key] = image
        } else {
            failedKeys.insert(key)
        }
        return image
    }

    private func storedImage(forKey key: String) -> NSImage? {
        if let image = memory[key] { return image }
        if let url = fileURL(forKey: key), let image = NSImage(contentsOf: url) {
            memory[key] = image
            return image
        }
        return nil
    }

    private func catalogKey(for title: FleetSoftwareTitle) -> String {
        "github-\(title.id)"
    }

    /// Changes when the icon on Fleet changes. The device token in `icon_url` rotates, so it's left out.
    private func cacheKey(for title: FleetSoftwareTitle) -> String? {
        guard let iconUrl = title.iconUrl, !iconUrl.isEmpty else { return nil }
        let withoutToken = iconUrl.replacingOccurrences(of: #"/device/[^/]+/"#, with: "/device/-/", options: .regularExpression)
        let hash = SHA256.hash(data: Data(withoutToken.utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
        return "\(title.id)-\(hash)"
    }

    private func fileURL(forKey key: String) -> URL? {
        guard let url = directory?.appendingPathComponent("\(key).png"),
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    /// The icon of the app on this Mac, found by Fleet's installed paths, bundle identifier, or name.
    /// Fleet's web page shows icons bundled with its front end for titles without a custom icon, which
    /// the device API doesn't expose, so this is the only other source.
    private func installedAppIcon(for title: FleetSoftwareTitle) -> NSImage? {
        let savedKey = "app-\(title.id)"
        if let path = installedAppPath(for: title) {
            let icon = NSWorkspace.shared.icon(forFile: path)
            if memory[savedKey] == nil {
                memory[savedKey] = icon
                saveAppIcon(icon, key: savedKey)
            }
            return icon
        }
        return storedImage(forKey: savedKey)
    }

    /// Keeps an installed app's icon so the title still has one after the app is uninstalled.
    private func saveAppIcon(_ icon: NSImage, key: String) {
        guard let directory else { return }
        let size = NSSize(width: 128, height: 128)
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        icon.draw(in: NSRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()
        guard let data = bitmap.representation(using: .png, properties: [:]) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: directory.appendingPathComponent("\(key).png"))
    }

    private func installedAppPath(for title: FleetSoftwareTitle) -> String? {
        let fileManager = FileManager.default
        let paths = (title.installedVersions ?? []).flatMap { $0.installedPaths ?? [] }
        if let path = paths.first(where: { fileManager.fileExists(atPath: $0) }) {
            return path
        }

        let bundleIDs = ([title.bundleIdentifier] + (title.installedVersions ?? []).map(\.bundleIdentifier))
            .compactMap { $0 }.filter { !$0.isEmpty }
        for bundleID in bundleIDs {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                return url.path
            }
        }

        // Titles for macOS apps are named after the app bundle, e.g. "Audacity" or "Audacity.app"
        for name in Set([title.name, title.title]) where !name.isEmpty && !name.contains("/") {
            let bundleName = name.hasSuffix(".app") ? name : "\(name).app"
            for folder in ["/Applications", "/Applications/Utilities", NSHomeDirectory() + "/Applications"] {
                let path = "\(folder)/\(bundleName)"
                if fileManager.fileExists(atPath: path) {
                    return path
                }
            }
        }
        return nil
    }
}
