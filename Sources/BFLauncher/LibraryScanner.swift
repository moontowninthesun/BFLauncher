import Foundation

enum LibraryScanner {
    static let supportedExtensions: Set<String> = [
        "wad", "pk3", "pk7", "zip", "deh", "bex", "lmp"
    ]

    static func scan(root: URL, ignoredTopLevelNames: Set<String> = []) -> [GameFile] {
        let keys: [URLResourceKey] = [
            .isRegularFileKey, .isDirectoryKey, .fileSizeKey,
            .contentModificationDateKey, .isHiddenKey
        ]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else { return [] }

        var results: [GameFile] = []
        for case let url as URL in enumerator {
            let relative = relativePath(of: url, under: root)
            if let first = relative.split(separator: "/").first,
               ignoredTopLevelNames.contains(String(first)) {
                enumerator.skipDescendants()
                continue
            }

            guard supportedExtensions.contains(url.pathExtension.lowercased()),
                  let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true else { continue }

            let inspection = WADInspector.inspect(url)
            let folder = url.deletingLastPathComponent().standardizedFileURL == root.standardizedFileURL
                ? ""
                : relativePath(of: url.deletingLastPathComponent(), under: root)

            results.append(GameFile(
                path: url.standardizedFileURL.path,
                kind: inspection.kind,
                displayName: DisplayNameFormatter.title(for: url),
                relativeFolder: folder,
                fileExtension: url.pathExtension.uppercased(),
                byteCount: Int64(values.fileSize ?? 0),
                modifiedAt: values.contentModificationDate ?? .distantPast,
                mapCount: inspection.mapCount
            ))
        }

        return results.sorted {
            if $0.kind != $1.kind { return kindOrder($0.kind) < kindOrder($1.kind) }
            return $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }
    }

    private static func relativePath(of url: URL, under root: URL) -> String {
        let rootPath = root.standardizedFileURL.path.hasSuffix("/")
            ? root.standardizedFileURL.path
            : root.standardizedFileURL.path + "/"
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(rootPath) else { return url.lastPathComponent }
        return String(path.dropFirst(rootPath.count))
    }

    private static func kindOrder(_ kind: GameFileKind) -> Int {
        switch kind {
        case .iwad: return 0
        case .mod: return 1
        case .resource: return 2
        }
    }
}
