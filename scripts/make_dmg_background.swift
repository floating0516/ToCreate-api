#!/usr/bin/env swift
import AppKit
import Foundation

let size = NSSize(width: 660, height: 400)
let scale: CGFloat = 2

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("Usage: make_dmg_background.swift <output.png>\n".utf8))
    exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let bounds = NSRect(origin: .zero, size: size)

guard
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size.width * scale),
        pixelsHigh: Int(size.height * scale),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )
else {
    FileHandle.standardError.write(Data("Failed to render DMG background.\n".utf8))
    exit(1)
}

bitmap.size = size

NSGraphicsContext.saveGraphicsState()
let context = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.current = context

NSColor(calibratedRed: 0.97, green: 0.985, blue: 0.99, alpha: 1).setFill()
bounds.fill()

let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.98, green: 0.99, blue: 0.99, alpha: 1),
    NSColor(calibratedRed: 0.89, green: 0.93, blue: 0.97, alpha: 1)
])
gradient?.draw(in: bounds, angle: -90)

func drawGlow(center: NSPoint, radius: CGFloat, color: NSColor) {
    let rect = NSRect(
        x: center.x - radius,
        y: center.y - radius,
        width: radius * 2,
        height: radius * 2
    )
    let path = NSBezierPath(ovalIn: rect)
    color.setFill()
    path.fill()
}

drawGlow(center: NSPoint(x: 58, y: 326), radius: 230, color: NSColor(calibratedRed: 0.50, green: 0.80, blue: 0.64, alpha: 0.20))
drawGlow(center: NSPoint(x: 586, y: 88), radius: 230, color: NSColor(calibratedRed: 0.54, green: 0.62, blue: 0.92, alpha: 0.18))

let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 25, weight: .semibold),
    .foregroundColor: NSColor(calibratedRed: 0.16, green: 0.21, blue: 0.27, alpha: 1)
]
let subtitleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 15, weight: .regular),
    .foregroundColor: NSColor(calibratedRed: 0.39, green: 0.46, blue: 0.53, alpha: 1)
]
let hintTitleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 13, weight: .medium),
    .foregroundColor: NSColor(calibratedRed: 0.26, green: 0.32, blue: 0.39, alpha: 1)
]
let hintAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 12, weight: .regular),
    .foregroundColor: NSColor(calibratedRed: 0.39, green: 0.46, blue: 0.54, alpha: 1)
]

("安装 ToCreate" as NSString).draw(at: NSPoint(x: 72, y: 336), withAttributes: titleAttributes)
("拖动左侧应用到右侧 Applications 文件夹" as NSString).draw(at: NSPoint(x: 72, y: 309), withAttributes: subtitleAttributes)

let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 252, y: 184))
arrow.line(to: NSPoint(x: 394, y: 184))
arrow.move(to: NSPoint(x: 394, y: 184))
arrow.line(to: NSPoint(x: 378, y: 195))
arrow.move(to: NSPoint(x: 394, y: 184))
arrow.line(to: NSPoint(x: 378, y: 173))
arrow.lineWidth = 4
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
NSColor(calibratedRed: 0.30, green: 0.37, blue: 0.46, alpha: 0.78).setStroke()
arrow.stroke()

let cardRect = NSRect(x: 60, y: 34, width: 540, height: 54)
let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: 14, yRadius: 14)
NSColor.white.withAlphaComponent(0.72).setFill()
cardPath.fill()
NSColor(calibratedRed: 0.80, green: 0.84, blue: 0.88, alpha: 0.72).setStroke()
cardPath.lineWidth = 1
cardPath.stroke()

("首次打开如被 macOS 拦截：" as NSString).draw(at: NSPoint(x: 84, y: 58), withAttributes: hintTitleAttributes)
("系统设置 > 隐私与安全性 > 允许打开 ToCreate" as NSString).draw(at: NSPoint(x: 84, y: 40), withAttributes: hintAttributes)

NSGraphicsContext.restoreGraphicsState()

guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("Failed to encode DMG background.\n".utf8))
    exit(1)
}

try pngData.write(to: outputURL)
