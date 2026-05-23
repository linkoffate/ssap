import Foundation

struct Tagger {
    /// Apply macOS tags (xattr) to a file.
    static func applyTags(_ tags: [String], to path: String) throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw TaggerError.fileNotFound(path)
        }

        // Read existing tags
        var existing = readTags(from: path)

        // Merge new tags (deduplicate)
        for tag in tags {
            let trimmed = tag.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && !existing.contains(trimmed) {
                existing.append(trimmed)
            }
        }

        // Write tags as plist-encoded xattr
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: existing,
            format: .binary,
            options: 0
        )

        let url = URL(fileURLWithPath: path)
        try url.withUnsafeFileSystemRepresentation { fsRep in
            guard let fsRep = fsRep else { throw TaggerError.invalidPath(path) }
            let result = plistData.withUnsafeBytes { bytes in
                setxattr(fsRep, "com.apple.metadata:_kMDItemUserTags", bytes.baseAddress, bytes.count, 0, 0)
            }
            if result != 0 {
                throw TaggerError.xattrFailed(String(cString: strerror(errno)))
            }
        }

        // Also save to tag history for autocomplete
        try saveToHistory(tags)
    }

    /// Read existing macOS tags from a file.
    static func readTags(from path: String) -> [String] {
        let url = URL(fileURLWithPath: path)
        let fsRep = (url as NSURL).fileSystemRepresentation

        let bufferSize = getxattr(fsRep, "com.apple.metadata:_kMDItemUserTags", nil, 0, 0, 0)
        guard bufferSize > 0 else { return [] }

        var buffer = [UInt8](repeating: 0, count: bufferSize)
        let readSize = getxattr(fsRep, "com.apple.metadata:_kMDItemUserTags", &buffer, bufferSize, 0, 0)
        guard readSize > 0 else { return [] }

        let data = Data(buffer[0..<readSize])
        guard let tags = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String] else {
            return []
        }
        return tags
    }

    /// Search for files with a specific tag using Spotlight.
    static func search(tag: String, in directory: String) throws -> [String] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        task.arguments = ["-onlyin", directory, "kMDItemUserTags == '\(tag)'"]

        let pipe = Pipe()
        task.standardOutput = pipe
        try task.run()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        return output.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
    }

    /// Load tag history for autocomplete.
    static func loadHistory() -> [String] {
        let historyPath = Config.configDir + "/tag_history.txt"
        guard let data = FileManager.default.contents(atPath: historyPath),
              let content = String(data: data, encoding: .utf8) else {
            return []
        }
        return content.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
    }

    /// Save new tags to history file.
    private static func saveToHistory(_ tags: [String]) throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: Config.configDir) {
            try fm.createDirectory(atPath: Config.configDir, withIntermediateDirectories: true)
        }
        let historyPath = Config.configDir + "/tag_history.txt"
        var existing = Set(loadHistory())
        for tag in tags {
            existing.insert(tag)
        }
        let content = existing.sorted().joined(separator: "\n") + "\n"
        try content.write(toFile: historyPath, atomically: true, encoding: .utf8)
    }
}

enum TaggerError: Error, CustomStringConvertible {
    case fileNotFound(String)
    case invalidPath(String)
    case xattrFailed(String)

    var description: String {
        switch self {
        case .fileNotFound(let p): return "File not found: \(p)"
        case .invalidPath(let p): return "Invalid path: \(p)"
        case .xattrFailed(let e): return "Failed to set xattr: \(e)"
        }
    }
}
