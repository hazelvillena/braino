# Braino

A local Mac task companion: a quiet desktop window, menu bar access, and Control–Space to bring it forward and focus quick capture.

## Run

Requires macOS 14+ and Apple Command Line Tools. No third-party dependencies.

```sh
./build.sh
open Braino.app
```

Enter a task and press Return. Today includes overdue tasks; This week shows Monday–Sunday with inline capture under every day; Someday holds undated ideas. The ellipsis opens a soft task editor for notes, schedule and an optional category and due date; Save commits the draft and Cancel discards it. New category… is available in the category dropdown. Complete a task to play a short scratch-off and move it to the Completed dropdown. Filter completion history by day, week, month, all time or inclusive custom dates. Undo restores the last completion. The icon-only pin keeps Braino above other apps; hover for “Keep on top.” Closing the window keeps menu bar access and the shortcut running. Quit from the menu bar.

## Local data and agent integration

Tasks persist in `~/Library/Application Support/Braino/tasks.json`. No cloud, analytics, or network requests. Stable UUIDs, title, notes, schedule date, optional category, and completion timestamp form the initial task model.

Agent integration is planned, not connected yet. Use an app-owned command/API layer for future writes so agents and the UI cannot overwrite each other. Do not edit the JSON while the app is running. Future work: agent task provenance, reviewable proposed changes, projects, recurring tasks, configurable shortcut, and launch at login.

## Source

`Sources/Braino.swift` contains the SwiftUI interface, AppKit window/menu bar lifecycle, Carbon hotkey registration, and atomic JSON persistence. `Package.swift` supports opening the project in development tools; `build.sh` builds the app directly with a local compiler cache.

This is an initial prototype. It is locally ad-hoc signed, not notarized for distribution. Build verification does not establish interactive UI or shortcut behavior; those require a desktop smoke test.

## Branding and installer

The warm yellow/black identity is shared across the app, Dock, Finder and installer. Run `./package.sh` to create `dist/Braino.dmg`; open it and drag Braino to Applications. This build targets Apple Silicon Macs. The installer and app are locally signed, not notarized. macOS may require approval when distributing to another Mac.

Generate a deterministic interface preview without changing tasks:

```sh
Braino.app/Contents/MacOS/Braino --render-preview /tmp/braino-preview.png
```

## Local browser design preview

Run `node preview/server.mjs`, then visit http://localhost:4317. No dependencies or installation needed. The preview supports capture, Today/Inbox/Logbook, notes, and completion with its own browser-local demo data. It is an HTML approximation, not the native SwiftUI renderer; native window pinning and system-wide hotkeys are not available in a browser. The server binds only to 127.0.0.1 and serves only the preview and its icon. Stop with Control-C.

## Design and verification

See [the design system](docs/design-system.md) for tokens, completion timing, information architecture, research and migration behavior. Run `./scripts/test.sh` for browser model tests and native storage, migration, scheduling and history checks. Browser demo state uses `braino-preview-v2`; existing v1 tasks migrate without inventing dates. Preview data remains separate from native data.

New thoughts go into the active planning view. Due dates are optional and independent of the planning date; assigning a due date does not move a thought to another view. Notes can be expanded or collapsed without opening the full editor.

Task titles and expanded notes can also be edited directly in place and save as typed. Capture uses “add something” in a soft dashed outline. The category filter’s unfiltered label is All.

This week stays within a compact scroll area. Each day is a rounded card that can be collapsed independently. Hover over a task to reveal Delete; Undo restores it.

The weekly view lands on Today at the top; scroll up for earlier days or down for later days. Day cards and task cards share white surfaces.
