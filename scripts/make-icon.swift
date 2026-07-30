// Regenerates the app icon:
//   swift scripts/make-icon.swift Pomodoro/Assets.xcassets/AppIcon.appiconset/icon-1024.png
//
// Draws the same progress ring the app itself uses, on the app's backdrop.
// No alpha channel — the App Store rejects icons that have one.

import AppKit
import CoreGraphics

let size = 1024.0
let cs = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8,
                    bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

// Background: dark base with a warm radial glow, matching the app backdrop.
ctx.setFillColor(CGColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1))
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

let glow = CGGradient(colorsSpace: cs, colors: [
    CGColor(red: 1.0, green: 0.42, blue: 0.35, alpha: 0.55),
    CGColor(red: 1.0, green: 0.42, blue: 0.35, alpha: 0.0)
] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(glow,
                       startCenter: CGPoint(x: size * 0.5, y: size * 0.62), startRadius: 0,
                       endCenter: CGPoint(x: size * 0.5, y: size * 0.62), endRadius: size * 0.62,
                       options: [])

// Progress ring: three-quarter arc in ember over a faint full-circle track.
let center = CGPoint(x: size / 2, y: size / 2)
let radius = size * 0.30
let lineWidth = size * 0.075

ctx.setLineCap(.round)
ctx.setLineWidth(lineWidth)
ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.10))
ctx.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
ctx.strokePath()

ctx.setStrokeColor(CGColor(red: 1.0, green: 0.42, blue: 0.35, alpha: 1))
ctx.addArc(center: center, radius: radius, startAngle: .pi / 2, endAngle: -.pi, clockwise: true)
ctx.strokePath()

let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
let data = rep.representation(using: .png, properties: [:])!
try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
