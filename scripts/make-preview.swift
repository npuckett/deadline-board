// Renders docs/widget-preview.png — a medium-widget mockup matching
// DeadlineEntryView with the sample deadlines, at 2x (684x316 for 342x158 pt).
// Run with: swift scripts/make-preview.swift

import AppKit

let width: CGFloat = 684
let height: CGFloat = 316

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(width),
    pixelsHigh: Int(height),
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

// Widget container: dark material look with rounded corners.
let container = NSBezierPath(
    roundedRect: NSRect(x: 0, y: 0, width: width, height: height),
    xRadius: 40,
    yRadius: 40
)
NSColor(calibratedRed: 0.165, green: 0.165, blue: 0.18, alpha: 1).setFill()
container.fill()

let white = NSColor(white: 1, alpha: 0.92)
let secondary = NSColor(white: 1, alpha: 0.55)
let red = NSColor(calibratedRed: 1.0, green: 0.27, blue: 0.23, alpha: 1)
let orange = NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.04, alpha: 1)
let gray = NSColor(white: 0.62, alpha: 1)

func draw(_ text: String, at point: NSPoint, font: NSFont, color: NSColor,
          rightAlignedTo rightEdge: CGFloat? = nil, tracking: CGFloat = 0) {
    var attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
    if tracking > 0 { attributes[.kern] = tracking }
    let string = NSAttributedString(string: text, attributes: attributes)
    var origin = point
    if let rightEdge {
        origin.x = rightEdge - string.size().width
    }
    string.draw(at: origin)
}

// Header, top-left (AppKit origin is bottom-left).
draw("DEADLINES", at: NSPoint(x: 44, y: height - 62),
     font: .systemFont(ofSize: 21, weight: .semibold), color: secondary, tracking: 2.4)

// Rows: (title, date, countdown, color), soonest first — matches Deadline.samples().
let rows: [(String, String, String, NSColor)] = [
    ("CHI paper submission", "Tue 25 Aug", "0d 9h", red),
    ("Grant report draft", "Fri 28 Aug", "3d 5h", orange),
    ("Ars Electronica open call", "Sun 6 Sep", "12d 4h", gray),
]

let titleFont = NSFont.systemFont(ofSize: 27, weight: .medium)
let captionFont = NSFont.systemFont(ofSize: 21, weight: .regular)
let countdownFont = NSFont.monospacedDigitSystemFont(ofSize: 27, weight: .semibold)

for (index, row) in rows.enumerated() {
    let rowTop = height - 96 - CGFloat(index) * 72
    let (title, date, countdown, color) = row

    color.setFill()
    NSBezierPath(ovalIn: NSRect(x: 44, y: rowTop - 22, width: 13, height: 13)).fill()

    draw(title, at: NSPoint(x: 76, y: rowTop - 32), font: titleFont, color: white)
    draw(date, at: NSPoint(x: 76, y: rowTop - 58), font: captionFont, color: secondary)
    draw(countdown, at: NSPoint(x: 0, y: rowTop - 32), font: countdownFont,
         color: color, rightAlignedTo: width - 44)
}

NSGraphicsContext.restoreGraphicsState()

try! FileManager.default.createDirectory(atPath: "docs", withIntermediateDirectories: true)
let data = rep.representation(using: .png, properties: [:])!
try! data.write(to: URL(fileURLWithPath: "docs/widget-preview.png"))
print("wrote docs/widget-preview.png")
