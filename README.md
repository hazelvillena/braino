# Braino

A local Mac task companion: a quiet desktop window, menu bar access, and Control–Option–Space to bring it forward and focus quick capture.

## Run

Requires macOS 14+ and Apple Command Line Tools. No third-party dependencies.

```sh
./build.sh
open Braino.app
```

Enter a task and press Return. The sun toggles Today; the circle completes a task. Click the ellipsis to edit notes. Right-click a task to delete it. The pin keeps the window above other apps; unpinning leaves it as a normal desktop window. Closing the window keeps the menu bar and shortcut running. Quit from the menu bar. The app follows you across Spaces.

Inbox contains all open tasks, including Today tasks. Logbook contains completed tasks; click a completed circle to reopen it.

## Local data and agent integration

Tasks persist in `~/Library/Application Support/Braino/tasks.json`. No cloud, analytics, or network requests. Stable UUIDs, title, notes, Today and completion flags form the initial task model.

Agent integration is planned, not connected yet. Use an app-owned command/API layer for future writes so agents and the UI cannot overwrite each other. Do not edit the JSON while the app is running. Future work: agent task provenance, reviewable proposed changes, projects, scheduling, recurring tasks, undo, configurable shortcut, and launch at login.

## Source

`Sources/Braino.swift` contains the SwiftUI interface, AppKit window/menu bar lifecycle, Carbon hotkey registration, and atomic JSON persistence. `Package.swift` supports opening the project in development tools; `build.sh` builds the app directly with a local compiler cache.

This is an initial prototype. It is locally ad-hoc signed, not notarized for distribution. Build verification does not establish interactive UI or shortcut behavior; those require a desktop smoke test.
