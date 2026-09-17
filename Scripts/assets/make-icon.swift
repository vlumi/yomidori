#!/usr/bin/env swift
//
// App icon: a night-green plate (夜緑, the second reading of ヨミドリ) with a silver
// roundel — the Java sparrow's body, reduced to a shape — and a reading mark
// below it. Pure CoreGraphics, flattened opaque (App Store Connect silently
// rejects a transparent icon). Placeholder until the mascot art exists.
//   swift Scripts/assets/make-icon.swift <outDir>
// writes <outDir>/icon-1024.png.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let size: CGFloat = 1024

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGColor {
    CGColor(srgbRed: r, green: g, blue: b, alpha: 1)
}

let nightGreenTop = rgb(0.09, 0.30, 0.23)
let nightGreenBottom = rgb(0.04, 0.16, 0.12)
let silver = rgb(0.86, 0.88, 0.89)
let silverShade = rgb(0.62, 0.66, 0.69)
let beak = rgb(0.93, 0.55, 0.50)

let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(
    data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
    space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

// Plate: a vertical gradient, darker at the foot, like a lamp over a page at night.
let gradient = CGGradient(
    colorsSpace: space, colors: [nightGreenTop, nightGreenBottom] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(
    gradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: 0, y: 0), options: [])

// Body: a silver disc, shaded on its lower-left, sitting a little above centre.
let body = CGRect(x: size * 0.25, y: size * 0.33, width: size * 0.50, height: size * 0.50)
ctx.setFillColor(silverShade)
ctx.fillEllipse(in: body)
ctx.setFillColor(silver)
ctx.fillEllipse(in: body.insetBy(dx: size * 0.02, dy: size * 0.02).offsetBy(dx: size * 0.015, dy: size * 0.02))

// Eye and beak, the two marks that make a disc a bird.
ctx.setFillColor(nightGreenBottom)
ctx.fillEllipse(in: CGRect(x: size * 0.58, y: size * 0.62, width: size * 0.05, height: size * 0.05))
ctx.setFillColor(beak)
ctx.move(to: CGPoint(x: size * 0.74, y: size * 0.60))
ctx.addLine(to: CGPoint(x: size * 0.84, y: size * 0.565))
ctx.addLine(to: CGPoint(x: size * 0.74, y: size * 0.53))
ctx.closePath()
ctx.fillPath()

// The reading mark: a short ruby line under the body, where furigana sits over a word.
ctx.setFillColor(silver)
let rule = CGRect(x: size * 0.30, y: size * 0.20, width: size * 0.40, height: size * 0.035)
ctx.addPath(CGPath(roundedRect: rule, cornerWidth: rule.height / 2, cornerHeight: rule.height / 2, transform: nil))
ctx.fillPath()

let image = ctx.makeImage()!
let url = URL(fileURLWithPath: outDir).appendingPathComponent("icon-1024.png")
let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("could not write \(url.path)") }
print("wrote \(url.path)")
