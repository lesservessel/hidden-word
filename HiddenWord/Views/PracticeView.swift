import SwiftUI
import SwiftData

enum PracticeMode: String, CaseIterable, Identifiable {
    case firstLetter
    case blanking
    case typeIt

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstLetter: return "Letters"
        case .blanking: return "Blanks"
        case .typeIt: return "Type"
        }
    }

    var hint: String {
        switch self {
        case .firstLetter: return "Say it from the first letters. Touch a word to see it."
        case .blanking: return "Read it once, then let words fall away."
        case .typeIt: return "Write it from memory."
        }
    }
}

/// One verse, practiced in any mode, then let go with "Again soon" or "Hidden".
/// Outside a session (`onGraded` nil) the screen closes itself afterwards.
struct PracticeView: View {
    let verse: Verse
    /// 0...1 through a session, shown as a hairline. Nil outside a session.
    let progress: Double?
    let onGraded: ((Bool) -> Void)?

    @AppStorage("practiceMode") private var mode: PracticeMode = .firstLetter
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var keyboardVisible = false
    @State private var graded = 0
    /// Set on the first choice. While this screen fades out, extra taps must not count
    /// against this verse again or skip the next one.
    @State private var settled = false

    init(verse: Verse, progress: Double? = nil, onGraded: ((Bool) -> Void)? = nil) {
        self.verse = verse
        self.progress = progress
        self.onGraded = onGraded
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 14) {
                    Eyebrow(verse.displayReference)
                    ModePicker(mode: $mode)
                    Text(mode.hint)
                        .font(.sans(13, relativeTo: .footnote))
                        .foregroundStyle(Color.muted)
                        .id(mode)
                        .transition(.opacity)
                }

                Group {
                    switch mode {
                    case .firstLetter: FirstLetterView(text: verse.text)
                    case .blanking: BlankingView(text: verse.text)
                    case .typeIt: TypeRecallView(text: verse.text)
                    }
                }
                .transition(.opacity)
            }
            .animation(.easeInOut(duration: 0.25), value: mode)
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 32)
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
            // Tapping empty paper closes the keyboard (words and buttons keep their taps).
            .background(Color.clear.contentShape(Rectangle()).onTapGesture { Keyboard.dismiss() })
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .top, spacing: 0) {
            if let progress { SessionHairline(progress: progress) }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // Hidden while typing so the keyboard and the choices don't crowd the verse.
            if !keyboardVisible { gradeBar.transition(.opacity) }
        }
        .onKeyboardVisibilityChange { visible in
            withAnimation(.easeOut(duration: 0.2)) { keyboardVisible = visible }
        }
        .keyboardDoneButton()
        .paperScreen()
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: mode)
        .sensoryFeedback(.success, trigger: graded)
    }

    private var gradeBar: some View {
        HStack(spacing: 12) {
            Button("Again soon") { grade(false) }
                .buttonStyle(.pill(wide: true))
            Button("Hidden") { grade(true) }
                .buttonStyle(.pill(filled: true, wide: true))
        }
        .allowsHitTesting(!settled)
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background {
            PaperBackground()
                .overlay(alignment: .top) { Rectangle().fill(Color.hairline.opacity(0.45)).frame(height: 0.5) }
        }
    }

    private func grade(_ remembered: Bool) {
        guard !settled else { return }
        settled = true
        Leitner.apply(remembered: remembered, to: verse)
        try? context.save()
        if remembered { graded += 1 }
        if let onGraded {
            onGraded(remembered)
        } else {
            dismiss()
        }
    }
}

/// Three words, the chosen one underlined. Lighter than a segmented control.
struct ModePicker: View {
    @Binding var mode: PracticeMode
    @Namespace private var underline

    var body: some View {
        HStack(spacing: 22) {
            ForEach(PracticeMode.allCases) { option in
                let selected = option == mode
                Button {
                    withAnimation(.snappy(duration: 0.25)) { mode = option }
                } label: {
                    VStack(spacing: 6) {
                        Text(option.title.uppercased())
                            .font(.sans(11, relativeTo: .caption, weight: .medium))
                            .tracking(2.4)
                            .foregroundStyle(selected ? Color.ink : Color.muted)
                        ZStack {
                            Rectangle().fill(Color.clear).frame(height: 1)
                            if selected {
                                Rectangle().fill(Color.ink).frame(height: 1)
                                    .matchedGeometryEffect(id: "line", in: underline)
                            }
                        }
                    }
                    .fixedSize()
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}

/// A one-pixel line across the top that fills as a session goes on. No numbers.
struct SessionHairline: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.hairline.opacity(0.35))
                Rectangle().fill(Color.ink.opacity(0.7))
                    .frame(width: geo.size.width * min(max(progress, 0), 1))
                    .animation(.easeInOut(duration: 0.5), value: progress)
            }
        }
        .frame(height: 1)
        .accessibilityElement()
        .accessibilityLabel("Session progress")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}

/// The verse as it is read: serif, generous leading.
private struct VerseWord: View {
    let text: String
    var color: Color = .ink
    var weight: Font.Weight = .regular

    var body: some View {
        Text(text)
            .font(.serif(26, relativeTo: .title2, weight: weight))
            .foregroundStyle(color)
            .padding(.vertical, 1)
    }
}

// MARK: - First-letter mode

struct FirstLetterView: View {
    let tokens: [WordToken]
    @State private var revealed: Set<Int> = []

    init(text: String) {
        tokens = WordToken.tokenize(text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            FlowLayout(spacing: 7, lineSpacing: 6) {
                ForEach(tokens) { token in
                    let isOpen = revealed.contains(token.id) || !token.hasLetters
                    VerseWord(
                        text: isOpen ? token.raw : token.firstLetterHint,
                        color: isOpen ? .ink : .ink,
                        weight: isOpen ? .regular : .semibold
                    )
                    .opacity(isOpen ? 1 : 0.92)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.2)) { _ = revealed.insert(token.id) }
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel(isOpen ? token.raw : "Hidden word starting with \(token.firstLetterHint)")
                }
            }
            .sensoryFeedback(.selection, trigger: revealed.count)

            HStack {
                Button("Show all") { withAnimation { revealed = Set(tokens.map(\.id)) } }
                Spacer()
                Button("Hide all") { withAnimation { revealed = [] } }
            }
            .buttonStyle(.quiet)
        }
    }
}

// MARK: - Progressive blanking mode

struct BlankingView: View {
    let tokens: [WordToken]
    private let steps = 5

    @State private var order: [Int]
    @State private var round = 0
    @State private var peeked: Set<Int> = []

    init(text: String) {
        let tokens = WordToken.tokenize(text)
        self.tokens = tokens
        _order = State(initialValue: tokens.filter(\.hasLetters).map(\.id).shuffled())
    }

    private var hiddenIDs: Set<Int> {
        let count = Int((Double(order.count) * Double(round) / Double(steps)).rounded(.up))
        return Set(order.prefix(count))
    }

    var body: some View {
        let hiddenIDs = self.hiddenIDs
        VStack(alignment: .leading, spacing: 22) {
            FlowLayout(spacing: 7, lineSpacing: 6) {
                ForEach(tokens) { token in
                    let isHidden = hiddenIDs.contains(token.id) && !peeked.contains(token.id)
                    BlankableWord(token: token, hidden: isHidden)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard hiddenIDs.contains(token.id) else { return }
                            withAnimation(.easeOut(duration: 0.2)) {
                                if peeked.contains(token.id) { peeked.remove(token.id) } else { peeked.insert(token.id) }
                            }
                        }
                        .accessibilityLabel(isHidden ? "Blank" : token.raw)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: round)

            HStack(alignment: .center) {
                Button("Start over") {
                    withAnimation { round = 0; peeked = []; order.shuffle() }
                }
                .buttonStyle(.quiet)
                .opacity(round == 0 ? 0 : 1)
                .disabled(round == 0)

                Spacer()

                RoundDots(round: round, steps: steps)

                Spacer()

                Button(round >= steps ? "All hidden" : "Hide more") {
                    round = min(round + 1, steps)
                    peeked = []
                }
                .buttonStyle(.quiet)
                .foregroundStyle(Color.ink)
                .disabled(round >= steps)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: round)
        }
    }
}

/// A word whose letters can fall away, leaving a hairline the width of the word.
private struct BlankableWord: View {
    let token: WordToken
    let hidden: Bool

    var body: some View {
        HStack(spacing: 0) {
            if !token.leading.isEmpty { VerseWord(text: token.leading) }
            VerseWord(text: token.core.isEmpty ? token.raw : token.core)
                .opacity(hidden ? 0 : 1)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.hairline)
                        .frame(height: 1)
                        .offset(y: -6)
                        .opacity(hidden ? 1 : 0)
                }
            if !token.trailing.isEmpty && token.hasLetters { VerseWord(text: token.trailing) }
        }
    }
}

private struct RoundDots: View {
    let round: Int
    let steps: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...steps, id: \.self) { i in
                Circle()
                    .fill(i <= round ? Color.ink : Color.hairline.opacity(0.6))
                    .frame(width: 4, height: 4)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(round == 0 ? "Reading through" : "Round \(round) of \(steps)")
    }
}

// MARK: - Type-it recall mode

struct TypeRecallView: View {
    let text: String
    let tokens: [WordToken]

    @State private var attempt = ""
    @State private var result: RecallScorer.Result?
    @FocusState private var editorFocused: Bool

    init(text: String) {
        self.text = text
        self.tokens = WordToken.tokenize(text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // A growing field (not TextEditor) so the box gets taller as you type and the page
            // scrolls, instead of the text scrolling inside a small box behind the keyboard.
            TextField("", text: $attempt, prompt: Text("Write it here…").foregroundStyle(Color.muted), axis: .vertical)
                .lineLimit(4...)
                .focused($editorFocused)
                .font(.serif(22, relativeTo: .title3))
                .foregroundStyle(Color.ink)
                .tint(Color.ink)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.sentences)
                .padding(16)
                .background(Color.wash, in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.hairline.opacity(0.7), lineWidth: 1))
                .accessibilityLabel("Write the verse")

            HStack {
                if result != nil {
                    Button("Try again") {
                        withAnimation { attempt = ""; result = nil }
                        editorFocused = true
                    }
                    .buttonStyle(.quiet)
                }
                Spacer()
                Button("Check") {
                    editorFocused = false
                    withAnimation(.easeOut(duration: 0.3)) {
                        result = RecallScorer.score(attempt: attempt, target: text)
                    }
                }
                .buttonStyle(.pill)
                .disabled(attempt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let result {
                resultView(result)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
    }

    private func resultView(_ result: RecallScorer.Result) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Rule()
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("\(result.percent)%")
                    .font(.serif(44, relativeTo: .largeTitle, weight: .medium))
                    .foregroundStyle(Color.ink)
                    .monospacedDigit()
                Text(verdict(for: result.percent))
                    .font(.serifItalic(20, relativeTo: .title3))
                    .foregroundStyle(Color.muted)
            }

            FlowLayout(spacing: 6, lineSpacing: 4) {
                ForEach(tokens) { token in
                    let recalled = result.recalledTokenIDs.contains(token.id)
                    Text(token.raw)
                        .font(.serif(21, relativeTo: .body, weight: recalled ? .regular : .semibold))
                        .underline(!recalled, color: Color.ink)
                        .foregroundStyle(recalled ? Color.muted : Color.ink)
                }
            }

            Text("Underlined words are the ones to look at again.")
                .font(.sans(12, relativeTo: .caption))
                .foregroundStyle(Color.muted)
        }
    }

    private func verdict(for percent: Int) -> String {
        switch percent {
        case 95...: return "Hidden in your heart."
        case 80..<95: return "Very close."
        case 50..<80: return "Taking root."
        default: return "Keep sowing. Letters may help."
        }
    }
}
