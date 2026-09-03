import Foundation

struct LaunchCommand: Equatable {
    let executableURL: URL
    let arguments: [String]
    let workingDirectoryURL: URL?

    var preview: String {
        ([executableURL.path] + arguments).map(Self.quote).joined(separator: " ")
    }

    private static func quote(_ value: String) -> String {
        guard value.contains(where: { $0.isWhitespace || $0 == "\"" || $0 == "'" }) else { return value }
        return "\"" + value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}

enum LaunchCommandBuilder {
    static func build(
        port: SourcePort,
        iwad: GameFile,
        mods: [GameFile],
        options: LaunchOptions,
        workingDirectory: URL?
    ) -> LaunchCommand {
        var arguments = ["-iwad", iwad.path]
        if !mods.isEmpty {
            arguments.append("-file")
            arguments.append(contentsOf: mods.map(\.path))
        }
        if options.skill > 0 {
            arguments.append(contentsOf: ["-skill", String(options.skill)])
        }
        let warp = options.warp.trimmingCharacters(in: .whitespacesAndNewlines)
        if !warp.isEmpty {
            arguments.append("-warp")
            arguments.append(contentsOf: ArgumentTokenizer.tokenize(warp))
        }
        if options.fastMonsters { arguments.append("-fast") }
        if options.noMonsters { arguments.append("-nomonsters") }
        if options.respawn { arguments.append("-respawn") }
        if options.pistolStart { arguments.append("-pistolstart") }
        arguments.append(contentsOf: ArgumentTokenizer.tokenize(options.extraArguments))

        return LaunchCommand(
            executableURL: port.executableURL,
            arguments: arguments,
            workingDirectoryURL: workingDirectory
        )
    }
}

enum ArgumentTokenizer {
    static func tokenize(_ input: String) -> [String] {
        var result: [String] = []
        var current = ""
        var quote: Character?
        var escaping = false

        for character in input {
            if escaping {
                current.append(character)
                escaping = false
                continue
            }
            if character == "\\" {
                escaping = true
                continue
            }
            if let activeQuote = quote {
                if character == activeQuote { quote = nil }
                else { current.append(character) }
                continue
            }
            if character == "\"" || character == "'" {
                quote = character
            } else if character.isWhitespace {
                if !current.isEmpty {
                    result.append(current)
                    current = ""
                }
            } else {
                current.append(character)
            }
        }
        if escaping { current.append("\\") }
        if !current.isEmpty { result.append(current) }
        return result
    }
}
