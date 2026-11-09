import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Same profile and smoothing as VesselShape in the app (the site's "round jug").
let profile: [(Double, Double)] = [(0, 0.40), (0.40, 0.96), (0.70, 0.80), (0.88, 0.28), (1, 0.32)]
func monotone(_ pts: [(Double, Double)]) -> (Double) -> Double {
    let xs = pts.map(\.0), ys = pts.map(\.1), n = pts.count
    var d: [Double] = []; for i in 0..<(n-1) { d.append((ys[i+1]-ys[i])/(xs[i+1]-xs[i])) }
    var m = [Double](repeating: 0, count: n); m[0] = d[0]; m[n-1] = d[n-2]
    for i in 1..<(n-1) { m[i] = d[i-1]*d[i] <= 0 ? 0 : (d[i-1]+d[i])/2 }
    for i in 0..<(n-1) { if d[i] == 0 { m[i] = 0; m[i+1] = 0; continue }
        let a = m[i]/d[i], b = m[i+1]/d[i], t = a*a+b*b
        if t > 9 { let k = 3/t.squareRoot(); m[i] = k*a*d[i]; m[i+1] = k*b*d[i] } }
    return { y in var j = 0; while j < n-2 && y > xs[j+1] { j += 1 }
        let h = xs[j+1]-xs[j], u = (y-xs[j])/h, u2 = u*u, u3 = u2*u
        return (2*u3-3*u2+1)*ys[j] + (u3-2*u2+u)*h*m[j] + (-2*u3+3*u2)*ys[j+1] + (u3-u2)*h*m[j+1] }
}
func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex>>16)&0xFF)/255, green: CGFloat((hex>>8)&0xFF)/255, blue: CGFloat(hex&0xFF)/255, alpha: a)
}

func draw(bg: UInt32, line: UInt32, glowCore: UInt32, glowHalo: UInt32, haloAlpha: CGFloat, out: String) {
    let S = 1024
    let ctx = CGContext(data: nil, width: S, height: S, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    // Flip so y grows downward, like the app.
    ctx.translateBy(x: 0, y: CGFloat(S)); ctx.scaleBy(x: 1, y: -1)
    ctx.setFillColor(rgb(bg)); ctx.fill(CGRect(x: 0, y: 0, width: S, height: S))

    let r = monotone(profile)
    let height = 560.0, maxR = 214.0, cx = 512.0
    let bottom = 512.0 + height / 2 + 6   // optically centered: the belly is low, so nudge down a touch
    let heart = bottom - 0.42 * height

    // The light: a soft halo, then a small bright core.
    let halo = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [rgb(glowHalo, haloAlpha), rgb(glowHalo, haloAlpha * 0.35), rgb(glowHalo, 0)] as CFArray, locations: [0, 0.45, 1])!
    ctx.drawRadialGradient(halo, startCenter: CGPoint(x: cx, y: heart), startRadius: 0, endCenter: CGPoint(x: cx, y: heart), endRadius: 230, options: [])
    let core = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [rgb(glowCore), rgb(glowCore), rgb(glowCore, 0)] as CFArray, locations: [0, 0.62, 1])!
    ctx.drawRadialGradient(core, startCenter: CGPoint(x: cx, y: heart), startRadius: 0, endCenter: CGPoint(x: cx, y: heart), endRadius: 66, options: [])

    // The jar, mouth open.
    let path = CGMutablePath(); let steps = 160
    for i in stride(from: steps, through: 0, by: -1) {
        let y = Double(i) / Double(steps); let p = CGPoint(x: cx - r(y) * maxR, y: bottom - y * height)
        if i == steps { path.move(to: p) } else { path.addLine(to: p) }
    }
    for i in 0...steps { let y = Double(i) / Double(steps); path.addLine(to: CGPoint(x: cx + r(y) * maxR, y: bottom - y * height)) }
    ctx.addPath(path); ctx.setStrokeColor(rgb(line)); ctx.setLineWidth(22); ctx.setLineCap(.round); ctx.setLineJoin(.round); ctx.strokePath()

    let img = ctx.makeImage()!
    let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil); CGImageDestinationFinalize(dest)
}

let outDir = CommandLine.arguments[1]
draw(bg: 0x141413, line: 0xFAF9F5, glowCore: 0xF6D27A, glowHalo: 0xE9B44C, haloAlpha: 0.7, out: outDir + "/AppIcon-Black.png")
draw(bg: 0xFAF9F5, line: 0x141413, glowCore: 0xEDB84E, glowHalo: 0xE9B44C, haloAlpha: 0.45, out: outDir + "/AppIcon-Cream.png")
print("ok")
