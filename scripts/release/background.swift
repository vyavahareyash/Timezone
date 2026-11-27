// Renders the DMG window background: scripts/release/background.svg plus its text, as one TIFF at 1x and 2x.
// Usage: swift scripts/release/background.swift <background.svg> <out.tiff>
// The SVG renderer ignores fonts, so the text is drawn here in the system font.
import AppKit

let size = NSSize(width: 660, height: 400)
let lines: [(text: String, size: CGFloat, weight: NSFont.Weight, gray: CGFloat, baseline: CGFloat)] = [
    ("Drag Timezone into Applications", 21, .semibold, 0.114, 66),
    ("It lives in your menu bar, not the Dock.", 13.5, .regular, 0.43, 92),
    ("First launch only", 12.5, .semibold, 0.227, 346),
    ("macOS stops it once. Click Done, then System Settings › Privacy & Security › Open Anyway.", 12.5, .regular, 0.43, 366),
]

let args = CommandLine.arguments
guard args.count == 3, let art = NSImage(contentsOf: URL(fileURLWithPath: args[1])) else {
    FileHandle.standardError.write("usage: swift background.swift <background.svg> <out.tiff>\n".data(using: .utf8)!)
    exit(64)
}

func render(scale: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width) * scale, pixelsHigh: Int(size.height) * scale,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size  // points: the context then draws in points, and Finder shows the 2x rep at the same size on Retina
    let cg = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    cg.scaleBy(x: 1, y: -1)  // top-left origin, like the SVG
    cg.translateBy(x: 0, y: -size.height)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
    art.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .copy, fraction: 1, respectFlipped: true, hints: nil)
    for line in lines {
        let font = NSFont.systemFont(ofSize: line.size, weight: line.weight)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor(white: line.gray, alpha: 1)]
        let width = (line.text as NSString).size(withAttributes: attributes).width
        // draw(at:) takes the top-left of the line box in a flipped context; the baseline sits one ascender below it.
        (line.text as NSString).draw(at: NSPoint(x: (size.width - width) / 2, y: line.baseline - font.ascender), withAttributes: attributes)
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let image = NSImage(size: size)
image.addRepresentation(render(scale: 1))
image.addRepresentation(render(scale: 2))
guard let tiff = image.tiffRepresentation(using: .lzw, factor: 0) else { exit(1) }
try tiff.write(to: URL(fileURLWithPath: args[2]))
