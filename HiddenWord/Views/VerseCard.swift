import SwiftUI

/// A verse set as a square card in the lesservessel style, for sharing.
/// Rendered off screen at 1080×1080 so it looks right on any social feed.
struct VerseCard: View {
    let text: String
    let reference: String
    var dark = false

    private var ink: Color { dark ? Color(light: 0xFAF9F5, dark: 0xFAF9F5) : Color(light: 0x141413, dark: 0x141413) }
    private var paper: Color { dark ? Color(light: 0x141413, dark: 0x141413) : Color(light: 0xFAF9F5, dark: 0xFAF9F5) }
    private var muted: Color { dark ? Color(light: 0xB0AEA5, dark: 0xB0AEA5) : Color(light: 0x5E5D59, dark: 0x5E5D59) }

    /// Long passages get smaller type so they always fit the square.
    private var fontSize: CGFloat {
        switch text.count {
        case ..<120: return 62
        case ..<220: return 52
        case ..<360: return 42
        case ..<560: return 34
        default: return 27
        }
    }

    var body: some View {
        ZStack {
            paper
            Rectangle().fill(ImagePaint(image: Grain.image(dark: dark), scale: 1)).opacity(0.9)

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                VesselMark(size: 170, brightness: 0.85, breathing: false, lineWidth: 2.6)
                    .environment(\.colorScheme, dark ? .dark : .light)
                    .padding(.bottom, 56)

                Text("“\(text)”")
                    .font(.custom("Cormorant Garamond", fixedSize: fontSize).italic())
                    .lineSpacing(fontSize * 0.12)
                    .foregroundStyle(ink)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .padding(.bottom, 44)

                Text(reference.uppercased())
                    .font(.custom("Inter", fixedSize: 22).weight(.medium))
                    .tracking(6)
                    .foregroundStyle(muted)

                Spacer(minLength: 0)
                Spacer(minLength: 0)

                Text("HIDDEN WORD")
                    .font(.custom("Inter", fixedSize: 16).weight(.medium))
                    .tracking(5)
                    .foregroundStyle(muted.opacity(0.7))
            }
            .padding(.horizontal, 110)
            .padding(.top, 70)
            .padding(.bottom, 70)
        }
        .frame(width: 1080, height: 1080)
        .environment(\.colorScheme, dark ? .dark : .light)
    }
}

/// The finished image, ready for the share sheet.
struct ShareableVerse: Transferable {
    let text: String
    let reference: String
    let dark: Bool

    @MainActor
    func render() -> Image {
        let renderer = ImageRenderer(content: VerseCard(text: text, reference: reference, dark: dark))
        renderer.scale = 1
        if let ui = renderer.uiImage { return Image(uiImage: ui) }
        return Image(systemName: "photo")
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { item in
            await MainActor.run {
                let renderer = ImageRenderer(content: VerseCard(text: item.text, reference: item.reference, dark: item.dark))
                renderer.scale = 1
                return renderer.uiImage?.pngData() ?? Data()
            }
        }
    }
}

/// Preview the card, pick paper or ink, then share.
struct ShareVerseSheet: View {
    let text: String
    let reference: String

    @Environment(\.dismiss) private var dismiss
    @State private var dark = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                VerseCard(text: text, reference: reference, dark: dark)
                    .scaleEffect(320.0 / 1080.0)
                    .frame(width: 320, height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.hairline.opacity(0.6), lineWidth: 1))
                    .shadow(color: .black.opacity(0.08), radius: 18, y: 8)
                    .animation(.easeInOut(duration: 0.3), value: dark)
                    .accessibilityElement()
                    .accessibilityLabel("Preview of \(reference) as an image")

                HStack(spacing: 10) {
                    Button("Paper") { dark = false }
                        .buttonStyle(.pill(filled: !dark, wide: true))
                    Button("Ink") { dark = true }
                        .buttonStyle(.pill(filled: dark, wide: true))
                }
                .frame(maxWidth: 320)
                .sensoryFeedback(.selection, trigger: dark)

                let item = ShareableVerse(text: text, reference: reference, dark: dark)
                ShareLink(item: item, preview: SharePreview(reference, image: item.render())) {
                    Text("Share image")
                }
                .buttonStyle(.pill(filled: true, wide: true))
                .frame(maxWidth: 320)

                Spacer(minLength: 0)
            }
            .padding(.top, 24)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
            .background { PaperBackground() }
            .serifTitle("Share")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.foregroundStyle(Color.muted)
                }
            }
        }
        .presentationDetents([.large])
    }
}
