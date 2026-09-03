import Foundation

struct WADInspection {
    let kind: GameFileKind
    let mapCount: Int
}

enum WADInspector {
    private static let knownIWADNames: Set<String> = [
        "doom.wad", "doom1.wad", "doom2.wad", "doom2f.wad", "doom211.wad",
        "tnt.wad", "plutonia.wad", "heretic.wad", "heretic1.wad", "hexen.wad",
        "hexdd.wad", "strife1.wad", "freedoom1.wad", "freedoom2.wad",
        "freedm.wad", "chex.wad", "hacx.wad", "rekkrsa.wad"
    ]

    private static let knownResourceNames: Set<String> = [
        "voices.wad", "sve.wad"
    ]

    static func inspect(_ url: URL) -> WADInspection {
        guard url.pathExtension.lowercased() == "wad",
              let handle = try? FileHandle(forReadingFrom: url) else {
            return WADInspection(kind: .mod, mapCount: 0)
        }
        defer { try? handle.close() }

        guard let header = try? handle.read(upToCount: 12), header.count == 12 else {
            return WADInspection(kind: .mod, mapCount: 0)
        }

        let signature = String(data: header.prefix(4), encoding: .ascii) ?? ""
        guard signature == "IWAD" || signature == "PWAD" else {
            return WADInspection(kind: .mod, mapCount: 0)
        }

        let lumpCount = int32LE(header, at: 4)
        let directoryOffset = int32LE(header, at: 8)
        guard lumpCount > 0, lumpCount < 1_000_000, directoryOffset >= 0 else {
            return WADInspection(kind: signature == "IWAD" ? .iwad : .mod, mapCount: 0)
        }

        let directorySize = Int(lumpCount) * 16
        guard directorySize <= 64 * 1024 * 1024 else {
            return WADInspection(kind: signature == "IWAD" ? .iwad : .mod, mapCount: 0)
        }

        do {
            try handle.seek(toOffset: UInt64(directoryOffset))
            guard let directory = try handle.read(upToCount: directorySize),
                  directory.count == directorySize else {
                return WADInspection(kind: signature == "IWAD" ? .iwad : .mod, mapCount: 0)
            }

            var names = Set<String>()
            for index in 0..<Int(lumpCount) {
                let start = index * 16 + 8
                let raw = directory[start..<(start + 8)]
                let name = String(bytes: raw.prefix { $0 != 0 }, encoding: .ascii)?.uppercased() ?? ""
                if !name.isEmpty { names.insert(name) }
            }

            let mapCount = names.filter(isMapMarker).count
            let filename = url.lastPathComponent.lowercased()
            if knownResourceNames.contains(filename) {
                return WADInspection(kind: .resource, mapCount: mapCount)
            }

            let hasCoreData = names.contains("PLAYPAL") && names.contains("COLORMAP")
            let isPlayableIWAD = signature == "IWAD" && (
                knownIWADNames.contains(filename) || (hasCoreData && mapCount > 0)
            )
            return WADInspection(kind: isPlayableIWAD ? .iwad : .mod, mapCount: mapCount)
        } catch {
            return WADInspection(kind: signature == "IWAD" ? .iwad : .mod, mapCount: 0)
        }
    }

    private static func int32LE(_ data: Data, at offset: Int) -> Int32 {
        let bytes = [UInt8](data[offset..<(offset + 4)])
        let value = UInt32(bytes[0])
            | (UInt32(bytes[1]) << 8)
            | (UInt32(bytes[2]) << 16)
            | (UInt32(bytes[3]) << 24)
        return Int32(bitPattern: value)
    }

    private static func isMapMarker(_ name: String) -> Bool {
        if name.range(of: #"^MAP\d\d$"#, options: .regularExpression) != nil { return true }
        if name.range(of: #"^E\dM\d$"#, options: .regularExpression) != nil { return true }
        return name.range(of: #"^MAP\d+$"#, options: .regularExpression) != nil
    }
}

enum DisplayNameFormatter {
    private static let knownTitles: [String: String] = [
        "doom": "The Ultimate Doom",
        "doom1": "Doom Shareware",
        "doom2": "Doom II: Hell on Earth",
        "doom2f": "Doom II (French)",
        "doom211": "Doom II 1.1",
        "tnt": "TNT: Evilution",
        "plutonia": "The Plutonia Experiment",
        "heretic": "Heretic",
        "hexen": "Hexen",
        "hexdd": "Hexen: Deathkings",
        "strife1": "Strife",
        "freedoom1": "Freedoom: Phase 1",
        "freedoom2": "Freedoom: Phase 2",
        "freedm": "FreeDM",
        "chex": "Chex Quest",
        "hacx": "Hacx"
    ]

    static func title(for url: URL) -> String {
        let stem = url.deletingPathExtension().lastPathComponent
        if let known = knownTitles[stem.lowercased()] { return known }
        return stem
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
    }
}
