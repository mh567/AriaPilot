import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconsetURL = root.appendingPathComponent("assets/AppIcon.iconset", isDirectory: true)

try? FileManager.default.removeItem(at: iconsetURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

struct IconItem { let name: String; let pixels: CGFloat }
let items = [
    IconItem(name: "icon_16x16.png", pixels: 16),
    IconItem(name: "icon_16x16@2x.png", pixels: 32),
    IconItem(name: "icon_32x32.png", pixels: 32),
    IconItem(name: "icon_32x32@2x.png", pixels: 64),
    IconItem(name: "icon_128x128.png", pixels: 128),
    IconItem(name: "icon_128x128@2x.png", pixels: 256),
    IconItem(name: "icon_256x256.png", pixels: 256),
    IconItem(name: "icon_256x256@2x.png", pixels: 512),
    IconItem(name: "icon_512x512.png", pixels: 512),
    IconItem(name: "icon_512x512@2x.png", pixels: 1024)
]

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let scale = size / 1024
    func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect { NSRect(x: x * scale, y: y * scale, width: w * scale, height: h * scale) }
    func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: x * scale, y: y * scale) }

    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()
    let bg = NSBezierPath(roundedRect: r(72, 72, 880, 880), xRadius: 220 * scale, yRadius: 220 * scale)
    NSGraphicsContext.saveGraphicsState()
    bg.addClip()

    NSGradient(colorsAndLocations:
        (NSColor(calibratedRed: 0.04, green: 0.23, blue: 0.68, alpha: 1), 0.0),
        (NSColor(calibratedRed: 0.02, green: 0.55, blue: 0.78, alpha: 1), 0.52),
        (NSColor(calibratedRed: 0.23, green: 0.88, blue: 0.74, alpha: 1), 1.0)
    )?.draw(in: bg, angle: 38)
    NSGradient(colors: [NSColor(calibratedWhite: 1, alpha: 0.30), NSColor(calibratedWhite: 1, alpha: 0.00)])?.draw(in: r(118, 590, 650, 360), angle: 265)

    let center = p(512, 512)
    let ring = NSBezierPath()
    ring.appendArc(withCenter: center, radius: 345 * scale, startAngle: 20, endAngle: 342, clockwise: false)
    NSColor(calibratedWhite: 1, alpha: 0.24).setStroke()
    ring.lineWidth = 34 * scale
    ring.lineCapStyle = .round
    ring.stroke()

    let inner = NSBezierPath()
    inner.appendArc(withCenter: center, radius: 258 * scale, startAngle: 202, endAngle: 336, clockwise: false)
    NSColor(calibratedWhite: 1, alpha: 0.16).setStroke()
    inner.lineWidth = 22 * scale
    inner.lineCapStyle = .round
    inner.stroke()

    let shadow = NSBezierPath()
    shadow.move(to: p(512, 238)); shadow.line(to: p(322, 454))
    shadow.curve(to: p(443, 436), controlPoint1: p(366, 444), controlPoint2: p(404, 438))
    shadow.line(to: p(443, 733)); shadow.curve(to: p(581, 733), controlPoint1: p(443, 775), controlPoint2: p(581, 775))
    shadow.line(to: p(581, 436)); shadow.curve(to: p(702, 454), controlPoint1: p(620, 438), controlPoint2: p(658, 444)); shadow.close()
    NSColor(calibratedRed: 0, green: 0.10, blue: 0.25, alpha: 0.24).setFill()
    let moveDown = AffineTransform(translationByX: 0, byY: -22 * scale)
    shadow.transform(using: moveDown)
    shadow.fill()

    let arrow = NSBezierPath()
    arrow.move(to: p(512, 270)); arrow.line(to: p(330, 476))
    arrow.curve(to: p(456, 455), controlPoint1: p(376, 463), controlPoint2: p(415, 456))
    arrow.line(to: p(456, 725)); arrow.curve(to: p(568, 725), controlPoint1: p(456, 760), controlPoint2: p(568, 760))
    arrow.line(to: p(568, 455)); arrow.curve(to: p(694, 476), controlPoint1: p(609, 456), controlPoint2: p(648, 463)); arrow.close()
    NSGradient(colorsAndLocations: (NSColor.white, 0.0), (NSColor(calibratedRed: 0.78, green: 0.96, blue: 1.0, alpha: 1), 1.0))?.draw(in: arrow, angle: 90)
    NSColor(calibratedWhite: 1, alpha: 0.62).setStroke()
    arrow.lineWidth = 10 * scale
    arrow.stroke()

    NSColor(calibratedWhite: 1, alpha: 0.86).setFill()
    for point in [p(315, 624), p(707, 624), p(512, 818)] {
        NSBezierPath(ovalIn: NSRect(x: point.x - 22 * scale, y: point.y - 22 * scale, width: 44 * scale, height: 44 * scale)).fill()
    }
    NSGraphicsContext.restoreGraphicsState()
    NSColor(calibratedWhite: 1, alpha: 0.35).setStroke()
    bg.lineWidth = 8 * scale
    bg.stroke()
    image.unlockFocus()
    return image
}

for item in items {
    let image = drawIcon(size: item.pixels)
    guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "AriaPilotIcon", code: 1)
    }
    try png.write(to: iconsetURL.appendingPathComponent(item.name))
}
