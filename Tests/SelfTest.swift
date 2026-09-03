import Foundation

@main
struct BFLauncherSelfTest {
    static func main() throws {
        try testRenamedIWADDetection()
        try testResourceDetection()
        try testPWADDetection()
        testOrderedLaunchCommand()
        testQuotedArguments()
        try testLegacySyntheticIDs()
        print("BFLauncher self-tests passed")
    }

    private static func testRenamedIWADDetection() throws {
        let url = try makeWAD(
            name: "totally-renamed.wad",
            signature: "IWAD",
            lumps: ["PLAYPAL", "COLORMAP", "MAP01", "THINGS"]
        )
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let result = WADInspector.inspect(url)
        try require(result.kind == .iwad, "renamed IWAD was not recognized")
        try require(result.mapCount == 1, "map count was not detected")
    }

    private static func testResourceDetection() throws {
        let url = try makeWAD(name: "VOICES.WAD", signature: "IWAD", lumps: ["VOC1", "VOC2"])
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try require(WADInspector.inspect(url).kind == .resource, "VOICES.WAD was treated as a playable IWAD")
    }

    private static func testPWADDetection() throws {
        let url = try makeWAD(name: "maps.wad", signature: "PWAD", lumps: ["MAP01"])
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try require(WADInspector.inspect(url).kind == .mod, "PWAD was not recognized")
    }

    private static func testOrderedLaunchCommand() {
        let port = SourcePort(
            name: "UZDoom",
            appPath: "/Applications/UZDoom.app",
            executablePath: "/Applications/UZDoom.app/Contents/MacOS/uzdoom",
            automaticallyDetected: true
        )
        let iwad = gameFile("/WADs/DOOM2.WAD", kind: .iwad)
        let first = gameFile("/WADs/Maps/first.wad", kind: .mod)
        let second = gameFile("/WADs/Addons/second.pk3", kind: .mod)
        var options = LaunchOptions()
        options.skill = 4
        options.warp = "10"
        options.fastMonsters = true
        options.extraArguments = #"+set fluid_patchset "A Soundfont.sf2""#
        let command = LaunchCommandBuilder.build(
            port: port,
            iwad: iwad,
            mods: [first, second],
            options: options,
            workingDirectory: URL(fileURLWithPath: "/WADs")
        )
        precondition(command.arguments == [
            "-iwad", "/WADs/DOOM2.WAD",
            "-file", "/WADs/Maps/first.wad", "/WADs/Addons/second.pk3",
            "-skill", "4", "-warp", "10", "-fast",
            "+set", "fluid_patchset", "A Soundfont.sf2"
        ], "launch order or arguments were incorrect")
    }

    private static func testQuotedArguments() {
        precondition(
            ArgumentTokenizer.tokenize(#"-config "/A Folder/game.ini" -host 2"#)
                == ["-config", "/A Folder/game.ini", "-host", "2"],
            "quoted arguments were split incorrectly"
        )
    }

    private static func testLegacySyntheticIDs() throws {
        let files = [
            gameFile("/WADs/room-redux-r2.wad", kind: .mod, byteCount: 999),
            gameFile("/WADs/AB.wad", kind: .mod, byteCount: 100),
            gameFile("/WADs/AB2.wad", kind: .mod, byteCount: 200),
            gameFile("/WADs/id1.pk3", kind: .mod, byteCount: 300)
        ]
        let lookup = LegacyFileLookup(files: files)
        try require(
            lookup.match(token: "room-redux-r2425930WAD")?.path == "/WADs/room-redux-r2.wad",
            "version digit was confused with SSGL's size suffix"
        )
        try require(
            lookup.match(token: "AB212818695WAD")?.path == "/WADs/AB2.wad",
            "longest matching filename was not preferred"
        )
        try require(
            lookup.match(token: "id117911130PK3")?.path == "/WADs/id1.pk3",
            "numeric filename was not recovered"
        )
    }

    private static func gameFile(_ path: String, kind: GameFileKind, byteCount: Int64 = 0) -> GameFile {
        GameFile(
            path: path,
            kind: kind,
            displayName: URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent,
            relativeFolder: "",
            fileExtension: URL(fileURLWithPath: path).pathExtension.uppercased(),
            byteCount: byteCount,
            modifiedAt: .distantPast,
            mapCount: 0
        )
    }

    private static func makeWAD(name: String, signature: String, lumps: [String]) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        var data = Data(signature.utf8)
        data.appendLittleEndian(UInt32(lumps.count))
        data.appendLittleEndian(UInt32(12))
        for lump in lumps {
            data.appendLittleEndian(UInt32(0))
            data.appendLittleEndian(UInt32(0))
            var nameBytes = Array(lump.utf8.prefix(8))
            nameBytes.append(contentsOf: repeatElement(0, count: 8 - nameBytes.count))
            data.append(contentsOf: nameBytes)
        }
        try data.write(to: url)
        return url
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw SelfTestError.failed(message) }
    }
}

private enum SelfTestError: Error {
    case failed(String)
}

private extension Data {
    mutating func appendLittleEndian(_ value: UInt32) {
        append(UInt8(value & 0xff))
        append(UInt8((value >> 8) & 0xff))
        append(UInt8((value >> 16) & 0xff))
        append(UInt8((value >> 24) & 0xff))
    }
}
