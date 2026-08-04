// 仮アイコンの .icns を生成する（後で本番デザインに差し替える）。
//
//     swift assets/make-icon.swift
import AppKit

let assetsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let iconsetURL = assetsDir.appendingPathComponent("AppIcon.iconset")
let icnsURL = assetsDir.appendingPathComponent("AppIcon.icns")

func renderPNG(canvas: Int) -> Data {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: canvas, pixelsHigh: canvas,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else {
        fatalError("cannot allocate \(canvas)px bitmap")
    }
    rep.size = NSSize(width: canvas, height: canvas)

    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high

    let inset = CGFloat(canvas) * 0.1
    let rect = NSRect(x: inset, y: inset, width: CGFloat(canvas) - inset * 2, height: CGFloat(canvas) - inset * 2)

    let bg = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.22, yRadius: rect.width * 0.22)
    NSColor(calibratedRed: 0.12, green: 0.18, blue: 0.28, alpha: 1).setFill()
    bg.fill()

    // 簡易プリズム（三角形）
    let tri = NSBezierPath()
    let midX = rect.midX
    let top = rect.minY + rect.height * 0.22
    let bottom = rect.minY + rect.height * 0.78
    let left = rect.minX + rect.width * 0.22
    let right = rect.minX + rect.width * 0.78
    tri.move(to: NSPoint(x: midX, y: top))
    tri.line(to: NSPoint(x: right, y: bottom))
    tri.line(to: NSPoint(x: left, y: bottom))
    tri.close()
    NSColor(calibratedRed: 0.95, green: 0.55, blue: 0.25, alpha: 1).setFill()
    tri.fill()

    // 分光の帯
    let bandHeight = rect.height * 0.06
    let colors: [NSColor] = [
        NSColor(calibratedRed: 0.95, green: 0.35, blue: 0.35, alpha: 0.9),
        NSColor(calibratedRed: 0.95, green: 0.75, blue: 0.25, alpha: 0.9),
        NSColor(calibratedRed: 0.35, green: 0.85, blue: 0.45, alpha: 0.9),
        NSColor(calibratedRed: 0.35, green: 0.55, blue: 0.95, alpha: 0.9),
    ]
    for (i, color) in colors.enumerated() {
        let y = bottom + CGFloat(i) * (bandHeight * 0.35)
        let band = NSBezierPath(roundedRect: NSRect(
            x: midX,
            y: y,
            width: rect.width * 0.28,
            height: bandHeight * 0.55
        ), xRadius: 2, yRadius: 2)
        color.setFill()
        band.fill()
    }

    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("cannot encode \(canvas)px PNG")
    }
    return data
}

let entries: [(points: Int, scale: Int)] = [
    (16, 1), (16, 2), (32, 1), (32, 2), (128, 1),
    (128, 2), (256, 1), (256, 2), (512, 1), (512, 2),
]

try? FileManager.default.removeItem(at: iconsetURL)
try! FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

for entry in entries {
    let px = entry.points * entry.scale
    let name = entry.scale == 1
        ? "icon_\(entry.points)x\(entry.points).png"
        : "icon_\(entry.points)x\(entry.points)@\(entry.scale)x.png"
    try! renderPNG(canvas: px).write(to: iconsetURL.appendingPathComponent(name))
}

let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", iconsetURL.path, "-o", icnsURL.path]
try! proc.run()
proc.waitUntilExit()
guard proc.terminationStatus == 0 else {
    fatalError("iconutil failed")
}
print("Wrote \(icnsURL.path)")
