import AppKit
import Foundation

enum SourcePortScanner {
    private static let recognizedNames = [
        "uzdoom", "gzdoom", "vkdoom", "lzdoom", "qzdoom", "zandronum",
        "chocolate doom", "chocolate-doom", "crispy doom", "crispy-doom",
        "dsda-doom", "dsda doom", "woof", "prboom", "prboom+", "odamex",
        "eternity", "doom retro", "doomretro"
    ]

    static func scan(customPaths: [String] = []) -> [SourcePort] {
        var candidates: [URL] = []
        let roots = [URL(fileURLWithPath: "/Applications", isDirectory: true),
                     FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)]

        for root in roots where FileManager.default.fileExists(atPath: root.path) {
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let url as URL in enumerator where url.pathExtension.lowercased() == "app" {
                if isRecognized(url) { candidates.append(url) }
            }
        }

        candidates.append(contentsOf: customPaths.map(URL.init(fileURLWithPath:)))

        var byExecutable: [String: SourcePort] = [:]
        for url in candidates {
            guard let port = makePort(from: url, automatic: !customPaths.contains(url.path)) else { continue }
            byExecutable[port.executablePath] = port
        }

        return byExecutable.values.sorted {
            let left = priority($0.name)
            let right = priority($1.name)
            return left == right
                ? $0.name.localizedStandardCompare($1.name) == .orderedAscending
                : left < right
        }
    }

    static func makePort(from url: URL, automatic: Bool) -> SourcePort? {
        let standardized = url.standardizedFileURL
        if standardized.pathExtension.lowercased() == "app" {
            guard let bundle = Bundle(url: standardized), let executable = bundle.executableURL else { return nil }
            let displayName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                ?? standardized.deletingPathExtension().lastPathComponent
            return SourcePort(
                name: displayName,
                appPath: standardized.path,
                executablePath: executable.path,
                automaticallyDetected: automatic
            )
        }

        guard FileManager.default.isExecutableFile(atPath: standardized.path) else { return nil }
        return SourcePort(
            name: standardized.lastPathComponent,
            appPath: standardized.path,
            executablePath: standardized.path,
            automaticallyDetected: automatic
        )
    }

    private static func isRecognized(_ url: URL) -> Bool {
        let name = url.deletingPathExtension().lastPathComponent.lowercased()
        guard !name.contains("telemetry"), name != "doomseeker" else { return false }
        return recognizedNames.contains { name.contains($0) }
    }

    private static func priority(_ name: String) -> Int {
        let value = name.lowercased()
        if value.contains("uzdoom") && value.contains("patched") { return 0 }
        if value == "uzdoom" { return 1 }
        if value.contains("uzdoom") { return 2 }
        if value.contains("gzdoom") { return 3 }
        if value.contains("vkdoom") { return 4 }
        return 10
    }
}
