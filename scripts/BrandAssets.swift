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
    // Composite the unchanged transparent source over a lemon tile for the Dock.
    // The mark itself remains open/transparent; it is never turned into a silhouette.
    if rounded {
        NSBezierPath(roundedRect: rect, xRadius: side * 0.20, yRadius: side * 0.20).addClip()
        let bottom = NSColor(calibratedRed: 243.0/255, green: 210.0/255, blue: 30.0/255, alpha: 1)
        let top = NSColor(calibratedRed: 255.0/255, green: 233.0/255, blue: 109.0/255, alpha: 1)
        NSGradient(starting: bottom, ending: top)!.draw(in: rect, angle: 90)
    }
    let sourceRect = rounded ? NSRect(x: 350, y: 210, width: 830, height: 620) : NSRect(x: 300, y: 180, width: 950, height: 720)
    let width = rect.width * (rounded ? 0.96 : 0.98)
    let height = width * sourceRect.height / sourceRect.width
    let markRect = NSRect(x: rect.midX - width/2, y: rect.midY - height/2, width: width, height: height)
    image.draw(in: markRect, from: sourceRect, operation: .sourceOver, fraction: 1)
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

try render(256, rounded: false).representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("Assets/BrainoGlyph.png"))
