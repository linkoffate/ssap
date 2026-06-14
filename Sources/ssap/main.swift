import ArgumentParser
import Foundation

@main
struct Ssap: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ssap",
        abstract: "Screenshot Snap, Annotate, Place — macOS screenshot organizer",
        version: "0.2.0",
        subcommands: [Watch.self, Prompt.self, Tag.self, Rename.self, Search.self, Install.self, Uninstall.self, Archive.self],
        defaultSubcommand: Watch.self
    )
}

struct Watch: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Watch for new screenshots and organize them")

    func run() throws {
        let config = try Config.load()
        let watcher = Watcher(config: config)
        print("ssap: watching \(config.watchDir) for new screenshots...")
        watcher.start()
        dispatchMain()
    }
}

struct Prompt: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Show tag prompt for a screenshot")

    @Argument(help: "Path to the screenshot file")
    var file: String

    func run() throws {
        let config = try Config.load()
        let path = (file as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: path) else {
            print("ssap: file not found: \(path)")
            throw ExitCode.failure
        }
        PromptUI.show(for: path, config: config)
    }
}

struct Tag: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Add tags to a screenshot")

    @Argument(help: "Path to the screenshot file")
    var file: String

    @Argument(help: "Tags to apply")
    var tags: [String]

    func run() throws {
        let path = (file as NSString).expandingTildeInPath
        try Tagger.applyTags(tags, to: path)
        print("ssap: tagged \(path) with \(tags.joined(separator: ", "))")
    }
}

struct Rename: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Rename a screenshot (tags are preserved)")

    @Argument(help: "Path to the screenshot file")
    var file: String

    @Argument(help: "New file name (extension optional — original is kept if omitted)")
    var name: String

    func run() throws {
        let path = (file as NSString).expandingTildeInPath
        let newPath = try Renamer.rename(file: path, to: name)
        if newPath == path {
            print("ssap: name unchanged")
        } else {
            print("ssap: renamed to \(newPath)")
        }
    }
}

struct Search: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Find screenshots by tag")

    @Argument(help: "Tag to search for")
    var tag: String

    func run() throws {
        let config = try Config.load()
        let results = try Tagger.search(tag: tag, in: config.watchDir)
        if results.isEmpty {
            print("No screenshots found with tag '\(tag)'")
        } else {
            for r in results {
                print(r)
            }
        }
    }
}

struct Install: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Install LaunchAgent and configure macOS screenshot location")

    func run() throws {
        try Installer.install()
    }
}

struct Uninstall: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Remove LaunchAgent and restore default screenshot location")

    func run() throws {
        try Installer.uninstall()
    }
}

struct Archive: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Compress a year's screenshots into a tarball")

    @Argument(help: "Year to archive (e.g., 2025)")
    var year: String

    func run() throws {
        let config = try Config.load()
        try Archiver.archive(year: year, in: config.watchDir)
    }
}
