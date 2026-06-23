#!/usr/bin/env swift
import AppKit

guard CommandLine.arguments.count == 2 || CommandLine.arguments.count == 3 else {
    fputs("Usage: generate_icon.swift <output.iconset> [source.png]\n", stderr)
    exit(2)
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
let sourceImage = CommandLine.arguments.count == 3 ? NSImage(contentsOfFile: CommandLine.arguments[2]) : nil

let outputs: [(pixels: Int, name: String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

func drawSourceIcon(_ image: NSImage, pixels: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "LiheIcon", code: 1)
    }

    bitmap.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

    let canvas = NSRect(x: 0, y: 0, width: pixels, height: pixels)
    NSColor.clear.setFill()
    canvas.fill()

    let inset = CGFloat(pixels) * 0.055
    let tile = canvas.insetBy(dx: inset, dy: inset)
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: CGFloat(pixels) * 0.22, yRadius: CGFloat(pixels) * 0.22)
    tilePath.addClip()
    image.draw(in: tile, from: .zero, operation: .sourceOver, fraction: 1)

    NSGraphicsContext.restoreGraphicsState()
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "LiheIcon", code: 2)
    }
    return data
}

func drawGeneratedIcon(pixels: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "LiheIcon", code: 1)
    }

    bitmap.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

    let canvas = NSRect(x: 0, y: 0, width: pixels, height: pixels)
    NSColor.clear.setFill()
    canvas.fill()

    let inset = CGFloat(pixels) * 0.055
    let tile = canvas.insetBy(dx: inset, dy: inset)
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: CGFloat(pixels) * 0.22, yRadius: CGFloat(pixels) * 0.22)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.16, green: 0.25, blue: 0.96, alpha: 1),
        NSColor(calibratedRed: 0.46, green: 0.24, blue: 0.92, alpha: 1)
    ])!
    gradient.draw(in: tilePath, angle: -45)

    let line = NSBezierPath()
    line.lineWidth = max(1, CGFloat(pixels) * 0.055)
    line.lineCapStyle = .round
    let points = [
        NSPoint(x: CGFloat(pixels) * 0.30, y: CGFloat(pixels) * 0.35),
        NSPoint(x: CGFloat(pixels) * 0.50, y: CGFloat(pixels) * 0.67),
        NSPoint(x: CGFloat(pixels) * 0.72, y: CGFloat(pixels) * 0.39)
    ]
    line.move(to: points[0])
    line.line(to: points[1])
    line.line(to: points[2])
    NSColor.white.withAlphaComponent(0.9).setStroke()
    line.stroke()

    for point in points {
        let radius = CGFloat(pixels) * 0.085
        let circle = NSBezierPath(ovalIn: NSRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
        NSColor.white.setFill()
        circle.fill()
    }

    NSGraphicsContext.restoreGraphicsState()
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "LiheIcon", code: 2)
    }
    return data
}

for output in outputs {
    let data = try sourceImage.map { try drawSourceIcon($0, pixels: output.pixels) } ?? drawGeneratedIcon(pixels: output.pixels)
    try data.write(to: outputDirectory.appendingPathComponent(output.name))
}
