import SwiftUI
import UIKit

// The lesservessel look: warm paper, near-black ink, Cormorant Garamond for the Word,
// small spaced capitals in Inter for everything that only points at it.

// MARK: - Colors

extension Color {
    /// Warm cream paper (#faf9f5) by day, ink (#141413) by night.
    static let paper = Color(light: 0xFAF9F5, dark: 0x141413)
    /// Near-black ink by day, paper by night.
    static let ink = Color(light: 0x141413, dark: 0xFAF9F5)
    /// Quiet text: references, hints, captions.
    static let muted = Color(light: 0x5E5D59, dark: 0xB0AEA5)
    /// Hairlines and outlines.
    static let hairline = Color(light: 0xB0AEA5, dark: 0x5E5D59)
    /// The faintest wash, for fields and cards.
    static let wash = Color(light: 0x141413, dark: 0xFAF9F5).opacity(0.025)
    /// The light inside the vessel.
    static let glow = Color(light: 0xE9B44C, dark: 0xF4CD6A)

    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

// MARK: - Type

extension Font {
    /// Cormorant Garamond: titles and the words of Scripture.
    static func serif(_ size: CGFloat, relativeTo style: Font.TextStyle = .body, weight: Font.Weight = .regular) -> Font {
        .custom("Cormorant Garamond", size: size, relativeTo: style).weight(weight)
    }

    static func serifItalic(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Cormorant Garamond", size: size, relativeTo: style).italic()
    }

    /// Inter: small labels, buttons, hints.
    static func sans(_ size: CGFloat, relativeTo style: Font.TextStyle = .footnote, weight: Font.Weight = .regular) -> Font {
        .custom("Inter", size: size, relativeTo: style).weight(weight)
    }

    /// The verse itself, sized to be read aloud from.
    static let verse = Font.serif(26, relativeTo: .title2)
}

/// Spaced capitals, the site's eyebrow and nav style.
struct Eyebrow: View {
    let text: String
    var color: Color = .muted

    init(_ text: String, color: Color = .muted) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text.uppercased())
            .font(.sans(11, relativeTo: .caption2, weight: .medium))
            .tracking(2.6)
            .foregroundStyle(color)
    }
}

/// A short centered hairline, the site's section rule.
struct Rule: View {
    var width: CGFloat = 48
    var body: some View {
        Rectangle().fill(Color.hairline).frame(width: width, height: 1)
    }
}

// MARK: - Buttons

/// The site's pill button: hairline capsule, spaced capitals. `filled` is the one main action.
struct PillButtonStyle: ButtonStyle {
    var filled = false
    var wide = false

    func makeBody(configuration: Configuration) -> some View {
        PillLabel(configuration: configuration, filled: filled, wide: wide)
    }

    private struct PillLabel: View {
        let configuration: ButtonStyleConfiguration
        let filled: Bool
        let wide: Bool
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.sans(12, relativeTo: .footnote, weight: .medium))
                .tracking(2.4)
                .textCase(.uppercase)
                .foregroundStyle(filled ? Color.paper : Color.ink)
                .padding(.horizontal, 26)
                .padding(.vertical, 15)
                .frame(maxWidth: wide ? .infinity : nil)
                .background {
                    Capsule().fill(filled ? Color.ink : Color.clear)
                }
                .overlay {
                    Capsule().strokeBorder(filled ? Color.clear : Color.hairline, lineWidth: 1)
                }
                .contentShape(Capsule())
                .opacity(isEnabled ? (configuration.isPressed ? 0.6 : 1) : 0.35)
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
        }
    }
}

extension ButtonStyle where Self == PillButtonStyle {
    static var pill: PillButtonStyle { PillButtonStyle() }
    static var pillFilled: PillButtonStyle { PillButtonStyle(filled: true) }
    static func pill(filled: Bool = false, wide: Bool) -> PillButtonStyle { PillButtonStyle(filled: filled, wide: wide) }
}

/// A plain text link in spaced capitals, for quiet secondary actions.
struct QuietLinkStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.sans(11, relativeTo: .caption, weight: .medium))
            .tracking(2.2)
            .textCase(.uppercase)
            .foregroundStyle(Color.muted)
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

extension ButtonStyle where Self == QuietLinkStyle {
    static var quiet: QuietLinkStyle { QuietLinkStyle() }
}

// MARK: - Paper

/// The site's paper: cream with a faint grain (light flecks at night).
struct PaperBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Color.paper
            Rectangle()
                .fill(ImagePaint(image: Grain.image(dark: scheme == .dark), scale: 0.5))
                .blendMode(.normal)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Seeded noise tile, made once per appearance.
enum Grain {
    private static var cache: [Bool: Image] = [:]

    static func image(dark: Bool) -> Image {
        if let cached = cache[dark] { return cached }
        let size = 192
        var generator = SeededGenerator(seed: 119_011)
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        // Light mode: warm brown flecks. Dark mode: cream flecks, fainter.
        let (r, g, b): (UInt8, UInt8, UInt8) = dark ? (250, 247, 240) : (89, 82, 69)
        let maxAlpha: Double = dark ? 0.07 : 0.11
        for i in 0..<(size * size) {
            let n = Double.random(in: 0...1, using: &generator)
            let a = n > 0.5 ? (n - 0.5) * 2 * maxAlpha : 0
            let alpha = UInt8(a * 255)
            // Premultiplied RGBA.
            pixels[i * 4] = UInt8(Double(r) * a)
            pixels[i * 4 + 1] = UInt8(Double(g) * a)
            pixels[i * 4 + 2] = UInt8(Double(b) * a)
            pixels[i * 4 + 3] = alpha
        }
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        let cg = CGImage(
            width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: size * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )!
        let image = Image(decorative: cg, scale: 1)
        cache[dark] = image
        return image
    }
}

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E37_79B9_7F4A_7C15 | 1 }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

extension View {
    /// Paper behind a screen, with list and form chrome cleared so it shows through.
    func paperScreen() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background { PaperBackground() }
            .toolbarBackground(.hidden, for: .navigationBar)
    }
}

// MARK: - System chrome

enum Appearance {
    /// Navigation titles and controls in the site's type, once at launch.
    static func apply() {
        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        let ink = UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0xFAF9F5) : UIColor(hex: 0x141413) }
        nav.largeTitleTextAttributes = [.font: cormorant(size: 38), .foregroundColor: ink]
        nav.titleTextAttributes = [.font: cormorant(size: 22), .foregroundColor: ink]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
    }

    /// Cormorant Garamond Medium. The font is variable, so it is picked by family and weight.
    private static func cormorant(size: CGFloat) -> UIFont {
        let descriptor = UIFontDescriptor(fontAttributes: [
            .family: "Cormorant Garamond",
            .traits: [UIFontDescriptor.TraitKey.weight: UIFont.Weight.medium],
        ])
        let font = UIFont(descriptor: descriptor, size: size)
        return font.familyName == "Cormorant Garamond" ? font : .systemFont(ofSize: size * 0.8, weight: .medium)
    }
}

// MARK: - Titles

extension View {
    /// A navigation title set in Cormorant. The plain title stays for the back button and VoiceOver.
    func serifTitle(_ title: String) -> some View {
        self
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.serif(22, relativeTo: .headline, weight: .medium))
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                        .accessibilityAddTraits(.isHeader)
                }
            }
    }
}

/// Section header and footer in the site's voice: spaced capitals over, quiet sans under.
struct FormHeader: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View { Eyebrow(text).padding(.top, 8) }
}

struct FormFooter: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.sans(12, relativeTo: .caption))
            .foregroundStyle(Color.muted)
    }
}
