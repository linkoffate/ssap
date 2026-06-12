import Foundation

struct Renamer {
    /// Rename a file within its current directory.
    ///
    /// Tags survive the rename: `moveItem` issues a `rename(2)` on the same volume,
    /// which preserves all extended attributes (including `kMDItemUserTags`).
    ///
    /// - If `newName` omits an extension, the original extension is appended so the
    ///   file never silently loses its type.
    /// - Any path components in `newName` are stripped — a rename always stays in the
    ///   same directory.
    /// - Name collisions are resolved with a numeric suffix (` 1`, ` 2`, …).
    ///
    /// Returns the new path (or the unchanged path if the name resolves to a no-op).
    @discardableResult
    static func rename(file path: String, to newName: String) throws -> String {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else {
            throw RenamerError.fileNotFound(path)
        }

        let dir = (path as NSString).deletingLastPathComponent
        let originalExt = (path as NSString).pathExtension

        // Strip directory components — a rename stays put.
        var trimmed = (newName.trimmingCharacters(in: .whitespaces) as NSString).lastPathComponent
        guard !trimmed.isEmpty else { throw RenamerError.emptyName }

        // Preserve the extension if the new name didn't provide one.
        if (trimmed as NSString).pathExtension.isEmpty && !originalExt.isEmpty {
            trimmed += ".\(originalExt)"
        }

        // No-op if the name is unchanged.
        let currentName = (path as NSString).lastPathComponent
        if trimmed == currentName {
            return path
        }

        // Resolve collisions.
        var dest = (dir as NSString).appendingPathComponent(trimmed)
        let base = (trimmed as NSString).deletingPathExtension
        let ext = (trimmed as NSString).pathExtension
        var counter = 1
        while fm.fileExists(atPath: dest) {
            let candidate = ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)"
            dest = (dir as NSString).appendingPathComponent(candidate)
            counter += 1
        }

        try fm.moveItem(atPath: path, toPath: dest)
        return dest
    }
}

enum RenamerError: Error, CustomStringConvertible {
    case fileNotFound(String)
    case emptyName

    var description: String {
        switch self {
        case .fileNotFound(let p): return "File not found: \(p)"
        case .emptyName: return "New name is empty"
        }
    }
}
