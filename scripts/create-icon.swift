import AppKit
let directory = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let side = points * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let factor = CGFloat(side) / 1024
        let transform = NSAffineTransform(); transform.scale(by: factor); transform.concat()
        NSColor(red: 0.10, green: 0.105, blue: 0.12, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 38, y: 38, width: 948, height: 948), xRadius: 210, yRadius: 210).fill()
        NSColor(red: 0.32, green: 0.20, blue: 0.20, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 244, y: 378, width: 588, height: 408), xRadius: 80, yRadius: 80).fill()
        NSColor(red: 1, green: 0.40, blue: 0.33, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 184, y: 268, width: 588, height: 408), xRadius: 80, yRadius: 80).fill()
        NSColor.white.setFill()
        let play = NSBezierPath(); play.move(to: NSPoint(x: 416, y: 370))
        play.line(to: NSPoint(x: 416, y: 574)); play.line(to: NSPoint(x: 580, y: 472)); play.close(); play.fill()
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
    }
}
