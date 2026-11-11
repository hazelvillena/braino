# Braino

A local Mac task companion with a compact desktop window, menu bar access and **Control–Space** capture.

## Install

Open `dist/Braino.dmg`, drag Braino to Applications and launch it. Quit an older Braino before replacing it. Tasks are stored outside the application bundle, so replacing the app keeps them.

Requires an Apple Silicon Mac running macOS 14 or newer. This is a locally signed build, not notarized for public distribution.

## Build

Requires Apple Command Line Tools, Python 3 and Node.js for development checks. No downloaded runtime dependencies.

```sh
./scripts/test.sh
./build.sh
open Braino.app
```

Create the installer with `./package.sh`.

## One interface

The Mac app bundles the exact HTML, CSS and JavaScript from `preview/` and renders it locally in WKWebView. There is no second SwiftUI implementation to drift from the preview. AppKit supplies the native window, menu bar, pinning, global shortcut and standard Edit menu (including Cmd+A, Cut, Copy, Paste and Undo).

`node preview/server.mjs` serves the same interface at http://localhost:4317. It binds only to 127.0.0.1. Browser demo tasks use separate browser-local storage; the installed Mac app reads and writes native files through a validated local message bridge. The desktop loads bundled files and does not require localhost or an internet connection.

The preview adds presentation chrome and demo controls around the interface. The Mac app uses the real macOS title bar and keeps the window sized to its content.

## Task flow

- Today includes today and overdue planned tasks. This week has collapsible white day cards and its own compact scrolling area, initially aligned to Today. Someday holds undated thoughts.
- Type into “add something” and press Return. Capture goes to the selected view. Due dates and categories are optional and independent of that placement.
- Task titles and expanded notes edit inline. Structured details use Save/Cancel. The category menu includes New category…; its unfiltered label is All.
- Complete a task for a short scratch-off. Completed history appears only when at least one completed task exists. It defaults to Past week and supports calendar-day, month, all-time and inclusive custom filters.
- Hover or focus a task to reveal Delete. Undo restores the latest deletion or completion.
- The pin keeps Braino above other windows. Closing the window leaves menu bar access and Control–Space running. Quit from the application or menu bar menu.

## Local data

Tasks remain at `~/Library/Application Support/Braino/tasks.json`; named categories are in `categories.json` in the same folder. Existing IDs, task text, notes, creation dates, planning dates, due dates and completion state are preserved by the desktop bridge. There is no cloud sync or analytics. Do not edit these files while Braino is running.

Agent integration is planned, not connected yet. Future writes should go through an app-owned API rather than editing the JSON concurrently.

## Brand and checks

`Assets/BrainoMark.png` is the original supplied transparent artwork. The Dock/installer icon places a larger version over a softly shaded lemon tile while preserving the mark's open spaces. Header and menu-bar glyphs retain transparency. `scripts/BrandAssets.swift` regenerates the assets.

See `docs/design-system.md` for design choices and research. Checks cover planning/history filters, native migration and persistence, delete/Undo, category persistence, bridge round-trips and bundled-interface parity. An isolated desktop smoke test verified capture, saved-task reload, empty Completed behavior and Cmd+A replacement; test data lives separately under `.cache/desktop-qa`.
