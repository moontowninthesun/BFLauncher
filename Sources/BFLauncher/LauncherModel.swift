import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
final class LauncherModel: ObservableObject {
    private enum Key {
        static let wadRoot = "wadRoot"
        static let defaultPort = "defaultPort"
        static let defaultIWAD = "defaultIWAD"
        static let customPorts = "customPorts"
        static let legacyMigrationVersion = "legacyMigrationVersion"
    }

    @Published var section: LibrarySection = .quick
    @Published private(set) var files: [GameFile] = []
    @Published private(set) var sourcePorts: [SourcePort] = []
    @Published private(set) var profiles: [LaunchProfile] = []
    @Published var selectedFileID: String?
    @Published var selectedProfileID: UUID?
    @Published var loadChain: [GameFile] = []
    @Published var options = LaunchOptions()
    @Published var searchText = ""
    @Published var status = "Ready"

    @Published var wadRootPath: String {
        didSet { UserDefaults.standard.set(wadRootPath, forKey: Key.wadRoot) }
    }
    @Published var defaultPortID: String {
        didSet { UserDefaults.standard.set(defaultPortID, forKey: Key.defaultPort) }
    }
    @Published var defaultIWADPath: String {
        didSet { UserDefaults.standard.set(defaultIWADPath, forKey: Key.defaultIWAD) }
    }

    private var customPortPaths: [String]
    private var runningProcesses: [Process] = []

    init() {
        let defaults = UserDefaults.standard
        let savedRoot = defaults.string(forKey: Key.wadRoot)
        wadRootPath = savedRoot
            ?? LegacySSGLImporter.existingWADRoot()?.path
            ?? ""
        defaultPortID = defaults.string(forKey: Key.defaultPort) ?? ""
        defaultIWADPath = defaults.string(forKey: Key.defaultIWAD) ?? ""
        customPortPaths = defaults.stringArray(forKey: Key.customPorts) ?? []

        rescanSourcePorts()
        rescanLibrary()
        profiles = ProfileStore.load()
        if defaults.integer(forKey: Key.legacyMigrationVersion) < 1 {
            let personalProfiles = profiles.filter { !$0.importedFromSSGL }
            profiles = personalProfiles + LegacySSGLImporter.importProfiles(from: files)
            try? ProfileStore.save(profiles)
            defaults.set(1, forKey: Key.legacyMigrationVersion)
        }
        status = summaryStatus
    }

    var iwads: [GameFile] { files.filter { $0.kind == .iwad } }
    var mods: [GameFile] { files.filter { $0.kind != .iwad } }
    var selectedFile: GameFile? { files.first { $0.id == selectedFileID } }
    var defaultPort: SourcePort? { sourcePorts.first { $0.id == defaultPortID } }
    var defaultIWAD: GameFile? { iwads.first { $0.path == defaultIWADPath } }

    var commandPreview: String {
        guard let port = defaultPort, let iwad = defaultIWAD else { return "Choose a source port and IWAD" }
        return LaunchCommandBuilder.build(
            port: port,
            iwad: iwad,
            mods: loadChain,
            options: options,
            workingDirectory: wadRootURL
        ).preview
    }

    var summaryStatus: String {
        let imported = profiles.filter(\.importedFromSSGL).count
        let presetText = imported > 0 ? " · \(imported) SSGL presets imported" : ""
        return "\(mods.count) mods · \(iwads.count) IWADs · \(sourcePorts.count) ports\(presetText)"
    }

    func rescanAll() {
        rescanSourcePorts()
        rescanLibrary()
        status = summaryStatus
    }

    func rescanSourcePorts() {
        sourcePorts = SourcePortScanner.scan(customPaths: customPortPaths)
        if !sourcePorts.contains(where: { $0.id == defaultPortID }) {
            defaultPortID = sourcePorts.first?.id ?? ""
        }
    }

    func rescanLibrary() {
        guard let root = wadRootURL,
              FileManager.default.fileExists(atPath: root.path) else {
            files = []
            defaultIWADPath = ""
            status = "Choose your WAD folder to begin"
            return
        }
        files = LibraryScanner.scan(
            root: root,
            ignoredTopLevelNames: LegacySSGLImporter.internalDirectoryNames()
        )
        if !iwads.contains(where: { $0.path == defaultIWADPath }) {
            defaultIWADPath = preferredDoomII?.path ?? iwads.first?.path ?? ""
        }
        if selectedFileID == nil { selectedFileID = mods.first?.id }
    }

    func chooseWADFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose your Doom WAD folder"
        panel.message = "BFLauncher will index IWADs and mods in this folder and its subfolders."
        panel.prompt = "Use Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if let root = wadRootURL { panel.directoryURL = root }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        wadRootPath = url.standardizedFileURL.path
        rescanLibrary()
        status = summaryStatus
    }

    func addSourcePort() {
        let panel = NSOpenPanel()
        panel.title = "Add a Doom source port"
        panel.message = "Choose a source-port app or executable."
        panel.prompt = "Add Port"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application, .unixExecutable]
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        guard panel.runModal() == .OK, let url = panel.url,
              let port = SourcePortScanner.makePort(from: url, automatic: false) else { return }
        if !customPortPaths.contains(port.appPath) { customPortPaths.append(port.appPath) }
        UserDefaults.standard.set(customPortPaths, forKey: Key.customPorts)
        rescanSourcePorts()
        defaultPortID = port.id
        status = "Added \(port.name)"
    }

    func setSelectedIWADAsDefault() {
        guard let file = selectedFile, file.kind == .iwad else { return }
        defaultIWADPath = file.path
        status = "Default IWAD: \(file.displayName)"
    }

    func addSelectedToChain() {
        guard let file = selectedFile, file.kind != .iwad,
              !loadChain.contains(where: { $0.path == file.path }) else { return }
        loadChain.append(file)
        section = .chain
        status = "Added \(file.displayName) to the load chain"
    }

    func removeFromChain(_ file: GameFile) {
        loadChain.removeAll { $0.id == file.id }
    }

    func clearChain() {
        loadChain.removeAll()
        status = "Load chain cleared"
    }

    func revealInFinder(_ file: GameFile) {
        NSWorkspace.shared.activateFileViewerSelecting([file.url])
    }

    func moveChainItem(at index: Int, by delta: Int) {
        let destination = index + delta
        guard loadChain.indices.contains(index), loadChain.indices.contains(destination) else { return }
        loadChain.swapAt(index, destination)
    }

    func quickLaunch(_ file: GameFile? = nil) {
        let target = file ?? selectedFile
        guard let target else { status = "Select a mod first"; return }
        if target.kind == .iwad {
            defaultIWADPath = target.path
            launch(mods: [])
        } else {
            launch(mods: [target])
        }
    }

    func launchChain() {
        launch(mods: loadChain)
    }

    func launchProfile(_ profile: LaunchProfile) {
        loadProfile(profile)
        guard !loadChain.isEmpty || profile.unresolvedCount == 0 else {
            status = "This preset’s files are missing; edit its chain before launching"
            return
        }
        launch(mods: loadChain)
    }

    func loadProfile(_ profile: LaunchProfile) {
        selectedProfileID = profile.id
        defaultIWADPath = profile.iwadPath
        if let sourcePortPath = profile.sourcePortPath,
           sourcePorts.contains(where: { $0.id == sourcePortPath }) {
            defaultPortID = sourcePortPath
        }
        loadChain = profile.modPaths.compactMap { path in files.first { $0.path == path } }
        options = profile.options
        section = .chain
        let missing = profile.modPaths.count - loadChain.count + profile.unresolvedCount
        status = missing == 0
            ? "Loaded preset: \(profile.name)"
            : "Loaded preset: \(profile.name) (\(missing) missing file\(missing == 1 ? "" : "s"))"
    }

    func saveProfile(named rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let iwad = defaultIWAD else { return }
        let profile = LaunchProfile(
            name: name,
            iwadPath: iwad.path,
            modPaths: loadChain.map(\.path),
            sourcePortPath: defaultPortID,
            options: options
        )
        profiles.append(profile)
        try? ProfileStore.save(profiles)
        selectedProfileID = profile.id
        status = "Saved preset: \(name)"
    }

    func deleteProfile(_ profile: LaunchProfile) {
        profiles.removeAll { $0.id == profile.id }
        try? ProfileStore.save(profiles)
        status = "Deleted preset: \(profile.name)"
    }

    private var wadRootURL: URL? {
        guard !wadRootPath.isEmpty else { return nil }
        return URL(fileURLWithPath: wadRootPath, isDirectory: true)
    }

    private var preferredDoomII: GameFile? {
        iwads.first { $0.url.lastPathComponent.caseInsensitiveCompare("DOOM2.WAD") == .orderedSame }
            ?? iwads.first { $0.displayName.lowercased().contains("doom ii") }
    }

    private func launch(mods: [GameFile]) {
        guard let port = defaultPort else { status = "Choose a source port"; return }
        guard let iwad = defaultIWAD else { status = "Choose an IWAD"; return }
        guard FileManager.default.fileExists(atPath: port.executablePath) else {
            status = "Source port is no longer available"
            return
        }

        let command = LaunchCommandBuilder.build(
            port: port,
            iwad: iwad,
            mods: mods,
            options: options,
            workingDirectory: wadRootURL
        )
        let process = Process()
        process.executableURL = command.executableURL
        process.arguments = command.arguments
        process.currentDirectoryURL = command.workingDirectoryURL
        runningProcesses.removeAll { !$0.isRunning }
        do {
            try process.run()
            runningProcesses.append(process)
            let content = mods.isEmpty ? iwad.displayName : mods.map(\.displayName).joined(separator: " + ")
            status = "Launched \(content) in \(port.name)"
        } catch {
            status = "Couldn’t launch \(port.name): \(error.localizedDescription)"
        }
    }
}
