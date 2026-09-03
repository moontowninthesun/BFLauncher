import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: LauncherModel

    var body: some View {
        VStack(spacing: 0) {
            HeaderView()
            Divider()
            HSplitView {
                SidebarView()
                    .frame(minWidth: 150, idealWidth: 170, maxWidth: 210)
                detail
                    .frame(minWidth: 620)
            }
            Divider()
            StatusBarView()
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var detail: some View {
        switch model.section {
        case .quick:
            LibraryListView(kind: .mods)
        case .iwads:
            LibraryListView(kind: .iwads)
        case .chain:
            LoadChainView()
        case .presets:
            PresetsView()
        }
    }
}

private struct HeaderView: View {
    @EnvironmentObject private var model: LauncherModel

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 9) {
                BFGEmblemView()

                VStack(alignment: .leading, spacing: 1) {
                    DoomWordmarkView()
                    Text("Doom WAD Launcher for Mac")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            Picker("Port", selection: $model.defaultPortID) {
                if model.sourcePorts.isEmpty { Text("No ports found").tag("") }
                ForEach(model.sourcePorts) { port in
                    Text(port.name).tag(port.id)
                }
            }
            .frame(width: 235)
            .help("Default source port")

            Button {
                model.addSourcePort()
            } label: {
                Image(systemName: "plus")
            }
            .help("Add a source port")

            Picker("IWAD", selection: $model.defaultIWADPath) {
                if model.iwads.isEmpty { Text("No IWADs found").tag("") }
                ForEach(model.iwads) { iwad in
                    Text(iwad.displayName).tag(iwad.path)
                }
            }
            .frame(width: 245)
            .help("Default IWAD")

            Button {
                model.chooseWADFolder()
            } label: {
                Label("WAD Folder", systemImage: "folder")
            }
            .help(model.wadRootPath.isEmpty ? "Choose a WAD folder" : model.wadRootPath)

            Button {
                model.rescanAll()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Rescan WADs and source ports")
        }
        .controlSize(.small)
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }
}

private struct BFGEmblemView: View {
    var body: some View {
        Group {
            if let emblem = AppArtwork.bfgEmblem {
                Image(nsImage: emblem)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "bolt.horizontal.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.green)
            }
        }
        .frame(width: 42, height: 42)
        .accessibilityHidden(true)
    }
}

private struct DoomWordmarkView: View {
    private let title = Text("BFLauncher")
        .font(.custom("Copperplate-Bold", size: 17))

    var body: some View {
        ZStack {
            title
                .foregroundStyle(.black.opacity(0.9))
                .offset(x: 1.2, y: 1.4)
            title
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.72, blue: 0.18),
                                 Color(red: 0.68, green: 0.06, blue: 0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("BFLauncher")
    }
}

private struct SidebarView: View {
    @EnvironmentObject private var model: LauncherModel

    var body: some View {
        List(LibrarySection.allCases, selection: $model.section) { section in
            HStack {
                Label(section.rawValue, systemImage: section.systemImage)
                Spacer()
                count(for: section)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .tag(section)
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.wadRootPath.isEmpty ? "No WAD folder" : URL(fileURLWithPath: model.wadRootPath).lastPathComponent)
                    .lineLimit(1)
                    .font(.caption)
                Text("Library is read-only")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
    }

    @ViewBuilder
    private func count(for section: LibrarySection) -> some View {
        switch section {
        case .quick: Text("\(model.mods.count)")
        case .iwads: Text("\(model.iwads.count)")
        case .chain: Text("\(model.loadChain.count)")
        case .presets: Text("\(model.profiles.count)")
        }
    }
}

private struct LibraryListView: View {
    enum Kind { case mods, iwads }

    @EnvironmentObject private var model: LauncherModel
    @State private var sort: LibrarySort = .name
    let kind: Kind

    private var title: String { kind == .mods ? "Quick Launch" : "IWAD Library" }
    private var subtitle: String {
        kind == .mods
            ? "Select a mod, then Play. Double-click to launch immediately."
            : "IWADs are identified from their contents, even when renamed."
    }

    private var visibleFiles: [GameFile] {
        let base = kind == .mods ? model.mods : model.iwads
        let query = model.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = query.isEmpty ? base : base.filter {
            $0.displayName.localizedCaseInsensitiveContains(query)
                || $0.relativeFolder.localizedCaseInsensitiveContains(query)
                || $0.url.lastPathComponent.localizedCaseInsensitiveContains(query)
        }
        switch sort {
        case .name:
            return filtered.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        case .folder:
            return filtered.sorted {
                let folderResult = $0.relativeFolder.localizedStandardCompare($1.relativeFolder)
                return folderResult == .orderedSame
                    ? $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
                    : folderResult == .orderedAscending
            }
        case .newest:
            return filtered.sorted { $0.modifiedAt > $1.modifiedAt }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: title, subtitle: subtitle) {
                TextField("Search names and folders", text: $model.searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 260)
                Picker("Sort", selection: $sort) {
                    ForEach(LibrarySort.allCases) { Text($0.rawValue).tag($0) }
                }
                .labelsHidden()
                .frame(width: 105)
            }
            Divider()

            if visibleFiles.isEmpty {
                EmptyLibraryView(kind: kind)
            } else {
                List(visibleFiles, selection: $model.selectedFileID) { file in
                    GameFileRow(file: file, isDefaultIWAD: file.path == model.defaultIWADPath)
                        .tag(file.id)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            model.selectedFileID = file.id
                            model.quickLaunch(file)
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            model.selectedFileID = file.id
                        })
                        .contextMenu {
                            Button(file.kind == .iwad ? "Play IWAD" : "Play") {
                                model.quickLaunch(file)
                            }
                            if file.kind == .iwad {
                                Button("Make Default IWAD") {
                                    model.selectedFileID = file.id
                                    model.setSelectedIWADAsDefault()
                                }
                            } else {
                                Button("Add to Load Chain") {
                                    model.selectedFileID = file.id
                                    model.addSelectedToChain()
                                }
                            }
                            Divider()
                            Button("Reveal in Finder") { model.revealInFinder(file) }
                        }
                }
                .listStyle(.inset)
            }

            Divider()
            HStack {
                if kind == .mods {
                    Button("Add to Load Chain") { model.addSelectedToChain() }
                        .disabled(model.selectedFile?.kind == .iwad || model.selectedFile == nil)
                    Spacer()
                    Button("Play") { model.quickLaunch() }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .keyboardShortcut(.defaultAction)
                        .disabled(model.selectedFile == nil || model.defaultPort == nil || model.defaultIWAD == nil)
                } else {
                    Button("Make Default") { model.setSelectedIWADAsDefault() }
                        .disabled(model.selectedFile?.kind != .iwad)
                    Spacer()
                    Button("Play IWAD") { model.quickLaunch() }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .disabled(model.selectedFile?.kind != .iwad || model.defaultPort == nil)
                }
            }
            .padding(12)
        }
    }
}

private struct GameFileRow: View {
    let file: GameFile
    let isDefaultIWAD: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(file.kind == .iwad ? .orange : .green)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(file.displayName)
                        .lineLimit(1)
                    if isDefaultIWAD {
                        Text("DEFAULT")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.orange.opacity(0.18), in: Capsule())
                    }
                }
                Text(file.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(file.fileExtension)
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 3)
    }

    private var icon: String {
        switch file.kind {
        case .iwad: return "shippingbox.fill"
        case .mod: return "doc.zipper"
        case .resource: return "waveform"
        }
    }
}

private struct LoadChainView: View {
    @EnvironmentObject private var model: LauncherModel
    @State private var showingSaveSheet = false

    private var availableMods: [GameFile] {
        let query = model.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return model.mods }
        return model.mods.filter {
            $0.displayName.localizedCaseInsensitiveContains(query)
                || $0.relativeFolder.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                SectionHeader(
                    title: "Available Mods",
                    subtitle: "Add any number of files; load order is preserved."
                ) {
                    TextField("Filter mods", text: $model.searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 230)
                }
                Divider()
                List(availableMods, selection: $model.selectedFileID) { file in
                    GameFileRow(file: file, isDefaultIWAD: false)
                        .tag(file.id)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            model.selectedFileID = file.id
                            model.addSelectedToChain()
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            model.selectedFileID = file.id
                        })
                        .contextMenu {
                            Button("Add to Load Chain") {
                                model.selectedFileID = file.id
                                model.addSelectedToChain()
                            }
                            Button("Reveal in Finder") { model.revealInFinder(file) }
                        }
                }
                .listStyle(.inset)
                Divider()
                HStack {
                    Spacer()
                    Button("Add →") { model.addSelectedToChain() }
                        .disabled(model.selectedFile == nil)
                }
                .padding(10)
            }
            .frame(minWidth: 340)

            VStack(spacing: 0) {
                SectionHeader(
                    title: "Load Chain",
                    subtitle: "Top loads first. Reorder with the arrow buttons."
                ) { EmptyView() }
                Divider()

                if model.loadChain.isEmpty {
                    EmptyStateView(
                        title: "No files in the chain",
                        systemImage: "square.stack.3d.up.slash",
                        message: "Double-click a mod on the left to add it."
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(Array(model.loadChain.enumerated()), id: \.element.id) { index, file in
                            HStack(spacing: 8) {
                                Text("\(index + 1)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 18)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(file.displayName).lineLimit(1)
                                    Text(file.fileExtension)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button { model.moveChainItem(at: index, by: -1) } label: {
                                    Image(systemName: "chevron.up")
                                }
                                .buttonStyle(.plain)
                                .disabled(index == 0)
                                Button { model.moveChainItem(at: index, by: 1) } label: {
                                    Image(systemName: "chevron.down")
                                }
                                .buttonStyle(.plain)
                                .disabled(index == model.loadChain.count - 1)
                                Button { model.removeFromChain(file) } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .listStyle(.inset)
                }

                Divider()
                AdvancedOptionsView()
                Divider()

                VStack(alignment: .leading, spacing: 5) {
                    Text("COMMAND PREVIEW")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(model.commandPreview)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                HStack {
                    Button("Clear") { model.clearChain() }
                        .disabled(model.loadChain.isEmpty)
                    Button("Save Preset…") { showingSaveSheet = true }
                        .disabled(model.loadChain.isEmpty)
                    Spacer()
                    Button("Launch Chain") { model.launchChain() }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .keyboardShortcut(.defaultAction)
                        .disabled(model.loadChain.isEmpty || model.defaultPort == nil || model.defaultIWAD == nil)
                }
                .padding(12)
            }
            .frame(minWidth: 390, idealWidth: 460)
        }
        .sheet(isPresented: $showingSaveSheet) {
            SavePresetSheet(isPresented: $showingSaveSheet)
                .environmentObject(model)
        }
    }
}

private struct AdvancedOptionsView: View {
    @EnvironmentObject private var model: LauncherModel

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 7) {
            GridRow {
                Text("Skill")
                    .foregroundStyle(.secondary)
                Picker("Skill", selection: $model.options.skill) {
                    Text("Port default").tag(0)
                    Text("1 · I'm Too Young to Die").tag(1)
                    Text("2 · Hey, Not Too Rough").tag(2)
                    Text("3 · Hurt Me Plenty").tag(3)
                    Text("4 · Ultra-Violence").tag(4)
                    Text("5 · Nightmare!").tag(5)
                }
                .labelsHidden()
            }
            GridRow {
                Text("Warp")
                    .foregroundStyle(.secondary)
                TextField("e.g. 10 or 2 4", text: $model.options.warp)
                    .textFieldStyle(.roundedBorder)
            }
            GridRow {
                Text("Rules")
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    Toggle("Fast", isOn: $model.options.fastMonsters)
                    Toggle("No monsters", isOn: $model.options.noMonsters)
                    Toggle("Respawn", isOn: $model.options.respawn)
                    Toggle("Pistol start", isOn: $model.options.pistolStart)
                }
                .toggleStyle(.checkbox)
            }
            GridRow {
                Text("Extra")
                    .foregroundStyle(.secondary)
                TextField("Additional source-port arguments", text: $model.options.extraArguments)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .font(.caption)
        .padding(12)
    }
}

private struct PresetsView: View {
    @EnvironmentObject private var model: LauncherModel
    @State private var presetSearch = ""

    private var selected: LaunchProfile? {
        model.profiles.first { $0.id == model.selectedProfileID }
    }

    private var visibleProfiles: [LaunchProfile] {
        let query = presetSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return model.profiles }
        return model.profiles.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || ($0.unresolvedLegacyFiles ?? []).contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(
                title: "Presets",
                subtitle: "Optional saved load chains, including recoverable SSGL packages."
            ) {
                TextField("Search presets", text: $presetSearch)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 260)
            }
            Divider()
            if model.profiles.isEmpty {
                EmptyStateView(
                    title: "No presets yet",
                    systemImage: "bookmark",
                    message: "Build a load chain, then save it as a preset."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(visibleProfiles, selection: $model.selectedProfileID) { profile in
                    HStack(spacing: 10) {
                        Image(systemName: profile.importedFromSSGL ? "arrow.down.doc.fill" : "bookmark.fill")
                            .foregroundStyle(profile.importedFromSSGL ? .orange : .green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.name)
                            Text("\(profile.modPaths.count) file\(profile.modPaths.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if profile.unresolvedCount > 0 {
                                Text("\(profile.unresolvedCount) missing from disk")
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                            }
                        }
                        Spacer()
                        if profile.importedFromSSGL {
                            Text("IMPORTED")
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(.orange.opacity(0.18), in: Capsule())
                        }
                    }
                    .tag(profile.id)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { model.launchProfile(profile) }
                    .simultaneousGesture(TapGesture().onEnded {
                        model.selectedProfileID = profile.id
                    })
                }
                .listStyle(.inset)
            }
            Divider()
            HStack {
                Button("Delete") {
                    if let selected { model.deleteProfile(selected) }
                }
                .disabled(selected == nil)
                if let selected, selected.unresolvedCount > 0 {
                    Button("Reconnect Missing File…") {
                        model.reconnectMissingFile(in: selected)
                    }
                }
                Spacer()
                Button("Edit Chain") {
                    if let selected { model.loadProfile(selected) }
                }
                .disabled(selected == nil)
                Button("Play Preset") {
                    if let selected { model.launchProfile(selected) }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(selected == nil || model.defaultPort == nil)
            }
            .padding(12)
        }
    }
}

private struct SectionHeader<Accessory: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let accessory: Accessory

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.title3.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            accessory
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }
}

private struct EmptyLibraryView: View {
    let kind: LibraryListView.Kind

    var body: some View {
        EmptyStateView(
            title: kind == .mods ? "No mods found" : "No IWADs found",
            systemImage: kind == .mods ? "doc.badge.ellipsis" : "shippingbox",
            message: "Choose a WAD folder or change the current search."
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
    }
}

private struct SavePresetSheet: View {
    @EnvironmentObject private var model: LauncherModel
    @Binding var isPresented: Bool
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Save Load Chain")
                .font(.title2.weight(.semibold))
            Text("This saves the current port, IWAD, ordered files, and gameplay options.")
                .foregroundStyle(.secondary)
            TextField("Preset name", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit { save() }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { isPresented = false }
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22)
        .frame(width: 440)
    }

    private func save() {
        model.saveProfile(named: name)
        isPresented = false
    }
}

private struct StatusBarView: View {
    @EnvironmentObject private var model: LauncherModel

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(model.defaultPort == nil || model.defaultIWAD == nil ? .orange : .green)
                .frame(width: 7, height: 7)
            Text(model.status)
                .lineLimit(1)
            Spacer()
            if let port = model.defaultPort {
                Text(port.name)
                    .foregroundStyle(.secondary)
            }
            if let iwad = model.defaultIWAD {
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(iwad.displayName)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }
}
