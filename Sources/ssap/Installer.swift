import Foundation

struct Installer {
    static let plistName = "com.ssap.agent"
    static var plistPath: String {
        NSHomeDirectory() + "/Library/LaunchAgents/\(plistName).plist"
    }

    static func install() throws {
        let fm = FileManager.default
        let execPath = ProcessInfo.processInfo.arguments[0]
        let resolvedExec = resolveSymlink(execPath)

        // 1. Create default config if not exists
        let config = try Config.load()
        if !fm.fileExists(atPath: Config.configPath) {
            try config.createDefaultConfig()
            print("✓ Created config at \(Config.configPath)")
        }

        // 2. Create watch directory
        try fm.createDirectory(atPath: config.watchDir, withIntermediateDirectories: true)
        print("✓ Watch directory: \(config.watchDir)")

        // 3. Set macOS screenshot location
        let setLocation = Process()
        setLocation.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        setLocation.arguments = ["write", "com.apple.screencapture", "location", config.watchDir]
        try setLocation.run()
        setLocation.waitUntilExit()

        // Restart SystemUIServer to apply
        let restart = Process()
        restart.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        restart.arguments = ["SystemUIServer"]
        try restart.run()
        restart.waitUntilExit()
        print("✓ macOS screenshot location set to \(config.watchDir)")

        // 4. Install LaunchAgent
        let plist: [String: Any] = [
            "Label": plistName,
            "ProgramArguments": [resolvedExec, "watch"],
            "RunAtLoad": true,
            "KeepAlive": true,
            "StandardOutPath": NSHomeDirectory() + "/.config/ssap/ssap.log",
            "StandardErrorPath": NSHomeDirectory() + "/.config/ssap/ssap.error.log",
        ]

        let plistDir = (plistPath as NSString).deletingLastPathComponent
        try fm.createDirectory(atPath: plistDir, withIntermediateDirectories: true)

        let plistData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try plistData.write(to: URL(fileURLWithPath: plistPath))
        print("✓ LaunchAgent installed at \(plistPath)")

        // 5. Load the agent
        let load = Process()
        load.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        load.arguments = ["load", plistPath]
        try load.run()
        load.waitUntilExit()
        print("✓ ssap daemon started")

        print("\nssap installed successfully. New screenshots will be organized and tagged automatically.")
    }

    static func uninstall() throws {
        // 1. Unload LaunchAgent
        if FileManager.default.fileExists(atPath: plistPath) {
            let unload = Process()
            unload.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            unload.arguments = ["unload", plistPath]
            try unload.run()
            unload.waitUntilExit()

            try FileManager.default.removeItem(atPath: plistPath)
            print("✓ LaunchAgent removed")
        }

        // 2. Reset screenshot location to default
        let reset = Process()
        reset.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        reset.arguments = ["delete", "com.apple.screencapture", "location"]
        try reset.run()
        reset.waitUntilExit()

        let restart = Process()
        restart.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        restart.arguments = ["SystemUIServer"]
        try restart.run()
        restart.waitUntilExit()
        print("✓ Screenshot location reset to default (Desktop)")

        print("\nssap uninstalled. Config and screenshots are preserved.")
    }

    private static func resolveSymlink(_ path: String) -> String {
        let fm = FileManager.default
        if let resolved = try? fm.destinationOfSymbolicLink(atPath: path) {
            if resolved.hasPrefix("/") { return resolved }
            let dir = (path as NSString).deletingLastPathComponent
            return (dir as NSString).appendingPathComponent(resolved)
        }
        // Return absolute path
        if path.hasPrefix("/") { return path }
        return fm.currentDirectoryPath + "/" + path
    }
}
