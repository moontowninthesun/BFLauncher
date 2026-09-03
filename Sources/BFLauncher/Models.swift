import Foundation

enum GameFileKind: String, Codable, CaseIterable {
    case iwad
    case mod
    case resource

    var label: String {
        switch self {
        case .iwad: return "IWAD"
        case .mod: return "Mod"
        case .resource: return "Resource"
        }
    }
}

struct GameFile: Identifiable, Hashable, Codable {
    let path: String
    let kind: GameFileKind
    let displayName: String
    let relativeFolder: String
    let fileExtension: String
    let byteCount: Int64
    let modifiedAt: Date
    let mapCount: Int

    var id: String { path }
    var url: URL { URL(fileURLWithPath: path) }

    var detail: String {
        var parts: [String] = []
        if !relativeFolder.isEmpty { parts.append(relativeFolder) }
        if mapCount > 0 { parts.append("\(mapCount) map\(mapCount == 1 ? "" : "s")") }
        parts.append(ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file))
        return parts.joined(separator: "  ·  ")
    }
}

struct SourcePort: Identifiable, Hashable, Codable {
    let name: String
    let appPath: String
    let executablePath: String
    let automaticallyDetected: Bool

    var id: String { executablePath }
    var appURL: URL { URL(fileURLWithPath: appPath) }
    var executableURL: URL { URL(fileURLWithPath: executablePath) }
}

struct LaunchOptions: Hashable, Codable {
    var skill: Int = 0
    var warp: String = ""
    var fastMonsters = false
    var noMonsters = false
    var respawn = false
    var pistolStart = false
    var extraArguments = ""
}

struct LaunchProfile: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var iwadPath: String
    var modPaths: [String]
    var sourcePortPath: String?
    var options: LaunchOptions
    var importedFromSSGL: Bool
    var unresolvedLegacyFiles: [String]?

    var unresolvedCount: Int { unresolvedLegacyFiles?.count ?? 0 }

    init(
        id: UUID = UUID(),
        name: String,
        iwadPath: String,
        modPaths: [String],
        sourcePortPath: String? = nil,
        options: LaunchOptions = LaunchOptions(),
        importedFromSSGL: Bool = false,
        unresolvedLegacyFiles: [String]? = nil
    ) {
        self.id = id
        self.name = name
        self.iwadPath = iwadPath
        self.modPaths = modPaths
        self.sourcePortPath = sourcePortPath
        self.options = options
        self.importedFromSSGL = importedFromSSGL
        self.unresolvedLegacyFiles = unresolvedLegacyFiles
    }
}

enum LibrarySection: String, CaseIterable, Identifiable {
    case quick = "Quick Launch"
    case iwads = "IWADs"
    case chain = "Load Chain"
    case presets = "Presets"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .quick: return "bolt.fill"
        case .iwads: return "shippingbox.fill"
        case .chain: return "square.stack.3d.up.fill"
        case .presets: return "bookmark.fill"
        }
    }
}

enum LibrarySort: String, CaseIterable, Identifiable {
    case name = "Name"
    case folder = "Folder"
    case newest = "Newest"

    var id: String { rawValue }
}
