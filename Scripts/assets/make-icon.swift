#!/usr/bin/env swift
//
// App icon: the mascot, a silver Java sparrow (文鳥, the "text bird") seen head-on,
// mochi-style: one round chest, the head sunk into it, perched low on a silver rule
// with its toes showing. Pure CoreGraphics on the night-green plate (夜緑, the second
// reading of ヨミドリ), flattened opaque because App Store Connect silently rejects
// a transparent icon. To change the icon, change the numbers below and re-run.
//   swift Scripts/assets/make-icon.swift <outDir>
// writes <outDir>/icon-1024.png.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let size: CGFloat = 1024

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r, green: g, blue: b, alpha: a)
}

// MARK: Colors

let nightGreenTop = rgb(0.09, 0.30, 0.23)
let nightGreenBottom = rgb(0.04, 0.16, 0.12)
let silver = rgb(0.86, 0.88, 0.89)
let chest = rgb(0.84, 0.86, 0.88)
let hood = rgb(0.60, 0.65, 0.70)
let hoodEdge = rgb(0.55, 0.60, 0.65)
let cheek = rgb(0.985, 0.985, 0.98)
let beakDeep = rgb(0.80, 0.22, 0.30)
let beakRed = rgb(0.89, 0.32, 0.38)
let beakPale = rgb(0.99, 0.86, 0.86)
let beakLine = rgb(0.70, 0.17, 0.25)
let eyeRing = rgb(0.93, 0.52, 0.58)
let eyeBlack = rgb(0.07, 0.07, 0.08)
let toe = rgb(0.95, 0.70, 0.72)
let toeLine = rgb(0.80, 0.50, 0.54)

// MARK: Proportions, as fractions of the icon's side

let cx = size / 2
let perchY = size * 0.15                  // the belly's lowest point; the rule sits just under it
let eggTop = size * 0.76                  // the chest, an egg wide at the bottom
let eggHalfWidth = size * 0.39
let eggWidestY = size * 0.40
let domeRadius = size * 0.215             // the head, a bump on top of the egg
let domeTop = size * 0.90
let faceY = domeTop - size * 0.13         // the line the beak rises from and the cheeks hang from
let hoodBottom = faceY - size * 0.13      // the darker crown ends here, behind the cheeks
let beakWidth = size * 0.20
let beakHeight = size * 0.22
let beakTop = faceY + size * 0.04
let beakBottom = beakTop - beakHeight
let mouth: CGFloat = 0.54                 // the mouth line, as a fraction down the beak
let mouthV: CGFloat = 0.08                // how far the line's point dips at the center
let eyeRadius = size * 0.027
let eyeX = size * 0.125
let eyeY = faceY - size * 0.025
let eyeTilt: CGFloat = 0.5                // radians, tops toward the beak: the eyes face sideways
let cheekWidth = size * 0.24
let cheekHeight = size * 0.20
let cheekY = faceY - size * 0.11

// MARK: Shapes

func rounded(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func ellipse(centerX: CGFloat, centerY: CGFloat, width: CGFloat, height: CGFloat) -> CGRect {
    CGRect(x: centerX - width / 2, y: centerY - height / 2, width: width, height: height)
}

/// The chest: an egg, widest low, narrowing toward the head.
func egg() -> CGPath {
    let p = CGMutablePath()
    let w = eggHalfWidth
    p.move(to: CGPoint(x: cx, y: eggTop))
    p.addCurve(
        to: CGPoint(x: cx + w, y: eggWidestY),
        control1: CGPoint(x: cx + w * 0.72, y: eggTop),
        control2: CGPoint(x: cx + w, y: eggTop - (eggTop - eggWidestY) * 0.45))
    p.addCurve(
        to: CGPoint(x: cx, y: perchY),
        control1: CGPoint(x: cx + w, y: eggWidestY - (eggWidestY - perchY) * 0.60),
        control2: CGPoint(x: cx + w * 0.60, y: perchY))
    p.addCurve(
        to: CGPoint(x: cx - w, y: eggWidestY),
        control1: CGPoint(x: cx - w * 0.60, y: perchY),
        control2: CGPoint(x: cx - w, y: eggWidestY - (eggWidestY - perchY) * 0.60))
    p.addCurve(
        to: CGPoint(x: cx, y: eggTop),
        control1: CGPoint(x: cx - w, y: eggTop - (eggTop - eggWidestY) * 0.45),
        control2: CGPoint(x: cx - w * 0.72, y: eggTop))
    p.closeSubpath()
    return p
}

/// The beak seen head-on: a square with a rounded top and a flat bottom.
func beak() -> CGPath {
    let p = CGMutablePath()
    let w = beakWidth, h = beakHeight, top = beakTop, bottom = beakBottom
    let corner = w * 0.14, halfBottom = w * 0.44
    p.move(to: CGPoint(x: cx, y: top))
    p.addCurve(
        to: CGPoint(x: cx - w * 0.5, y: top - h * 0.42),
        control1: CGPoint(x: cx - w * 0.36, y: top), control2: CGPoint(x: cx - w * 0.5, y: top - h * 0.14))
    p.addLine(to: CGPoint(x: cx - halfBottom, y: bottom + corner))
    p.addQuadCurve(to: CGPoint(x: cx - halfBottom + corner, y: bottom), control: CGPoint(x: cx - halfBottom, y: bottom))
    p.addLine(to: CGPoint(x: cx + halfBottom - corner, y: bottom))
    p.addQuadCurve(to: CGPoint(x: cx + halfBottom, y: bottom + corner), control: CGPoint(x: cx + halfBottom, y: bottom))
    p.addLine(to: CGPoint(x: cx + w * 0.5, y: top - h * 0.42))
    p.addCurve(
        to: CGPoint(x: cx, y: top),
        control1: CGPoint(x: cx + w * 0.5, y: top - h * 0.14), control2: CGPoint(x: cx + w * 0.36, y: top))
    p.closeSubpath()
    return p
}

// MARK: Drawing

let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(
    data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
    space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

func gradient(_ colors: [CGColor], _ locations: [CGFloat]) -> CGGradient {
    CGGradient(colorsSpace: space, colors: colors as CFArray, locations: locations)!
}

// Plate: darker at the foot, like a lamp over a page at night.
ctx.drawLinearGradient(
    gradient([nightGreenTop, nightGreenBottom], [0, 1]),
    start: CGPoint(x: 0, y: size), end: .zero, options: [])

// Perch: a silver rule, the reading mark under a word.
let rule = CGRect(x: size * 0.18, y: perchY - size * 0.05, width: size * 0.64, height: size * 0.042)
ctx.setFillColor(silver)
ctx.addPath(rounded(rule, rule.height / 2))
ctx.fillPath()

// Body: the egg and the head dome as one silhouette, flat gray with one broad soft
// highlight where the round breast catches the light, and a little weight at the belly.
let dome = CGPath(ellipseIn: ellipse(centerX: cx, centerY: domeTop - domeRadius, width: 2 * domeRadius, height: 2 * domeRadius), transform: nil)
let silhouette = egg().union(dome)
ctx.saveGState()
ctx.addPath(silhouette)
ctx.clip()
ctx.setFillColor(chest)
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
let highlight = CGPoint(x: cx - size * 0.05, y: size * 0.42)
ctx.drawRadialGradient(
    gradient([rgb(1, 1, 1, 0.16), rgb(1, 1, 1, 0)], [0, 1]),
    startCenter: highlight, startRadius: 0, endCenter: highlight, endRadius: size * 0.30, options: [])
ctx.drawLinearGradient(
    gradient([rgb(0, 0, 0, 0), rgb(0, 0, 0, 0.10)], [0, 1]),
    start: CGPoint(x: 0, y: perchY + size * 0.14), end: CGPoint(x: 0, y: perchY), options: [])
// Hood: the darker crown, inside the dome only, down to just below the eyes.
let hoodRect = CGRect(x: cx - domeRadius * 1.15, y: hoodBottom, width: domeRadius * 2.3, height: domeTop - hoodBottom)
ctx.addEllipse(in: hoodRect)
ctx.clip()
ctx.drawLinearGradient(
    gradient([hood, hood, hoodEdge], [0, 0.6, 1]),
    start: CGPoint(x: 0, y: hoodRect.maxY), end: CGPoint(x: 0, y: hoodRect.minY), options: [])
ctx.restoreGState()

// Toes: three each, wrapping the perch in front of the belly's edge.
for footX in [cx - size * 0.12, cx + size * 0.12] {
    for i in -1...1 {
        let w = size * 0.030, h = size * 0.085
        let r = CGRect(x: footX + CGFloat(i) * size * 0.031 - w / 2, y: perchY - h * 0.75, width: w, height: h)
        ctx.saveGState()
        ctx.translateBy(x: r.midX, y: r.maxY)
        ctx.rotate(by: CGFloat(i) * -0.2)
        ctx.translateBy(x: -r.midX, y: -r.maxY)
        ctx.setFillColor(toe)
        ctx.addPath(rounded(r, w / 2))
        ctx.fillPath()
        ctx.setStrokeColor(toeLine)
        ctx.setLineWidth(size * 0.004)
        ctx.addPath(rounded(r, w / 2))
        ctx.strokePath()
        ctx.restoreGState()
    }
}

// Chin in chest gray under the beak so the hood ends at the beak; then the cheeks,
// white ovals from the beak's sides to the edge of the head.
ctx.saveGState()
ctx.addPath(silhouette)
ctx.clip()
ctx.setFillColor(chest)
ctx.fillEllipse(in: CGRect(x: cx - beakWidth * 0.9, y: beakBottom - beakHeight * 0.9, width: beakWidth * 1.8, height: beakHeight * 1.25))
for side in [-1.0, 1.0] as [CGFloat] {
    let inner = beakWidth * 0.5 - size * 0.012
    let r = CGRect(
        x: side > 0 ? cx + inner : cx - inner - cheekWidth, y: cheekY - cheekHeight / 2,
        width: cheekWidth, height: cheekHeight)
    ctx.saveGState()
    ctx.translateBy(x: r.midX, y: r.midY)
    ctx.rotate(by: side * 0.18)
    ctx.translateBy(x: -r.midX, y: -r.midY)
    ctx.setFillColor(cheek)
    ctx.fillEllipse(in: r)
    ctx.restoreGState()
}
ctx.restoreGState()

// Beak: red, with a pale band along the mouth line, and the line itself a shallow V.
ctx.saveGState()
ctx.addPath(beak())
ctx.clip()
ctx.drawLinearGradient(
    gradient([beakDeep, beakRed, beakPale, beakPale, beakRed, beakRed], [0, 0.28, mouth - 0.05, mouth + 0.03, mouth + 0.26, 1]),
    start: CGPoint(x: 0, y: beakTop), end: CGPoint(x: 0, y: beakBottom), options: [])
ctx.setStrokeColor(beakLine)
ctx.setLineWidth(size * 0.005)
ctx.setLineJoin(.round)
ctx.setLineCap(.round)
ctx.move(to: CGPoint(x: cx - beakWidth * 0.47, y: beakTop - beakHeight * (mouth - 0.02)))
ctx.addLine(to: CGPoint(x: cx, y: beakTop - beakHeight * (mouth + mouthV)))
ctx.addLine(to: CGPoint(x: cx + beakWidth * 0.47, y: beakTop - beakHeight * (mouth - 0.02)))
ctx.strokePath()
ctx.restoreGState()

// Eyes: small ovals on the sides of the head, ringed pink, with a glint.
for side in [-1.0, 1.0] as [CGFloat] {
    let r = eyeRadius
    ctx.saveGState()
    ctx.translateBy(x: cx + side * eyeX, y: eyeY)
    ctx.rotate(by: side * -eyeTilt)
    ctx.scaleBy(x: 0.8, y: 1)
    ctx.setFillColor(eyeRing)
    ctx.fillEllipse(in: CGRect(x: -r * 1.3, y: -r * 1.3, width: r * 2.6, height: r * 2.6))
    ctx.setFillColor(eyeBlack)
    ctx.fillEllipse(in: CGRect(x: -r, y: -r, width: r * 2, height: r * 2))
    ctx.setFillColor(rgb(1, 1, 1, 0.85))
    ctx.fillEllipse(in: CGRect(x: -r * 0.55, y: r * 0.15, width: r * 0.5, height: r * 0.5))
    ctx.restoreGState()
}

let image = ctx.makeImage()!
let url = URL(fileURLWithPath: outDir).appendingPathComponent("icon-1024.png")
let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("could not write \(url.path)") }
print("wrote \(url.path)")
