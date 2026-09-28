import Foundation

// Watches a file for changes. Handles editors that save atomically (write temp + rename)
// by listening for rename/delete and reopening the file descriptor.

class FileWatcher {
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private let filePath: String
    private let queue = DispatchQueue(label: "com.github.macadmins.SupportCompanion.FileWatcher")
    private var pendingReload = false

    init?(filePath: String, eventHandler: @escaping () -> Void) {
        self.filePath = filePath
        guard reopen(eventHandler: eventHandler) else { return nil }
        Logger.shared.logDebug("Initializing file watcher for \(filePath)")
    }

    // Recreate the dispatch source and ensure it is resumed.
    private func reopen(eventHandler: @escaping () -> Void) -> Bool {
        // Tear down old source if any
        if let src = source {
            src.cancel()
            source = nil
        }
        if fileDescriptor >= 0 {
            // fd will be closed by cancel handler; reset our tracking value here
            fileDescriptor = -1
        }

        let fd = open(filePath, O_EVTONLY)
        guard fd >= 0 else {
            Logger.shared.logError("Failed to open file for watching: \(filePath)")
            return false
        }
        fileDescriptor = fd

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .extend, .attrib],
            queue: queue
        )
        src.setCancelHandler { [fd] in
            close(fd)
        }

        // Set handler referencing self.source to always act on the current source
        src.setEventHandler { [weak self] in
            guard let self = self, let current = self.source else { return }
            let flags = current.data

            if flags.contains(.rename) || flags.contains(.delete) {
                Logger.shared.logDebug("FileWatcher: rename/delete detected for \(self.filePath), reopening FD")
                // Under atomic save, our FD now points to the old inode.
                // Reopen the path to attach to the new file, then trigger reload.
                _ = self.reopen(eventHandler: eventHandler)
            }

            // Debounce to avoid multiple loads per single save
            if !self.pendingReload {
                self.pendingReload = true
                self.queue.asyncAfter(deadline: .now() + 0.15) {
                    self.pendingReload = false
                    eventHandler()
                }
            }
        }

        // Resume the new source immediately
        src.resume()
        source = src
        return true
    }

    deinit {
        Logger.shared.logDebug("Deinitializing file watcher")
        source?.cancel() // Clean up; cancel handler closes fd
        source = nil
        // Don't close fileDescriptor here; cancel handler already did it.
        fileDescriptor = -1
    }
}
