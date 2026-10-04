// Draws the app icon: an e⁺e⁻ → γ* → μ⁺μ⁻ Feynman diagram on an indigo background.
//
//   swift Tools/MakeIcon.swift
//
// Writes the iOS icon (full-bleed, opaque; iOS rounds the corners) and the macOS icon
// (rounded square with margin and shadow, on transparency).

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

/// Fills `rect` with the background and draws the diagram inside it. Coordinates have y pointing down.
func drawIcon(in ctx: CGContext, rect: CGRect) {
    // Background: indigo, lighter toward the top, with a soft glow behind the photon.
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: [color(0x3A3F9E), color(0x161845)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: rect.midX, y: rect.minY), end: CGPoint(x: rect.midX, y: rect.maxY), options: [])
    let glow = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                          colors: [color(0xFF9F43, 0.35), color(0xFF9F43, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: rect.midX, y: rect.midY), startRadius: 0,
                           endCenter: CGPoint(x: rect.midX, y: rect.midY), endRadius: rect.width * 0.42, options: [])

    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height) }
    let w = rect.width
    let left = p(0.33, 0.5), right = p(0.67, 0.5)

    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    // Photon: a bold orange wave with a glow.
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: w * 0.03, color: color(0xFFB347, 0.9))
    ctx.setStrokeColor(color(0xFFA040))
    ctx.setLineWidth(w * 0.03)
    let halfWaves = 7.0, amplitude = w * 0.042
    let length = right.x - left.x
    ctx.move(to: left)
    for i in 0...200 {
        let t = CGFloat(i) / 200
        ctx.addLine(to: CGPoint(x: left.x + t * length, y: left.y - amplitude * sin(.pi * halfWaves * t)))
    }
    ctx.strokePath()
    ctx.restoreGState()

    // Fermions: white lines with arrows showing particle flow (antiparticles point backward).
    let white = color(0xFFFFFF)
    ctx.setStrokeColor(white)
    ctx.setFillColor(white)
    ctx.setLineWidth(w * 0.03)
    let lines: [(CGPoint, CGPoint, Bool)] = [
        (p(0.14, 0.22), left, true),      // e⁻ in, arrow toward the vertex
        (p(0.14, 0.78), left, false),     // e⁺ in, arrow away from the vertex
        (right, p(0.86, 0.22), true),     // μ⁻ out, arrow away from the vertex
        (right, p(0.86, 0.78), false),    // μ⁺ out, arrow toward the vertex
    ]
    for (a, b, forward) in lines {
        ctx.move(to: a)
        ctx.addLine(to: b)
        ctx.strokePath()
        let dx = b.x - a.x, dy = b.y - a.y, len = hypot(dx, dy)
        var t = CGPoint(x: dx / len, y: dy / len)
        if !forward { t = CGPoint(x: -t.x, y: -t.y) }
        let n = CGPoint(x: -t.y, y: t.x)
        let m = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        let s = w * 0.05
        ctx.move(to: CGPoint(x: m.x + t.x * s, y: m.y + t.y * s))
        ctx.addLine(to: CGPoint(x: m.x - t.x * s * 0.7 + n.x * s * 0.75, y: m.y - t.y * s * 0.7 + n.y * s * 0.75))
        ctx.addLine(to: CGPoint(x: m.x - t.x * s * 0.3, y: m.y - t.y * s * 0.3))
        ctx.addLine(to: CGPoint(x: m.x - t.x * s * 0.7 - n.x * s * 0.75, y: m.y - t.y * s * 0.7 - n.y * s * 0.75))
        ctx.closePath()
        ctx.fillPath()
    }

    // Vertices.
    for v in [left, right] {
        let r = w * 0.04
        ctx.fillEllipse(in: CGRect(x: v.x - r, y: v.y - r, width: 2 * r, height: 2 * r))
    }
}

func makeContext(opaque: Bool) -> CGContext {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: (opaque ? CGImageAlphaInfo.noneSkipLast : CGImageAlphaInfo.premultipliedLast).rawValue)!
    // Flip so y points down, matching the drawing code.
    ctx.translateBy(x: 0, y: CGFloat(size))
    ctx.scaleBy(x: 1, y: -1)
    return ctx
}

func write(_ ctx: CGContext, to url: URL) {
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
    print("Wrote \(url.path)")
}

// iOS: full-bleed and opaque.
let ios = makeContext(opaque: true)
drawIcon(in: ios, rect: CGRect(x: 0, y: 0, width: size, height: size))
write(ios, to: root.appending(path: "iOS/Assets.xcassets/AppIcon.appiconset/AppIcon.png"))

// macOS: rounded square on the standard 824pt grid, with a drop shadow.
let mac = makeContext(opaque: false)
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let shape = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)
mac.saveGState()
mac.setShadow(offset: CGSize(width: 0, height: 12), blur: 28, color: color(0x000000, 0.35))
mac.addPath(shape)
mac.setFillColor(color(0x161845))
mac.fillPath()
mac.restoreGState()
mac.saveGState()
mac.addPath(shape)
mac.clip()
drawIcon(in: mac, rect: body)
mac.restoreGState()
write(mac, to: root.appending(path: "Sources/Quarksman/Resources/AppIcon.png"))
