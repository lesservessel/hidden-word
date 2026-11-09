import SwiftUI

/// A jar of clay, drawn the way lesservessel.com draws its jars: a radius profile from
/// bottom (0) to lip (1), smoothed with monotone cubic interpolation so the walls never bulge.
struct VesselShape: Shape {
    /// (height 0...1, radius 0...1) control points. The default is the site's "round jug".
    var profile: [(CGFloat, CGFloat)] = VesselShape.roundJug

    static let roundJug: [(CGFloat, CGFloat)] = [(0, 0.40), (0.40, 0.96), (0.70, 0.80), (0.88, 0.28), (1, 0.32)]

    func path(in rect: CGRect) -> Path {
        let r = MonotoneCubic(points: profile)
        let maxR = rect.width / 2
        let cx = rect.midX
        let steps = 90
        var path = Path()
        // Left wall from lip down, across the base, right wall back up. The mouth stays open.
        for i in stride(from: steps, through: 0, by: -1) {
            let y = CGFloat(i) / CGFloat(steps)
            let point = CGPoint(x: cx - r(y) * maxR, y: rect.maxY - y * rect.height)
            if i == steps { path.move(to: point) } else { path.addLine(to: point) }
        }
        for i in 0...steps {
            let y = CGFloat(i) / CGFloat(steps)
            path.addLine(to: CGPoint(x: cx + r(y) * maxR, y: rect.maxY - y * rect.height))
        }
        return path
    }

    /// Where the light sits: the widest part of the belly, as a fraction of height from the bottom.
    static let heartHeight: CGFloat = 0.42
}

/// Fritsch–Carlson monotone cubic, the same smoothing the site uses.
struct MonotoneCubic {
    private let xs: [CGFloat]
    private let ys: [CGFloat]
    private let m: [CGFloat]

    init(points: [(CGFloat, CGFloat)]) {
        xs = points.map(\.0)
        ys = points.map(\.1)
        let n = points.count
        var d: [CGFloat] = []
        for i in 0..<(n - 1) { d.append((ys[i + 1] - ys[i]) / (xs[i + 1] - xs[i])) }
        var m = [CGFloat](repeating: 0, count: n)
        m[0] = d[0]
        m[n - 1] = d[n - 2]
        if n > 2 {
            for i in 1..<(n - 1) { m[i] = d[i - 1] * d[i] <= 0 ? 0 : (d[i - 1] + d[i]) / 2 }
        }
        for i in 0..<(n - 1) {
            if d[i] == 0 { m[i] = 0; m[i + 1] = 0; continue }
            let a = m[i] / d[i], b = m[i + 1] / d[i], t = a * a + b * b
            if t > 9 {
                let k = 3 / t.squareRoot()
                m[i] = k * a * d[i]
                m[i + 1] = k * b * d[i]
            }
        }
        self.m = m
    }

    func callAsFunction(_ y: CGFloat) -> CGFloat {
        var j = 0
        while j < xs.count - 2 && y > xs[j + 1] { j += 1 }
        let h = xs[j + 1] - xs[j]
        let u = (y - xs[j]) / h, u2 = u * u, u3 = u2 * u
        return (2 * u3 - 3 * u2 + 1) * ys[j] + (u3 - 2 * u2 + u) * h * m[j]
            + (-2 * u3 + 3 * u2) * ys[j + 1] + (u3 - u2) * h * m[j + 1]
    }
}

/// The vessel with its light. `brightness` 0...1 lets a finished session fill it.
struct VesselMark: View {
    var size: CGFloat = 120
    var brightness: Double = 0.75
    var breathing = true
    var lineWidth: CGFloat = 1.25

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var inhale = false

    var body: some View {
        let width = size * 0.78
        ZStack {
            // Halo first, so the clay line sits over it.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.glow.opacity(0.55 * brightness), Color.glow.opacity(0)],
                        center: .center, startRadius: 0, endRadius: size * 0.34
                    )
                )
                .frame(width: size * 0.7, height: size * 0.7)
                .scaleEffect(inhale ? 1.08 : 0.94)
                .offset(y: size * (0.5 - VesselShape.heartHeight) - size * 0.02)

            Circle()
                .fill(Color.glow)
                .frame(width: size * 0.13, height: size * 0.13)
                .opacity(0.55 + 0.45 * brightness)
                .shadow(color: Color.glow.opacity(0.8 * brightness), radius: size * 0.06)
                .offset(y: size * (0.5 - VesselShape.heartHeight) - size * 0.02)

            VesselShape()
                .stroke(Color.ink, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .frame(width: width, height: size * 0.92)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
        .onAppear {
            guard breathing, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.6).repeatForever(autoreverses: true)) { inhale = true }
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        VesselMark(size: 160)
        VesselMark(size: 80, brightness: 1)
    }
    .padding()
    .background(PaperBackground())
}
