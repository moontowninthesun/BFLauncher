import Foundation

enum ProfileStore {
    static var directory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/BFLauncher", isDirectory: true)
    }

    private static var fileURL: URL { directory.appendingPathComponent("profiles.json") }

    static var exists: Bool { FileManager.default.fileExists(atPath: fileURL.path) }

    static func load() -> [LaunchProfile] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([LaunchProfile].self, from: data)) ?? []
    }

    static func save(_ profiles: [LaunchProfile]) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(profiles).write(to: fileURL, options: .atomic)
    }
}
