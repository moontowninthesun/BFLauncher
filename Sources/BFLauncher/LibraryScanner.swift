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

            if let file = makeGameFile(url: url, relativeTo: root, resourceKeys: Set(keys)) {
                results.append(file)
            }
        }

        return results.sorted {
            if $0.kind != $1.kind { return kindOrder($0.kind) < kindOrder($1.kind) }
            return $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }
    }

    static func makeGameFile(url: URL, relativeTo root: URL?) -> GameFile? {
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey, .fileSizeKey, .contentModificationDateKey
        ]
        return makeGameFile(url: url, relativeTo: root, resourceKeys: keys)
    }

    private static func makeGameFile(
        url: URL,
        relativeTo root: URL?,
        resourceKeys: Set<URLResourceKey>
    ) -> GameFile? {
        guard supportedExtensions.contains(url.pathExtension.lowercased()),
              let values = try? url.resourceValues(forKeys: resourceKeys),
              values.isRegularFile == true else { return nil }
        let inspection = WADInspector.inspect(url)
        let parent = url.deletingLastPathComponent().standardizedFileURL
        let folder: String
        if let root, parent == root.standardizedFileURL {
            folder = ""
        } else if let root, parent.path.hasPrefix(root.standardizedFileURL.path + "/") {
            folder = relativePath(of: parent, under: root)
        } else {
            folder = parent.lastPathComponent
        }
        return GameFile(
            path: url.standardizedFileURL.path,
            kind: inspection.kind,
            displayName: DisplayNameFormatter.title(for: url),
            relativeFolder: folder,
            fileExtension: url.pathExtension.uppercased(),
            byteCount: Int64(values.fileSize ?? 0),
            modifiedAt: values.contentModificationDate ?? .distantPast,
            mapCount: inspection.mapCount
        )
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
