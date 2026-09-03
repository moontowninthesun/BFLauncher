# BFLauncher

**Big firepower. Small friction.**

BFLauncher is a fast, native Doom launcher for macOS. It is a modern fork and
rewrite of [Super Shotgun Launcher](https://github.com/FreaKzero/ssgl-doom-launcher),
built around a two-action default flow:

1. Select a PWAD.
2. Press **Play**.

Your preferred source port and IWAD are remembered. Double-clicking a PWAD is
even faster.

## What works today

- Native SwiftUI interface for macOS 13 and newer
- Universal binary: Apple Silicon and Intel
- Automatic discovery of installed Doom source-port apps
- Manual source-port picker for uncommon or locally built ports
- Recursive scanning of one WAD folder for both IWADs and mods
- Content-based IWAD recognition, including renamed IWADs
- Doom II selected as the initial default when available
- Search by filename or folder and sort by name, folder, or date
- Direct launch of a single PWAD without creating a package
- Ordered multi-file load chains for WAD, PK3, PK7, ZIP, DEH, BEX, and LMP files
- Skill, warp, fast-monsters, no-monsters, respawn, pistol-start, and free-form
  source-port arguments
- Exact command preview before an advanced launch
- Saved presets for frequently used load chains
- One-time import of legacy SSGL package names, IWADs, load order, and custom
  parameters; unavailable files are preserved and marked as missing
- Read-only library indexing: BFLauncher never moves, copies, or renames WADs

## Build

Full Xcode is not required. Apple's current Command Line Tools are sufficient.

```sh
Scripts/run-self-tests.sh
Scripts/build-macos-app.sh dist
open dist/BFLauncher.app
```

The build script creates an ad-hoc-signed Universal app at
`dist/BFLauncher.app`.

## Design

BFLauncher treats the folder as the library. Presets are useful for elaborate
combinations, but they are never required to play a PWAD. This keeps the quick
path quick while retaining precise load order and command-line control for
advanced setups.

Useful ideas were studied from Doom Runner (folder synchronization and ordered
presets), Doom Launcher (library management), Rocket Launcher (drag-and-drop
load composition), and SSGL's original “fast in, fast out” goal. BFLauncher is
a native macOS implementation with no Electron runtime.

## Data and privacy

Settings and presets are stored in `~/Library/Application Support/BFLauncher`.
The chosen WAD folder is only read. Source ports are launched locally with the
arguments shown in the command preview. BFLauncher has no analytics or network
service.

## Credits and license

BFLauncher is an MIT-licensed fork of SSGL. The original SSGL code is retained
in `app/` for history and attribution; the native implementation lives in
`Sources/BFLauncher/`. Original SSGL code is copyright Thomas Petrovic.

DOOM is a registered trademark of id Software LLC. BFLauncher is not affiliated
with or endorsed by id Software, Bethesda, ZeniMax, or any source-port project.
