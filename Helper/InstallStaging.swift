//
//  InstallStaging.swift
//  com.github.macadmins.SupportCompanion.helper
//

import CryptoKit
import Foundation

// MARK: - Helper state

/// The root-owned directory the helper keeps its own state in.
///
/// `/Library/Application Support` is no good for any of it: the app creates its folder there as the
/// logged-in user, and whoever owns a directory can replace what is in it. `/var/db` is root-owned and
/// is where daemon state belongs. `ElevationCoordinator` keeps its deadline and audit log under the
/// same directory for the same reason.
enum HelperState {

    static let directory = "/var/db/com.github.macadmins.SupportCompanion"

    /// Create a directory that only root can read or write, including every level above it.
    ///
    /// Each level is created separately rather than with `withIntermediateDirectories`, so the mode is
    /// applied to all of them and not only to the last one.
    static func makeDirectory(at path: String, permissions: Int16 = 0o700) throws {
        let components = (path as NSString).pathComponents
        var current = "/"

        for component in components where component != "/" {
            current = (current as NSString).appendingPathComponent(component)

            if FileManager.default.fileExists(atPath: current) { continue }

            try FileManager.default.createDirectory(
                atPath: current,
                withIntermediateDirectories: false,
                attributes: [.posixPermissions: permissions, .ownerAccountID: 0, .groupOwnerAccountID: 0]
            )
        }
    }

    /// Append one line to a root-owned log, flattening anything that came from outside first.
    ///
    /// One line per event is the only structure these logs have, so text containing a newline would let
    /// whoever supplied it write entries of their choosing into a root-owned record.
    static func appendLine(_ line: String, toLogAt path: String) {
        try? makeDirectory(at: directory)

        let flattened = line.unicodeScalars
            .map { CharacterSet.controlCharacters.contains($0) ? " " : Character($0) }
            .reduce(into: "") { $0.append($1) }
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(2048)

        let stamped = "\(ISO8601DateFormatter().string(from: Date())) \(flattened)\n"
        guard let data = stamped.data(using: .utf8) else { return }

        if let handle = FileHandle(forWritingAtPath: path) {
            defer { try? handle.close() }
            try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            FileManager.default.createFile(
                atPath: path,
                contents: data,
                attributes: [.posixPermissions: 0o600, .ownerAccountID: 0]
            )
        }
    }
}

// MARK: - Staged file

/// Copies an installer out of the user's reach, and measures it once it is there.
enum StagedFile {

    /// The staging directories, one per installer being considered.
    static let root = HelperState.directory + "/installs"

    /// The largest installer the helper will copy.
    ///
    /// Staging means a second copy on disk, and a standard user handing the helper a very large file is
    /// otherwise a way to fill the boot volume as root.
    static let maximumBytes: Int64 = 8 * 1024 * 1024 * 1024

    private static let chunkSize = 4 * 1024 * 1024

    /// A private directory for one candidate installer.
    static func makeStagingDirectory() throws -> String {
        let path = (root as NSString).appendingPathComponent(UUID().uuidString)
        try HelperState.makeDirectory(at: path)
        return path
    }

    static func remove(_ path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }

    /// Copy what the descriptor refers to into the staging directory.
    ///
    /// The app opens the file and passes the descriptor rather than the path, for two reasons. The app
    /// runs as the user, so it can only open what the user could already read — a path would let a
    /// standard user have root read and measure files they have no access to. And a descriptor names
    /// the file itself rather than a name that can be repointed, so the copy is of what the user
    /// actually double-clicked.
    static func copy(from handle: FileHandle, toDirectory directory: String, fileName: String) throws -> String {
        var info = stat()

        guard fstat(handle.fileDescriptor, &info) == 0 else {
            throw SupportCompanionErrors.helperConnection("Unable to read the installer's file information")
        }

        guard (info.st_mode & S_IFMT) == S_IFREG else {
            throw SupportCompanionErrors.helperConnection("The installer is not a regular file")
        }

        guard info.st_size <= maximumBytes else {
            throw SupportCompanionErrors.helperConnection(
                "The installer is larger than \(maximumBytes / (1024 * 1024 * 1024))GB"
            )
        }

        guard try hasRoom(for: info.st_size) else {
            throw SupportCompanionErrors.helperConnection("There is not enough free space to check this installer")
        }

        // Only the extension is taken from the name the client supplied; the rest is ours. A name is
        // the one part of this a client chooses freely, and it is about to become a path we run
        // commands against.
        let fileExtension = (fileName as NSString).pathExtension.lowercased()
        let safeExtension = fileExtension.allSatisfy(\.isLetter) && !fileExtension.isEmpty ? fileExtension : "pkg"
        let destination = (directory as NSString).appendingPathComponent("installer.\(safeExtension)")

        guard FileManager.default.createFile(
            atPath: destination,
            contents: nil,
            attributes: [.posixPermissions: 0o600, .ownerAccountID: 0]
        ) else {
            throw SupportCompanionErrors.helperConnection("Unable to create a staging file for the installer")
        }

        guard let output = FileHandle(forWritingAtPath: destination) else {
            throw SupportCompanionErrors.helperConnection("Unable to open the staging file for the installer")
        }

        defer { try? output.close() }

        try handle.seek(toOffset: 0)

        while true {
            guard let chunk = try handle.read(upToCount: chunkSize), !chunk.isEmpty else { break }
            try output.write(contentsOf: chunk)
        }

        return destination
    }

    private static func hasRoom(for bytes: Int64) throws -> Bool {
        let values = try URL(fileURLWithPath: "/var/db").resourceValues(forKeys: [.volumeAvailableCapacityKey])

        guard let available = values.volumeAvailableCapacity else { return true }

        // Twice over: the staged copy, and then whatever it installs.
        return Int64(available) > bytes * 2
    }

    /// The SHA-256 of a staged file, read in chunks so a large installer is not held in memory.
    static func sha256(ofFileAt path: String) throws -> String {
        guard let handle = FileHandle(forReadingAtPath: path) else {
            throw SupportCompanionErrors.helperConnection("Unable to read the staged installer")
        }

        defer { try? handle.close() }

        var hasher = SHA256()

        while true {
            guard let chunk = try handle.read(upToCount: chunkSize), !chunk.isEmpty else { break }
            hasher.update(data: chunk)
        }

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
