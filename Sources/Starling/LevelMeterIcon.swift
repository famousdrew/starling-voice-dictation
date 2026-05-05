import AppKit

/// Draws a 5-bar level meter as an NSImage for the menubar.
///
/// Bars light up cumulatively based on `level` (0...1). Heights are staggered
/// (short → tall) so the icon reads as a level meter even at a glance, the way
/// audio meters look in QuickTime / Voice Memos.
enum LevelMeterIcon {
    static func image(level: Float, tint: NSColor) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        let bars = 5
        let spacing: CGFloat = 1.5
        let totalSpacing = CGFloat(bars - 1) * spacing
        let barWidth = (size.width - totalSpacing) / CGFloat(bars)

        // Heights peak in the middle so it reads as a waveform shape.
        let heights: [CGFloat] = [0.35, 0.65, 1.0, 0.65, 0.35]

        let dim = tint.withAlphaComponent(0.22)
        let level = max(0, min(1, CGFloat(level)))

        for i in 0..<bars {
            let h = size.height * heights[i]
            let x = CGFloat(i) * (barWidth + spacing)
            let y = (size.height - h) / 2
            let rect = NSRect(x: x, y: y, width: barWidth, height: h)
            let path = NSBezierPath(roundedRect: rect, xRadius: 1, yRadius: 1)

            // Bar i lights up once `level` exceeds (i+1)/bars * 0.65 — the bias
            // keeps the meter responsive at typical speech amplitudes.
            let threshold = CGFloat(i + 1) / CGFloat(bars) * 0.65
            (level >= threshold ? tint : dim).setFill()
            path.fill()
        }

        image.isTemplate = false
        return image
    }
}
