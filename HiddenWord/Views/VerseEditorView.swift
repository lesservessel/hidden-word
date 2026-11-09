import SwiftUI
import SwiftData

/// Add a new verse (verse == nil) or edit an existing one.
///
/// Adding is built around one gesture: paste. The sheet opens on a single Paste button; the
/// cleaned words appear set in type, with the reference and translation already filled in.
/// A pasted passage can be kept whole or saved as one card per verse.
struct VerseEditorView: View {
    let verse: Verse?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var reference: String
    @State private var translation: String
    @State private var text: String
    /// Per-verse pieces of the last paste, offered as separate cards.
    @State private var segments: [PassageCleaner.VerseSegment] = []
    @State private var splitIntoVerses = false
    @State private var typing = false
    @FocusState private var focus: Field?

    private enum Field { case reference, translation, words }

    init(verse: Verse?) {
        self.verse = verse
        _reference = State(initialValue: verse?.reference ?? "")
        _translation = State(initialValue: verse?.translation ?? "")
        _text = State(initialValue: verse?.text ?? "")
    }

    private var isEditing: Bool { verse != nil }
    private var hasWords: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var canSave: Bool {
        hasWords && !reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// "James 1:1-27" -> "James 1". Splitting needs a book and chapter to name each card.
    private var chapterReference: String? {
        let trimmed = reference.trimmingCharacters(in: .whitespaces)
        let base = trimmed.split(separator: ":").first.map(String.init) ?? trimmed
        return base.range(of: #"\s\d{1,3}$"#, options: .regularExpression) != nil ? base : nil
    }

    private var canSplit: Bool { !isEditing && segments.count >= 2 && chapterReference != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    if hasWords || typing || isEditing {
                        filled
                    } else {
                        empty
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 40)
                .frame(maxWidth: 640, alignment: .leading)
                .frame(maxWidth: .infinity)
                .animation(.easeInOut(duration: 0.3), value: hasWords)
            }
            .scrollDismissesKeyboard(.interactively)
            .keyboardDoneButton()
            .paperScreen()
            .serifTitle(isEditing ? "Edit verse" : "Add a verse")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.muted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saveTitle) { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(canSave ? Color.ink : Color.muted)
                        .disabled(!canSave)
                }
            }
            .sensoryFeedback(.success, trigger: segments.count)
        }
        .presentationDetents([.large])
        .presentationBackground { PaperBackground() }
    }

    private var saveTitle: String {
        canSplit && splitIntoVerses ? "Save \(segments.count)" : "Save"
    }

    // MARK: Empty: one gesture

    private var empty: some View {
        VStack(spacing: 22) {
            VesselMark(size: 92, brightness: 0.25, breathing: false)
                .padding(.top, 36)
            Text("Copy a verse or a passage from any Bible app or website.")
                .font(.serifItalic(22, relativeTo: .title3))
                .foregroundStyle(Color.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            SystemPasteButton(size: .large, tone: .ink, placeholderHeight: 50) { pasted in
                withAnimation { applyPaste(pasted) }
            }
            .labelStyle(.titleAndIcon)
            .padding(.top, 4)

            Text("Verse numbers, headings and footnotes are removed for you.")
                .font(.sans(12, relativeTo: .caption))
                .foregroundStyle(Color.muted)
                .multilineTextAlignment(.center)

            Button("Or type it") {
                withAnimation { typing = true }
                focus = .reference
            }
            .buttonStyle(.quiet)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Filled: the words, set in type

    private var filled: some View {
        VStack(alignment: .leading, spacing: 30) {
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow("Reference")
                TextField("", text: $reference, prompt: Text("Psalm 119:11").foregroundStyle(Color.hairline))
                    .font(.serif(28, relativeTo: .title, weight: .medium))
                    .foregroundStyle(Color.ink)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .reference)
                    .submitLabel(.next)
                    .onSubmit { focus = .translation }
                Rectangle().fill(Color.hairline.opacity(0.7)).frame(height: 1)
                HStack(spacing: 10) {
                    Eyebrow("Translation")
                    TextField("", text: $translation, prompt: Text("ESV").foregroundStyle(Color.hairline))
                        .font(.sans(13, relativeTo: .footnote, weight: .medium))
                        .tracking(2)
                        .foregroundStyle(Color.ink)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .translation)
                        .submitLabel(.next)
                        .onSubmit { focus = .words }
                }
                .padding(.top, 4)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Eyebrow("The words")
                    Spacer()
                    if !isEditing {
                        SystemPasteButton(size: .mini, tone: .muted, placeholderHeight: 24) { pasted in
                            withAnimation { applyPaste(pasted, replacing: true) }
                        }
                        .labelStyle(.iconOnly)
                        .accessibilityLabel("Paste again")
                    }
                }
                TextField("", text: $text, prompt: Text("Type or paste the verse…").foregroundStyle(Color.hairline), axis: .vertical)
                    .lineLimit(4...)
                    .font(.serif(23, relativeTo: .title3))
                    .lineSpacing(3)
                    .foregroundStyle(Color.ink)
                    .tint(Color.ink)
                    .focused($focus, equals: .words)
                    .onChange(of: text) { old, new in textChanged(from: old, to: new) }
            }

            if canSplit {
                splitChoice
                    .transition(.opacity)
            }
        }
    }

    /// Whole passage, or one card per verse.
    private var splitChoice: some View {
        VStack(alignment: .leading, spacing: 12) {
            Rule()
            Eyebrow("Keep it")
            HStack(spacing: 10) {
                choice("Whole", selected: !splitIntoVerses) { splitIntoVerses = false }
                choice("By verse", selected: splitIntoVerses) { splitIntoVerses = true }
            }
            if splitIntoVerses, let base = chapterReference {
                Text("\(segments.count) cards, \(base):\(segments.first!.number) to \(base):\(segments.last!.number).")
                    .font(.sans(12, relativeTo: .caption))
                    .foregroundStyle(Color.muted)
            }
        }
        .sensoryFeedback(.selection, trigger: splitIntoVerses)
    }

    private func choice(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(title) { withAnimation(.snappy) { action() } }
            .buttonStyle(.pill(filled: selected, wide: true))
            .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Saving

    private func save() {
        let cleanReference = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTranslation = translation.trimmingCharacters(in: .whitespacesAndNewlines)

        if let verse {
            verse.reference = cleanReference
            verse.translation = cleanTranslation
            verse.text = flatten(text)
        } else if canSplit && splitIntoVerses, let base = chapterReference {
            // Created a millisecond apart so they keep their order in the list.
            let start = Date.now
            for (i, segment) in segments.enumerated() {
                context.insert(Verse(
                    reference: "\(base):\(segment.number)",
                    text: segment.text,
                    translation: cleanTranslation,
                    createdAt: start.addingTimeInterval(Double(i) / 1000)
                ))
            }
        } else {
            context.insert(Verse(reference: cleanReference, text: flatten(text), translation: cleanTranslation))
        }
        try? context.save()
        dismiss()
    }

    private func flatten(_ words: String) -> String {
        PassageCleaner.repairEncoding(words)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    // MARK: Pasting

    /// Cleans pasted text down to just the passage (see `PassageCleaner`) and fills in the
    /// reference and translation when they came along and the fields are still empty.
    private func applyPaste(_ pasted: String, replacing: Bool = false) {
        let result = PassageCleaner.clean(pasted)
        if (replacing || reference.isEmpty), let ref = result.reference { reference = ref }
        if (replacing || translation.isEmpty), let tag = result.translation { translation = tag }
        text = result.text
        segments = result.verses
        splitIntoVerses = false
        // No reference came along: put the cursor where it is needed next.
        if reference.isEmpty { focus = .reference }
    }

    /// A paste straight into the text field (long-press > Paste) arrives as one big jump in
    /// length. Typing never adds this much at once, so ordinary editing is left alone.
    private func textChanged(from old: String, to new: String) {
        if new.count < old.count, !segments.isEmpty, new.isEmpty { segments = [] }
        guard new.count - old.count >= 25 else { return }
        let cleaned = PassageCleaner.clean(new)
        guard cleaned.text != new else { return }
        // Apply after the text field finishes its own paste, or it can overwrite our change.
        DispatchQueue.main.async { applyPaste(new) }
    }
}

// MARK: - System paste button

/// Apple's own `PasteButton`, set up so iOS agrees to draw it.
///
/// The paste control is drawn by the system, not by the app, and iOS leaves it blank when it
/// doesn't trust how it is shown. Two things here tripped that on iOS 26:
/// - Inserting it while the sheet is still sliding up. It is added once the sheet has settled.
/// - A tint the app computes itself (`Color.ink` resolves through a UIColor closure). It gets
///   plain, fixed colors for the current appearance instead, with the label color to match.
struct SystemPasteButton: View {
    enum Tone { case ink, muted }

    let size: ControlSize
    let tone: Tone
    /// Space held while waiting, so the layout doesn't jump when the button arrives.
    let placeholderHeight: CGFloat
    let onPaste: (String) -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var ready = false

    /// Long enough for the sheet's presentation to finish.
    private static let settleDelay: Duration = .milliseconds(450)

    var body: some View {
        Group {
            if ready {
                PasteButton(payloadType: String.self) { strings in
                    let pasted = strings.first ?? ""
                    Task { @MainActor in onPaste(pasted) }
                }
                .buttonBorderShape(.capsule)
                .controlSize(size)
                .tint(background)
                .foregroundStyle(foreground)
            } else {
                Color.clear.frame(width: 1, height: placeholderHeight)
            }
        }
        .task {
            guard !ready else { return }
            try? await Task.sleep(for: Self.settleDelay)
            // No animation: the control must not be added mid-fade.
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) { ready = true }
        }
    }

    // Fixed sRGB values matching Theme.swift (ink #141413, paper #FAF9F5, muted #5E5D59 / #B0AEA5).
    private var background: Color {
        switch (tone, scheme) {
        case (.ink, .dark): return Color(.sRGB, red: 0xFA / 255, green: 0xF9 / 255, blue: 0xF5 / 255)
        case (.ink, _): return Color(.sRGB, red: 0x14 / 255, green: 0x14 / 255, blue: 0x13 / 255)
        case (.muted, .dark): return Color(.sRGB, red: 0xB0 / 255, green: 0xAE / 255, blue: 0xA5 / 255)
        case (.muted, _): return Color(.sRGB, red: 0x5E / 255, green: 0x5D / 255, blue: 0x59 / 255)
        }
    }

    /// Paper on a dark button, ink on a light one, so the label always contrasts.
    private var foreground: Color {
        scheme == .dark
            ? Color(.sRGB, red: 0x14 / 255, green: 0x14 / 255, blue: 0x13 / 255)
            : Color(.sRGB, red: 0xFA / 255, green: 0xF9 / 255, blue: 0xF5 / 255)
    }
}
