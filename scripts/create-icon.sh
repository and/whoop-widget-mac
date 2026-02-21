#!/bin/bash
set -euo pipefail

# Generate AppIcon.icns programmatically using Swift and CoreGraphics
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RESOURCES_DIR="$PROJECT_DIR/Resources"
ICONSET_DIR="$RESOURCES_DIR/AppIcon.iconset"

mkdir -p "$ICONSET_DIR"

# Swift script to generate icon PNGs
cat > /tmp/generate_icon.swift << 'SWIFT_EOF'
import AppKit
import CoreGraphics

func createHeartIcon(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let s = CGFloat(size)
    let rect = CGRect(x: 0, y: 0, width: s, height: s)

    // Red gradient rounded rectangle background
    let cornerRadius = s * 0.2
    let bgPath = CGPath(roundedRect: rect.insetBy(dx: s * 0.02, dy: s * 0.02),
                        cornerWidth: cornerRadius, cornerHeight: cornerRadius,
                        transform: nil)

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradientColors = [
        CGColor(colorSpace: colorSpace, components: [0.9, 0.1, 0.15, 1.0])!,
        CGColor(colorSpace: colorSpace, components: [0.7, 0.05, 0.1, 1.0])!
    ] as CFArray
    let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: [0.0, 1.0])!

    context.saveGState()
    context.addPath(bgPath)
    context.clip()
    context.drawLinearGradient(gradient,
                               start: CGPoint(x: 0, y: s),
                               end: CGPoint(x: 0, y: 0),
                               options: [])
    context.restoreGState()

    // White heart symbol
    let heartSize = s * 0.55
    let heartX = (s - heartSize) / 2
    let heartY = (s - heartSize) / 2 - s * 0.02

    let heartPath = CGMutablePath()
    let cx = heartX + heartSize / 2
    let top = heartY + heartSize * 0.75
    let bottom = heartY + heartSize * 0.1

    // Left bump
    heartPath.move(to: CGPoint(x: cx, y: bottom))
    heartPath.addCurve(to: CGPoint(x: heartX, y: top),
                       control1: CGPoint(x: cx - heartSize * 0.05, y: heartY + heartSize * 0.25),
                       control2: CGPoint(x: heartX, y: heartY + heartSize * 0.45))
    heartPath.addCurve(to: CGPoint(x: cx, y: heartY + heartSize * 0.55),
                       control1: CGPoint(x: heartX, y: top + heartSize * 0.15),
                       control2: CGPoint(x: cx - heartSize * 0.15, y: top + heartSize * 0.1))

    // Right bump
    heartPath.addCurve(to: CGPoint(x: heartX + heartSize, y: top),
                       control1: CGPoint(x: cx + heartSize * 0.15, y: top + heartSize * 0.1),
                       control2: CGPoint(x: heartX + heartSize, y: top + heartSize * 0.15))
    heartPath.addCurve(to: CGPoint(x: cx, y: bottom),
                       control1: CGPoint(x: heartX + heartSize, y: heartY + heartSize * 0.45),
                       control2: CGPoint(x: cx + heartSize * 0.05, y: heartY + heartSize * 0.25))

    context.setFillColor(CGColor(colorSpace: colorSpace, components: [1, 1, 1, 0.95])!)
    context.addPath(heartPath)
    context.fillPath()

    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, to path: String) {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG for \(path)")
        return
    }
    do {
        try pngData.write(to: URL(fileURLWithPath: path))
    } catch {
        print("Failed to write \(path): \(error)")
    }
}

let iconsetDir = CommandLine.arguments[1]
let sizes: [(name: String, size: Int)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024),
]

for entry in sizes {
    let image = createHeartIcon(size: entry.size)
    let path = "\(iconsetDir)/\(entry.name).png"
    savePNG(image, to: path)
    print("Generated \(entry.name).png (\(entry.size)x\(entry.size))")
}
SWIFT_EOF

echo "Generating icon images..."
swiftc -o /tmp/generate_icon /tmp/generate_icon.swift -framework AppKit -framework CoreGraphics
/tmp/generate_icon "$ICONSET_DIR"

echo "Creating AppIcon.icns..."
iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"

# Clean up
rm -rf "$ICONSET_DIR"
rm -f /tmp/generate_icon /tmp/generate_icon.swift

echo "Done! AppIcon.icns created at $RESOURCES_DIR/AppIcon.icns"
