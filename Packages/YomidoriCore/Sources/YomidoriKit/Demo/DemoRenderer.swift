import CoreGraphics
import CoreText
import Foundation

/// Pages and covers drawn from text, so the demo has something to read without a camera:
/// vertical Mincho on cream for a novel's page, a bold horizontal sign, a cover with a title.
enum DemoRenderer {
    static func verticalPage(_ text: String, size: CGSize = CGSize(width: 1500, height: 2000))
        -> CGImage?
    {
        let paper = CGColor(red: 0.96, green: 0.94, blue: 0.88, alpha: 1)
        return draw(size: size, background: paper) { context in
            let font = CTFontCreateWithName("HiraMinProN-W3" as CFString, 56, nil)
            let attributed = NSAttributedString(
                string: text,
                attributes: attributes(font: font, gray: 0.12, vertical: true, lineSpacing: 30))
            let frame = CTFramesetterCreateFrame(
                CTFramesetterCreateWithAttributedString(attributed), CFRange(),
                CGPath(
                    rect: CGRect(
                        x: 140, y: 160, width: size.width - 280, height: size.height - 320),
                    transform: nil),
                [kCTFrameProgressionAttributeName: CTFrameProgression.rightToLeft.rawValue]
                    as CFDictionary)
            CTFrameDraw(frame, context)
        }
    }

    static func sign(_ text: String, size: CGSize = CGSize(width: 1600, height: 900)) -> CGImage? {
        let red = CGColor(red: 0.72, green: 0.1, blue: 0.12, alpha: 1)
        return draw(size: size, background: red) { context in
            let font = CTFontCreateWithName("HiraginoSans-W7" as CFString, 120, nil)
            let attributed = NSAttributedString(
                string: text,
                attributes: attributes(font: font, gray: 1, vertical: false, lineSpacing: 40))
            let frame = CTFramesetterCreateFrame(
                CTFramesetterCreateWithAttributedString(attributed), CFRange(),
                CGPath(
                    rect: CGRect(
                        x: 120, y: 120, width: size.width - 240, height: size.height - 240),
                    transform: nil),
                nil)
            CTFrameDraw(frame, context)
        }
    }

    static func cover(_ title: String, author: String, hue: CGColor) -> CGImage? {
        let size = CGSize(width: 600, height: 840)
        return draw(size: size, background: hue) { context in
            let titleFont = CTFontCreateWithName("HiraMinProN-W6" as CFString, 72, nil)
            let attributed = NSAttributedString(
                string: title,
                attributes: attributes(font: titleFont, gray: 0.98, vertical: true, lineSpacing: 0))
            let frame = CTFramesetterCreateFrame(
                CTFramesetterCreateWithAttributedString(attributed), CFRange(),
                CGPath(rect: CGRect(x: 380, y: 120, width: 120, height: 640), transform: nil),
                [kCTFrameProgressionAttributeName: CTFrameProgression.rightToLeft.rawValue]
                    as CFDictionary)
            CTFrameDraw(frame, context)
            let authorFont = CTFontCreateWithName("HiraMinProN-W3" as CFString, 36, nil)
            let by = NSAttributedString(
                string: author,
                attributes: attributes(
                    font: authorFont, gray: 0.95, vertical: false, lineSpacing: 0))
            let line = CTLineCreateWithAttributedString(by)
            context.textPosition = CGPoint(x: 80, y: 90)
            CTLineDraw(line, context)
        }
    }

    /// CoreText's own keys, so the string draws the same on every platform.
    private static func attributes(
        font: CTFont, gray: CGFloat, vertical: Bool, lineSpacing: CGFloat
    ) -> [NSAttributedString.Key: Any] {
        var spacing = lineSpacing
        let setting = withUnsafeMutablePointer(to: &spacing) { pointer in
            CTParagraphStyleSetting(
                spec: .lineSpacingAdjustment, valueSize: MemoryLayout<CGFloat>.size, value: pointer)
        }
        let style = CTParagraphStyleCreate([setting], 1)
        return [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(
                gray: gray, alpha: 1),
            NSAttributedString.Key(kCTVerticalFormsAttributeName as String): vertical,
            NSAttributedString.Key(kCTParagraphStyleAttributeName as String): style,
        ]
    }

    private static func draw(size: CGSize, background: CGColor, _ body: (CGContext) -> Void)
        -> CGImage?
    {
        guard
            let context = CGContext(
                data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return nil }
        context.setFillColor(background)
        context.fill(CGRect(origin: .zero, size: size))
        context.textMatrix = .identity
        body(context)
        return context.makeImage()
    }
}
