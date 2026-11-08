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
        case .firstLetter: return "Say the verse from the first letters. Tap a word to reveal it."
        case .blanking: return "Read it, then hide more words each round. Tap a blank to peek."
        case .typeIt: return "Type the verse from memory, then check your score."
        }
    }
}

/// Practice one verse in any mode, then grade yourself.
/// With `onGraded` nil, the view dismisses itself after grading.
struct PracticeView: View {
    let verse: Verse
    let progressLabel: String?
    let onGraded: ((Bool) -> Void)?

    @AppStorage("practiceMode") private var mode: PracticeMode = .firstLetter
    @Environment(\.modelContext) private var context
    @Environment(StreakStore.self) private var streak
    @Environment(\.dismiss) private var dismiss
    @State private var keyboardVisible = false

    init(verse: Verse, progressLabel: String? = nil, onGraded: ((Bool) -> Void)? = nil) {
        self.verse = verse
        self.progressLabel = progressLabel
        self.onGraded = onGraded
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                Picker("Mode", selection: $mode) {
                    ForEach(PracticeMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(mode.hint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                switch mode {
                case .firstLetter:
                    FirstLetterView(text: verse.text)
                case .blanking:
                    BlankingView(text: verse.text)
                case .typeIt:
                    TypeRecallView(text: verse.text)
                }
            }
            .padding()
            // Tapping empty space closes the keyboard (buttons and words still get their taps).
            .background(Color.clear.contentShape(Rectangle()).onTapGesture { Keyboard.dismiss() })
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            // Hidden while typing so the keyboard and the grade bar don't eat the whole screen.
            if !keyboardVisible { gradeBar }
        }
        .onKeyboardVisibilityChange { visible in
            withAnimation(.easeOut(duration: 0.2)) { keyboardVisible = visible }
        }
        .keyboardDoneButton()
        .navigationTitle(progressLabel ?? verse.reference)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verse.displayReference)
                .font(.system(.title2, design: .serif).weight(.semibold))
            Text("Box \(verse.box) of \(Leitner.maxBox)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var gradeBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    grade(false)
                } label: {
                    Label("Missed it", systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    grade(true)
                } label: {
                    Label("Got it", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)

            Text("Got it: next in \(Leitner.interval(forBox: verse.box + 1)) days. Missed: tomorrow.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func grade(_ remembered: Bool) {
        Leitner.apply(remembered: remembered, to: verse)
        streak.recordPractice()
        try? context.save()
        if let onGraded {
            onGraded(remembered)
        } else {
            dismiss()
        }
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
        VStack(alignment: .leading, spacing: 16) {
            FlowLayout {
                ForEach(tokens) { token in
                    let isOpen = revealed.contains(token.id) || !token.hasLetters
                    Text(isOpen ? token.raw : token.firstLetterHint)
                        .font(.system(.title3, design: .serif).weight(isOpen ? .regular : .semibold))
                        .foregroundStyle(isOpen ? Color.primary : Color.accentColor)
                        .contentShape(Rectangle())
                        .onTapGesture { revealed.insert(token.id) }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityLabel(isOpen ? token.raw : "Hidden word starting with \(token.firstLetterHint)")
                }
            }

            HStack {
                Button("Reveal all") { revealed = Set(tokens.map(\.id)) }
                Spacer()
                Button("Hide all") { revealed = [] }
            }
            .font(.subheadline)
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
        VStack(alignment: .leading, spacing: 16) {
            ProgressView(value: Double(round), total: Double(steps)) {
                Text(round == 0 ? "Read it through once" : "Round \(round) of \(steps)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            FlowLayout {
                ForEach(tokens) { token in
                    let isHidden = hiddenIDs.contains(token.id) && !peeked.contains(token.id)
                    Text(isHidden ? token.blanked : token.raw)
                        .font(.system(.title3, design: .serif))
                        .foregroundStyle(isHidden ? Color.secondary : Color.primary)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard hiddenIDs.contains(token.id) else { return }
                            if peeked.contains(token.id) {
                                peeked.remove(token.id)
                            } else {
                                peeked.insert(token.id)
                            }
                        }
                        .accessibilityLabel(isHidden ? "Blank" : token.raw)
                }
            }

            HStack {
                Button("Start over") {
                    round = 0
                    peeked = []
                    order.shuffle()
                }
                .disabled(round == 0)
                Spacer()
                Button {
                    round = min(round + 1, steps)
                    peeked = []
                } label: {
                    Label("Hide more", systemImage: "eye.slash")
                }
                .buttonStyle(.bordered)
                .disabled(round >= steps)
            }
            .font(.subheadline)
        }
        .animation(.easeInOut(duration: 0.2), value: round)
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
        VStack(alignment: .leading, spacing: 16) {
            // A growing field (not TextEditor) so the box gets taller as you type and the page
            // scrolls, instead of the text scrolling inside a small box behind the keyboard.
            TextField("Type the verse from memory", text: $attempt, axis: .vertical)
                .lineLimit(5...)
                .focused($editorFocused)
                .font(.system(.body, design: .serif))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.sentences)
                .padding(12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel("Type the verse")

            HStack {
                Button {
                    editorFocused = false
                    result = RecallScorer.score(attempt: attempt, target: text)
                } label: {
                    Label("Check", systemImage: "checkmark.circle")
                }
                .buttonStyle(.bordered)
                .disabled(attempt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()

                if result != nil {
                    Button("Try again") {
                        attempt = ""
                        result = nil
                        editorFocused = true
                    }
                }
            }
            .font(.subheadline)

            if let result {
                resultView(result)
            }
        }
    }

    private func resultView(_ result: RecallScorer.Result) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(result.percent)%")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(verdict(for: result.percent))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            FlowLayout {
                ForEach(tokens) { token in
                    let recalled = result.recalledTokenIDs.contains(token.id)
                    Text(token.raw)
                        .font(.system(.body, design: .serif).weight(recalled ? .regular : .bold))
                        .underline(!recalled)
                        .foregroundStyle(recalled ? Color.primary : Color.orange)
                }
            }

            Text("Words in orange were missed or misspelled.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func verdict(for percent: Int) -> String {
        switch percent {
        case 95...: return "Hidden in your heart. Mark it Got it."
        case 80..<95: return "Very close. Your call."
        case 50..<80: return "Getting there. Mark it Missed and come back tomorrow."
        default: return "Keep at it. Try Letters mode first."
        }
    }
}
