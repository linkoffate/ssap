import Foundation

class Watcher {
    let config: Config
    private var stream: FSEventStreamRef?
    private var knownFiles: Set<String> = []

    init(config: Config) {
        self.config = config
        // Snapshot existing files so we don't process them on startup
        self.knownFiles = Self.scanExistingFiles(in: config.watchDir)
    }

    func start() {
        let pathsToWatch = [config.watchDir] as CFArray
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        guard let stream = FSEventStreamCreate(
            nil,
            eventCallback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5, // latency in seconds
            UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        ) else {
            print("ssap: failed to create FSEvent stream")
            return
        }

        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
    }

    func stop() {
        guard let stream = stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    func handleNewFile(_ path: String) {
        // Only process PNG files with screenshot naming pattern
        guard path.hasSuffix(".png"),
              isScreenshot(path) else { return }

        // Skip if already known
        guard !knownFiles.contains(path) else { return }
        knownFiles.insert(path)

        // Wait a moment for the file to finish writing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            guard FileManager.default.fileExists(atPath: path) else { return }

            if self.config.organize {
                if let organized = try? Organizer.organize(file: path, watchDir: self.config.watchDir) {
                    self.knownFiles.insert(organized)
                    self.showPromptIfEnabled(organized)
                    return
                }
            }
            self.showPromptIfEnabled(path)
        }
    }

    private func showPromptIfEnabled(_ path: String) {
        guard config.promptEnabled else { return }

        // Launch prompt as separate process so daemon stays responsive
        let execPath = ProcessInfo.processInfo.arguments[0]
        let task = Process()
        task.executableURL = URL(fileURLWithPath: execPath)
        task.arguments = ["prompt", path]
        try? task.run()
    }

    private func isScreenshot(_ path: String) -> Bool {
        let name = (path as NSString).lastPathComponent
        // macOS screenshot pattern: 스크린샷 YYYY-MM-DD or Screenshot YYYY-MM-DD
        return name.contains("스크린샷") || name.contains("Screenshot ")
    }

    private static func scanExistingFiles(in dir: String) -> Set<String> {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(atPath: dir) else { return [] }
        var files = Set<String>()
        while let file = enumerator.nextObject() as? String {
            if file.hasSuffix(".png") {
                files.insert((dir as NSString).appendingPathComponent(file))
            }
        }
        return files
    }
}

private func eventCallback(
    streamRef: ConstFSEventStreamRef,
    clientCallBackInfo: UnsafeMutableRawPointer?,
    numEvents: Int,
    eventPaths: UnsafeMutableRawPointer,
    eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    eventIds: UnsafePointer<FSEventStreamEventId>
) {
    guard let info = clientCallBackInfo else { return }
    let watcher = Unmanaged<Watcher>.fromOpaque(info).takeUnretainedValue()

    guard let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] else { return }

    for i in 0..<numEvents {
        let flags = eventFlags[i]
        let path = paths[i]

        // Only react to file creation events
        let isCreated = flags & UInt32(kFSEventStreamEventFlagItemCreated) != 0
        let isFile = flags & UInt32(kFSEventStreamEventFlagItemIsFile) != 0
        let isRenamed = flags & UInt32(kFSEventStreamEventFlagItemRenamed) != 0

        if (isCreated || isRenamed) && isFile {
            watcher.handleNewFile(path)
        }
    }
}
