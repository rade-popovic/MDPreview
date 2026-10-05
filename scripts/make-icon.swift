// Draws Resources/AppIcon.icns. Run: swiftc scripts/make-icon.swift -o /tmp/make-icon && /tmp/make-icon
import AppKit

func render(size: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = size / 1024

    // Page with a soft shadow, inset like Apple's icon grid.
    let page = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let shadow = NSShadow()
    shadow.shadowBlurRadius = 24 * s
    shadow.shadowOffset = NSSize(width: 0, height: -10 * s)
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    NSGraphicsContext.current?.saveGraphicsState()
    shadow.set()
    let pagePath = NSBezierPath(roundedRect: page, xRadius: 185 * s, yRadius: 185 * s)
    NSGradient(starting: NSColor(white: 1, alpha: 1), ending: NSColor(white: 0.92, alpha: 1))!
        .draw(in: pagePath, angle: -90)
    NSGraphicsContext.current?.restoreGraphicsState()

    // Blue header band.
    NSGraphicsContext.current?.saveGraphicsState()
    pagePath.addClip()
    let band = NSRect(x: page.minX, y: page.maxY - 190 * s, width: page.width, height: 190 * s)
    NSGradient(starting: NSColor(calibratedRed: 0.30, green: 0.56, blue: 0.98, alpha: 1),
               ending: NSColor(calibratedRed: 0.16, green: 0.40, blue: 0.90, alpha: 1))!
        .draw(in: band, angle: -90)
    NSGraphicsContext.current?.restoreGraphicsState()

    // "M↓" mark.
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 400 * s, weight: .heavy),
        .foregroundColor: NSColor(white: 0.18, alpha: 1),
        .paragraphStyle: paragraph,
    ]
    let text = NSAttributedString(string: "M↓", attributes: attributes)
    let textSize = text.size()
    text.draw(in: NSRect(x: page.minX, y: page.minY + (page.height - 190 * s - textSize.height) / 2,
                         width: page.width, height: textSize.height))

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
