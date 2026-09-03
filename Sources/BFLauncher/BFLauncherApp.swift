import SwiftUI

@main
struct BFLauncherApp: App {
    @StateObject private var model = LauncherModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 920, minHeight: 600)
        }
        .defaultSize(width: 1180, height: 720)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Choose WAD Folder…") { model.chooseWADFolder() }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                Button("Add Source Port…") { model.addSourcePort() }
                Divider()
                Button("Rescan Library") { model.rescanAll() }
                    .keyboardShortcut("r", modifiers: .command)
            }
            CommandMenu("Play") {
                Button("Launch Selected") { model.quickLaunch() }
                    .keyboardShortcut(.return, modifiers: .command)
                Button("Launch Load Chain") { model.launchChain() }
                    .keyboardShortcut(.return, modifiers: [.command, .shift])
            }
        }
    }
}
