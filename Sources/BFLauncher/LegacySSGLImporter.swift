import Foundation

enum LegacySSGLImporter {
    private static var supportDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/ssgl-doom-launcher", isDirectory: true)
    }

    static func existingWADRoot() -> URL? {
        let url = supportDirectory.appendingPathComponent("settings.json")
        guard let data = try? Data(contentsOf: url),
              let settings = try? JSONDecoder().decode(LegacySettings.self, from: data),
              let path = settings.modpath ?? settings.savepath,
              FileManager.default.fileExists(atPath: path) else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    static func internalDirectoryNames() -> Set<String> {
        var names = Set<String>()
        for package in packages() {
            names.insert(package.sourceport)
            if let first = package.datapath.split(separator: "/").first {
                names.insert(String(first))
            }
        }
        let sourcePortsURL = supportDirectory.appendingPathComponent("sourceports.json")
        if let data = try? Data(contentsOf: sourcePortsURL),
           let ports = try? JSONDecoder().decode([LegacyPort].self, from: data) {
            names.formUnion(ports.map(\.id))
        }
        return names
    }

    static func importProfiles(from indexedFiles: [GameFile]) -> [LaunchProfile] {
        let lookup = LegacyFileLookup(files: indexedFiles)
        return packages().map { package in
            let matches = package.selected.map { token in (token, lookup.match(token: token)) }
            let mods = matches.compactMap { $0.1?.path }
            let unresolved = matches.compactMap { $0.1 == nil ? $0.0 : nil }
            var options = LaunchOptions()
            options.extraArguments = package.userparams ?? ""
            return LaunchProfile(
                name: package.name,
                iwadPath: package.iwad,
                modPaths: mods,
                options: options,
                importedFromSSGL: true,
                unresolvedLegacyFiles: unresolved.isEmpty ? nil : unresolved
            )
        }
    }

    private static func packages() -> [LegacyPackage] {
        let url = supportDirectory.appendingPathComponent("packages.json")
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([LegacyPackage].self, from: data)) ?? []
    }
}

private struct LegacySettings: Decodable {
    let modpath: String?
    let savepath: String?
}

private struct LegacyPort: Decodable {
    let id: String
}

private struct LegacyPackage: Decodable {
    let name: String
    let iwad: String
    let selected: [String]
    let sourceport: String
    let datapath: String
    let userparams: String?
}

struct LegacyFileLookup {
    let files: [GameFile]

    func match(token: String) -> GameFile? {
        if let synthetic = matchSyntheticID(token) { return synthetic }
        guard let parsed = parse(token: token) else { return nil }
        let exact = files.filter {
            $0.fileExtension.caseInsensitiveCompare(parsed.extensionName) == .orderedSame
                && $0.byteCount == parsed.byteCount
                && normalize($0.url.deletingPathExtension().lastPathComponent) == normalize(parsed.stem)
        }
        if let best = exact.min(by: pathPreference) { return best }

        // SSGL encoded the file size into each synthetic ID. A WAD that was
        // replaced by a newer revision keeps the same human filename but no
        // longer has that historical byte count, so prefer a unique normalized
        // filename match before falling back to size alone.
        let nameMatches = files.filter {
            $0.fileExtension.caseInsensitiveCompare(parsed.extensionName) == .orderedSame
                && normalize($0.url.deletingPathExtension().lastPathComponent) == normalize(parsed.stem)
        }
        if let best = nameMatches.min(by: pathPreference) { return best }

        let sizeMatches = files.filter {
            $0.fileExtension.caseInsensitiveCompare(parsed.extensionName) == .orderedSame
                && $0.byteCount == parsed.byteCount
        }
        return sizeMatches.min(by: pathPreference)
    }

    private func matchSyntheticID(_ token: String) -> GameFile? {
        let extensions = ["WAD", "PK3", "PK7", "ZIP", "DEH", "BEX", "LMP"]
        guard let extensionName = extensions.first(where: { token.uppercased().hasSuffix($0) }) else { return nil }
        let tokenBody = normalize(String(token.dropLast(extensionName.count)))

        let candidates = files.compactMap { file -> (file: GameFile, stemLength: Int, exactSize: Bool)? in
            guard file.fileExtension.caseInsensitiveCompare(extensionName) == .orderedSame else { return nil }
            let stem = normalize(file.url.deletingPathExtension().lastPathComponent)
            guard !stem.isEmpty, tokenBody.hasPrefix(stem) else { return nil }
            let suffix = String(tokenBody.dropFirst(stem.count))
            guard !suffix.isEmpty, suffix.allSatisfy({ $0.isNumber }) else { return nil }
            return (file, stem.count, Int64(suffix) == file.byteCount)
        }

        return candidates.sorted { left, right in
            if left.exactSize != right.exactSize { return left.exactSize }
            if left.stemLength != right.stemLength { return left.stemLength > right.stemLength }
            return pathPreference(left.file, right.file)
        }.first?.file
    }

    private func parse(token: String) -> (stem: String, byteCount: Int64, extensionName: String)? {
        let extensions = ["WAD", "PK3", "PK7", "ZIP", "DEH", "BEX", "LMP"]
        guard let extensionName = extensions.first(where: { token.uppercased().hasSuffix($0) }) else { return nil }
        let withoutExtension = String(token.dropLast(extensionName.count))
        guard let digitStart = withoutExtension.lastIndex(where: { !$0.isNumber }).map({ withoutExtension.index(after: $0) }) else {
            return nil
        }
        let stem = String(withoutExtension[..<digitStart])
        let digits = String(withoutExtension[digitStart...])
        guard !stem.isEmpty, let byteCount = Int64(digits) else { return nil }
        return (stem, byteCount, extensionName)
    }

    private func normalize(_ value: String) -> String {
        String(value.lowercased().filter { $0.isLetter || $0.isNumber })
    }

    private func pathPreference(_ left: GameFile, _ right: GameFile) -> Bool {
        let leftDepth = left.path.split(separator: "/").count
        let rightDepth = right.path.split(separator: "/").count
        if leftDepth != rightDepth { return leftDepth < rightDepth }
        return left.path.localizedStandardCompare(right.path) == .orderedAscending
    }
}
