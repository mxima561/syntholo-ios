#!/usr/bin/env swift

// Renders the Syntholo app icon at 1024x1024 with no alpha channel, as the
// App Store requires. The mark nests the three orientation shapes the welcome
// screen already uses - square, diamond, circle - so the icon and the first
// screen a learner sees share one motif.
//
// Usage: swift scripts/generate_app_icon.swift <output.png>

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let side = 1024.0

// Brand palette, matching OnboardingPalette in the app target.
let academicInk = (r: 21.0 / 255.0, g: 34.0 / 255.0, b: 56.0 / 255.0)
let lectureBlue = (r: 46.0 / 255.0, g: 91.0 / 255.0, b: 255.0 / 255.0)
let campusPaper = (r: 247.0 / 255.0, g: 248.0 / 255.0, b: 244.0 / 255.0)

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(
        Data("usage: generate_app_icon.swift <output.png>\n".utf8)
    )
    exit(2)
}
let outputPath = CommandLine.arguments[1]

let colorSpace = CGColorSpaceCreateDeviceRGB()

// No alpha: App Store Connect rejects icons with a transparent channel.
guard let context = CGContext(
    data: nil,
    width: Int(side),
    height: Int(side),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else {
    FileHandle.standardError.write(Data("could not create context\n".utf8))
    exit(1)
}

func color(_ rgb: (r: Double, g: Double, b: Double), _ alpha: Double = 1) -> CGColor {
    CGColor(
        colorSpace: colorSpace,
        components: [rgb.r, rgb.g, rgb.b, alpha]
    )!
}

// Ground: a soft vertical lift keeps the icon from reading as a flat block.
let groundTop = (r: 27.0 / 255.0, g: 46.0 / 255.0, b: 79.0 / 255.0)
let gradient = CGGradient(
    colorsSpace: colorSpace,
    colors: [color(groundTop), color(academicInk)] as CFArray,
    locations: [0, 1]
)!
context.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: side),
    end: CGPoint(x: side, y: 0),
    options: []
)

let center = CGPoint(x: side / 2, y: side / 2)

// Outer square: the "structure" of the motif.
let squareSide = 600.0
let squareStroke = 44.0
let squareRect = CGRect(
    x: center.x - squareSide / 2,
    y: center.y - squareSide / 2,
    width: squareSide,
    height: squareSide
)
let squarePath = CGPath(
    roundedRect: squareRect.insetBy(dx: squareStroke / 2, dy: squareStroke / 2),
    cornerWidth: 104,
    cornerHeight: 104,
    transform: nil
)
context.setStrokeColor(color(campusPaper))
context.setLineWidth(squareStroke)
context.addPath(squarePath)
context.strokePath()

// Middle diamond: the "synthesis" turn.
let diamondDiagonal = 356.0
let half = diamondDiagonal / 2
let diamond = CGMutablePath()
diamond.move(to: CGPoint(x: center.x, y: center.y + half))
diamond.addLine(to: CGPoint(x: center.x + half, y: center.y))
diamond.addLine(to: CGPoint(x: center.x, y: center.y - half))
diamond.addLine(to: CGPoint(x: center.x - half, y: center.y))
diamond.closeSubpath()
context.setFillColor(color(lectureBlue))
context.addPath(diamond)
context.fillPath()

// Inner circle: the focal point, sized to stay visible at 40pt.
context.setFillColor(color(campusPaper))
context.addEllipse(
    in: CGRect(
        x: center.x - 70,
        y: center.y - 70,
        width: 140,
        height: 140
    )
)
context.fillPath()

guard let image = context.makeImage() else {
    FileHandle.standardError.write(Data("could not render image\n".utf8))
    exit(1)
}

let url = URL(fileURLWithPath: outputPath)
guard let destination = CGImageDestinationCreateWithURL(
    url as CFURL,
    UTType.png.identifier as CFString,
    1,
    nil
) else {
    FileHandle.standardError.write(Data("could not open \(outputPath)\n".utf8))
    exit(1)
}
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else {
    FileHandle.standardError.write(Data("could not write \(outputPath)\n".utf8))
    exit(1)
}

print("wrote \(outputPath) (\(Int(side))x\(Int(side)), no alpha)")
