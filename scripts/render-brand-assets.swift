import CoreGraphics
import CoreText
import Foundation
import ImageIO

// Renders the Allotment brand assets: AppIcon.png (1024px) and the
// LaunchLockup imageset PNGs. Run: swift scripts/render-brand-assets.swift

let ink = CGColor(red: 0.18, green: 0.16, blue: 0.29, alpha: 1)
let paper = CGColor(red: 1.0, green: 0.99, blue: 0.97, alpha: 1)
let leafGreen = CGColor(red: 0.38, green: 0.76, blue: 0.62, alpha: 1)
let mauve = CGColor(red: 0.776, green: 0.627, blue: 0.965, alpha: 1)

// Design space is 1000x1000 units, y measured from the top; scale maps it
// to the target pixel size. Callers that draw into a bottom-up CGContext
// should flip the CTM first (see makeFlipped).
func drawSprout(_ ctx: CGContext, silhouette: Bool, scale: CGFloat) {
    // Soil band: rounded mauve bar with ink outline.
    let soil = CGRect(x: 112 * scale, y: 600 * scale, width: 776 * scale, height: 96 * scale)
    let soilPath = CGPath(roundedRect: soil, cornerWidth: 48 * scale, cornerHeight: 48 * scale, transform: nil)

    // Stem.
    let stem = CGMutablePath()
    stem.move(to: CGPoint(x: 500 * scale, y: 636 * scale))
    stem.addQuadCurve(to: CGPoint(x: 500 * scale, y: 360 * scale), control: CGPoint(x: 512 * scale, y: 500 * scale))

    // Two leaves: mirrored quad-curve teardrops meeting at the stem.
    func leaf(tipX: CGFloat, tipY: CGFloat, control1: CGPoint, control2: CGPoint) -> CGMutablePath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 500 * scale, y: 420 * scale))
        p.addQuadCurve(to: CGPoint(x: tipX * scale, y: tipY * scale), control: control1)
        p.addQuadCurve(to: CGPoint(x: 500 * scale, y: 420 * scale), control: control2)
        p.closeSubpath()
        return p
    }
    let leftLeaf = leaf(tipX: 300, tipY: 250,
                        control1: CGPoint(x: 340 * scale, y: 350 * scale),
                        control2: CGPoint(x: 380 * scale, y: 200 * scale))
    let rightLeaf = leaf(tipX: 700, tipY: 250,
                         control1: CGPoint(x: 660 * scale, y: 350 * scale),
                         control2: CGPoint(x: 620 * scale, y: 200 * scale))

    if silhouette {
        ctx.setFillColor(ink)
        ctx.setStrokeColor(ink)
    } else {
        ctx.setFillColor(mauve)
        ctx.setStrokeColor(ink)
    }
    ctx.setLineWidth(22 * scale)
    ctx.setLineCap(.round)

    ctx.addPath(soilPath)
    ctx.fillPath()
    ctx.addPath(soilPath)
    ctx.strokePath()

    ctx.setFillColor(silhouette ? ink : leafGreen)
    ctx.addPath(leftLeaf)
    ctx.fillPath()
    ctx.addPath(leftLeaf)
    ctx.strokePath()
    ctx.addPath(rightLeaf)
    ctx.fillPath()
    ctx.addPath(rightLeaf)
    ctx.strokePath()

    ctx.addPath(stem)
    ctx.strokePath()
}

func makeFlipped(width: Int, height: Int) -> CGContext {
    let space = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(data: nil, width: width, height: height,
                        bitsPerComponent: 8, bytesPerRow: 0, space: space,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.translateBy(x: 0, y: CGFloat(height))
    ctx.scaleBy(x: 1, y: -1)
    return ctx
}

func savePNG(_ image: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path) as CFURL
    let dest = CGImageDestinationCreateWithURL(url, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    precondition(CGImageDestinationFinalize(dest), "failed to write \(path)")
}

// App icon: 1024x1024, paper background, offset ink shadow behind the sprout.
let iconSize = 1024
let ctx = makeFlipped(width: iconSize, height: iconSize)
ctx.setFillColor(paper)
ctx.fill(CGRect(x: 0, y: 0, width: iconSize, height: iconSize))
let iconScale = CGFloat(iconSize) / 1000.0
ctx.translateBy(x: 0, y: 50)
ctx.saveGState()
ctx.translateBy(x: 16, y: 18)
drawSprout(ctx, silhouette: true, scale: iconScale)
ctx.restoreGState()
drawSprout(ctx, silhouette: false, scale: iconScale)
savePNG(ctx.makeImage()!, to: "Allotment/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
print("wrote AppIcon.png")
