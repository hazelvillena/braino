import AppKit
let root = CommandLine.arguments[1]
guard let image = NSImage(contentsOfFile: root + "/Assets/Braino.icns") else { fatalError("Missing icon") }
guard NSWorkspace.shared.setIcon(image, forFile: root + "/dist/Braino.dmg", options: []) else { fatalError("Could not set installer icon") }
