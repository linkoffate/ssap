import Foundation

struct Archiver {
    static func archive(year: String, in watchDir: String) throws {
        let fm = FileManager.default
        let yearDir = (watchDir as NSString).appendingPathComponent(year)
        let tarPath = (watchDir as NSString).appendingPathComponent("\(year).tar.gz")

        guard fm.fileExists(atPath: yearDir) else {
            print("ssap: directory not found: \(yearDir)")
            throw ArchiveError.notFound(yearDir)
        }

        if fm.fileExists(atPath: tarPath) {
            print("ssap: archive already exists: \(tarPath)")
            throw ArchiveError.alreadyExists(tarPath)
        }

        // Count files
        let files = try fm.contentsOfDirectory(atPath: yearDir)
        let totalFiles = files.reduce(0) { count, month in
            let monthDir = (yearDir as NSString).appendingPathComponent(month)
            return count + ((try? fm.contentsOfDirectory(atPath: monthDir))?.count ?? 0)
        }

        print("Archiving \(year): \(totalFiles) files...")

        // Create tar.gz preserving xattrs
        let tar = Process()
        tar.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        tar.arguments = ["czf", tarPath, "-C", watchDir, year]
        tar.currentDirectoryURL = URL(fileURLWithPath: watchDir)
        try tar.run()
        tar.waitUntilExit()

        guard tar.terminationStatus == 0 else {
            throw ArchiveError.tarFailed(Int(tar.terminationStatus))
        }

        // Report size
        let attrs = try fm.attributesOfItem(atPath: tarPath)
        let size = attrs[.size] as? Int64 ?? 0
        let sizeMB = Double(size) / 1_048_576.0

        // Remove directory
        try fm.removeItem(atPath: yearDir)

        print("✓ Archived \(year): \(totalFiles) files → \(String(format: "%.1f", sizeMB))MB")
    }
}

enum ArchiveError: Error, CustomStringConvertible {
    case notFound(String)
    case alreadyExists(String)
    case tarFailed(Int)

    var description: String {
        switch self {
        case .notFound(let p): return "Directory not found: \(p)"
        case .alreadyExists(let p): return "Archive already exists: \(p)"
        case .tarFailed(let code): return "tar failed with exit code \(code)"
        }
    }
}
