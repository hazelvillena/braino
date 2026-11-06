import AppKit
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let source = root.appendingPathComponent("Assets/BrainoMark.png")
guard let image = NSImage(contentsOf: source) else { fatalError("Missing brand image") }
let iconset = root.appendingPathComponent(".cache/Braino.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
func bitmap(_ size: Int) -> NSBitmapImageRep {
    NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: size * 4, bitsPerPixel: 32)!
}
func render(_ size: Int, rounded: Bool) -> NSBitmapImageRep {
    let rep = bitmap(size)
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
    context.imageInterpolation = .high
    let side = CGFloat(size)
    let inset = rounded ? side * 0.055 : 0
    let rect = NSRect(x: inset, y: inset, width: side - 2 * inset, height: side - 2 * inset)
    if rounded { NSBezierPath(roundedRect: rect, xRadius: side * 0.20, yRadius: side * 0.20).addClip() }
    if rounded {
        NSColor(calibratedRed: 244.0/255, green: 200.0/255, blue: 74.0/255, alpha: 1).setFill()
        rect.fill()
    }
    let ratio = image.size.width / image.size.height
    let markRect = NSRect(x: rect.minX, y: rect.midY - rect.width / ratio / 2, width: rect.width, height: rect.width / ratio)
    image.draw(in: markRect, from: .zero, operation: .sourceOver, fraction: 1)
    context.flushGraphics(); NSGraphicsContext.restoreGraphicsState()
    return rep
}
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(base)x\(base)\(scale == 2 ? "@2x" : "").png"
        try render(base * scale, rounded: true).representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(name))
    }
}
// Preserve original per-pixel alpha, including the dissolving fragments.
let full = render(128, rounded: false)
try full.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("Assets/BrainoMenu.png"))
try render(1024, rounded: true).representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("Assets/BrainoIcon.png"))
