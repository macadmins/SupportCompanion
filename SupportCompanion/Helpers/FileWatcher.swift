import Foundation

class FileWatcher {
    private var source: DispatchSourceFileSystemObject?
    private let fileDescriptor: Int32

    init?(filePath: String, eventHandler: @escaping () -> Void) {
        let fileDescriptor = open(filePath, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            Logger.shared.logError("Failed to open file: \(filePath)")
            return nil
        }
        self.fileDescriptor = fileDescriptor
        
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor, eventMask: .write, queue: DispatchQueue.global())
        source.setEventHandler(handler: eventHandler)
        source.setCancelHandler {
            close(fileDescriptor)
        }
        Logger.shared.logDebug("Initializing file watcher for \(filePath)")
        source.resume()
        self.source = source
    }
    
    deinit {
        Logger.shared.logDebug("Deinitializing file watcher")
        source?.cancel() // Clean up
        close(fileDescriptor)
    }
}
