// Draws Resources/AppIcon.icns. Run: swiftc scripts/make-icon.swift -o /tmp/make-icon && /tmp/make-icon
import AppKit

// Raboš brand palette and wordmark font (Rabos/ra_frontend/src/index.css).
let slate = NSColor(srgbRed: 0x23 / 255.0, green: 0x30 / 255.0, blue: 0x38 / 255.0, alpha: 1)
let amber = NSColor(srgbRed: 0xcf / 255.0, green: 0x8a / 255.0, blue: 0x3c / 255.0, alpha: 1)
let paper = NSColor(srgbRed: 0xf4 / 255.0, green: 0xef / 255.0, blue: 0xe8 / 255.0, alpha: 1)

let scriptDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let fontURL = scriptDir.appendingPathComponent("fonts/IBMPlexSans-SemiBold.ttf")
guard let plexSemiBold = (CTFontManagerCreateFontDescriptorsFromURL(fontURL as CFURL) as? [CTFontDescriptor])?.first else {
    fatalError("Missing \(fontURL.path)")
}

func render(size: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = size / 1024

    // Paper tile with a soft shadow, inset like Apple's icon grid.
    let tile = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let shadow = NSShadow()
    shadow.shadowBlurRadius = 24 * s
    shadow.shadowOffset = NSSize(width: 0, height: -10 * s)
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
    NSGraphicsContext.current?.saveGraphicsState()
    shadow.set()
    paper.setFill()
    NSBezierPath(roundedRect: tile, xRadius: 185 * s, yRadius: 185 * s).fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    // Lowercase "md" in slate, centred on its visible glyph bounds, with an amber underline.
    let font = CTFontCreateWithFontDescriptor(plexSemiBold, 430 * s, nil)
    let text = NSAttributedString(string: "md", attributes: [.font: font, .foregroundColor: slate])
    let line = CTLineCreateWithAttributedString(text)
    let context = NSGraphicsContext.current!.cgContext
    let bounds = CTLineGetImageBounds(line, context)
    let barHeight = 44 * s, gap = 70 * s
    let groupHeight = bounds.height + gap + barHeight
    let glyphBottom = tile.midY - groupHeight / 2 + barHeight + gap
    context.textPosition = CGPoint(x: tile.midX - bounds.midX, y: glyphBottom - bounds.minY)
    CTLineDraw(line, context)

    amber.setFill()
    let bar = NSRect(x: tile.midX - bounds.width / 2, y: glyphBottom - gap - barHeight,
                     width: bounds.width, height: barHeight)
    NSBezierPath(roundedRect: bar, xRadius: barHeight / 2, yRadius: barHeight / 2).fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath)
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        let data = render(size: CGFloat(base * scale)).representation(using: .png, properties: [:])!
        try data.write(to: iconset.appendingPathComponent(name))
    }
}

let output = root.appendingPathComponent("Resources/AppIcon.icns")
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try iconutil.run()
iconutil.waitUntilExit()
print("Wrote \(output.path)")
