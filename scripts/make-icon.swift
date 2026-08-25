// Renders the app icon: a dark squircle holding three list rows with
// urgency dots, echoing the widget layout. Run with:
//   swift scripts/make-icon.swift
// Writes PNGs into DeadlinesApp/Assets.xcassets/AppIcon.appiconset/.

import AppKit

let outputDir = "DeadlinesApp/Assets.xcassets/AppIcon.appiconset"

func drawIcon(size: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size),
        pixelsHigh: Int(size),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let s = size

    // Apple macOS icon grid: squircle inset ~100/1024 with radius ~185/1024.
    let squircle = NSBezierPath(
        roundedRect: NSRect(x: 0.0977 * s, y: 0.0977 * s, width: 0.8046 * s, height: 0.8046 * s),
        xRadius: 0.1807 * s,
        yRadius: 0.1807 * s
    )
    let gradient = NSGradient(
        starting: NSColor(calibratedRed: 0.16, green: 0.17, blue: 0.20, alpha: 1),
        ending: NSColor(calibratedRed: 0.09, green: 0.10, blue: 0.12, alpha: 1)
    )!
    gradient.draw(in: squircle, angle: -90)

    // Three rows: urgency dot + bar, soonest (red) on top.
    let dotColors = [
        NSColor(calibratedRed: 0.96, green: 0.26, blue: 0.21, alpha: 1),   // critical
        NSColor(calibratedRed: 1.00, green: 0.58, blue: 0.00, alpha: 1),   // soon
        NSColor(white: 0.62, alpha: 1),                                    // calm
    ]
    let barWidths: [CGFloat] = [0.40, 0.34, 0.26]
    let rowYs: [CGFloat] = [0.635, 0.465, 0.295]   // from bottom, top row first
    let dotRadius = 0.048 * s
    let barHeight = 0.075 * s

    for row in 0..<3 {
        let centerY = rowYs[row] * s
        dotColors[row].setFill()
        NSBezierPath(ovalIn: NSRect(
            x: 0.235 * s - dotRadius,
            y: centerY - dotRadius,
            width: dotRadius * 2,
            height: dotRadius * 2
        )).fill()

        NSColor(white: 1, alpha: 0.92).setFill()
        NSBezierPath(
            roundedRect: NSRect(
                x: 0.335 * s,
                y: centerY - barHeight / 2,
                width: barWidths[row] * s,
                height: barHeight
            ),
            xRadius: barHeight / 2,
            yRadius: barHeight / 2
        ).fill()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let sizes: [(name: String, pixels: CGFloat)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for (name, pixels) in sizes {
    let rep = drawIcon(size: pixels)
    let data = rep.representation(using: .png, properties: [:])!
    let url = URL(fileURLWithPath: "\(outputDir)/\(name).png")
    try! data.write(to: url)
    print("wrote \(url.path)")
}
