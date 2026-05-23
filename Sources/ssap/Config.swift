import Foundation
import Yams

struct Config {
    let watchDir: String
    let organize: Bool
    let promptEnabled: Bool
    let deletePrompt: Bool
    let tagPresets: [String]
    let archivePreserveXattrs: Bool

    static let configDir = NSHomeDirectory() + "/.config/ssap"
    static let configPath = configDir + "/config.yaml"

    static func load() throws -> Config {
        let fm = FileManager.default

        if fm.fileExists(atPath: configPath),
           let data = fm.contents(atPath: configPath),
           let str = String(data: data, encoding: .utf8) {
            return try parse(str)
        }

        // Return defaults if no config file
        return Config(
            watchDir: NSHomeDirectory() + "/Screenshots",
            organize: true,
            promptEnabled: true,
            deletePrompt: true,
            tagPresets: ["troubleshooting", "incident", "reference", "meeting", "personal"],
            archivePreserveXattrs: true
        )
    }

    static func parse(_ yaml: String) throws -> Config {
        guard let dict = try Yams.load(yaml: yaml) as? [String: Any] else {
            throw ConfigError.invalidFormat
        }

        let watchDir: String
        if let dir = dict["watch_dir"] as? String {
            watchDir = (dir as NSString).expandingTildeInPath
        } else {
            watchDir = NSHomeDirectory() + "/Screenshots"
        }

        return Config(
            watchDir: watchDir,
            organize: dict["organize"] as? Bool ?? true,
            promptEnabled: dict["prompt"] as? Bool ?? true,
            deletePrompt: dict["delete_prompt"] as? Bool ?? true,
            tagPresets: dict["tag_presets"] as? [String] ?? ["troubleshooting", "incident", "reference", "meeting", "personal"],
            archivePreserveXattrs: (dict["archive"] as? [String: Any])?["preserve_xattrs"] as? Bool ?? true
        )
    }

    func createDefaultConfig() throws {
        let fm = FileManager.default
        try fm.createDirectory(atPath: Config.configDir, withIntermediateDirectories: true)

        let content = """
        # ssap configuration
        watch_dir: ~/Screenshots
        organize: true        # auto-sort into YYYY/MM
        prompt: true          # show tag dialog on new screenshot
        delete_prompt: true   # include Delete button for mistakes

        tag_presets:
          - troubleshooting
          - incident
          - reference
          - meeting
          - personal

        archive:
          preserve_xattrs: true
        """

        try content.write(toFile: Config.configPath, atomically: true, encoding: .utf8)
    }
}

enum ConfigError: Error, CustomStringConvertible {
    case invalidFormat

    var description: String {
        switch self {
        case .invalidFormat: return "Invalid config format"
        }
    }
}
