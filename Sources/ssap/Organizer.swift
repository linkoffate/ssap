import Foundation

struct Organizer {
    /// Parse date from macOS screenshot filename and move to YYYY/MM directory.
    /// Returns the new file path.
    static func organize(file path: String, watchDir: String) throws -> String {
        let filename = (path as NSString).lastPathComponent
        let fm = FileManager.default

        // Extract YYYY-MM-DD from filename
        guard let range = filename.range(of: #"\d{4}-\d{2}-\d{2}"#, options: .regularExpression) else {
            throw OrganizerError.noDateInFilename(filename)
        }

        let dateStr = String(filename[range])
        let parts = dateStr.split(separator: "-")
        guard parts.count == 3 else {
            throw OrganizerError.noDateInFilename(filename)
        }

        let year = String(parts[0])
        let month = String(parts[1])
        let destDir = (watchDir as NSString).appendingPathComponent("\(year)/\(month)")

        // Already in the right place?
        let currentDir = (path as NSString).deletingLastPathComponent
        if currentDir == destDir {
            return path
        }

        // Create destination directory
        try fm.createDirectory(atPath: destDir, withIntermediateDirectories: true)

        // Move file
        let destPath = (destDir as NSString).appendingPathComponent(filename)

        // Handle name collision
        var finalPath = destPath
        var counter = 1
        while fm.fileExists(atPath: finalPath) {
            let name = (filename as NSString).deletingPathExtension
            let ext = (filename as NSString).pathExtension
            finalPath = (destDir as NSString).appendingPathComponent("\(name) \(counter).\(ext)")
            counter += 1
        }

        try fm.moveItem(atPath: path, toPath: finalPath)
        return finalPath
    }
}

enum OrganizerError: Error, CustomStringConvertible {
    case noDateInFilename(String)

    var description: String {
        switch self {
        case .noDateInFilename(let name):
            return "Could not extract date from filename: \(name)"
        }
    }
}
