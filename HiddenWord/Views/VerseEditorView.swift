import SwiftUI
import SwiftData

/// Add a new verse (verse == nil) or edit an existing one.
struct VerseEditorView: View {
    let verse: Verse?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var reference: String
    @State private var translation: String
    @State private var text: String

    init(verse: Verse?) {
        self.verse = verse
        _reference = State(initialValue: verse?.reference ?? "")
        _translation = State(initialValue: verse?.translation ?? "")
        _text = State(initialValue: verse?.text ?? "")
    }

    private var canSave: Bool {
        !reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Reference, e.g. Psalm 119:11", text: $reference)
                        .textInputAutocapitalization(.words)
                    TextField("Translation (optional), e.g. ESV", text: $translation)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }

                Section {
                    TextEditor(text: $text)
                        .font(.system(.body, design: .serif))
                        .frame(minHeight: 160)
                    PasteButton(payloadType: String.self) { strings in
                        let pasted = strings.first ?? ""
                        Task { @MainActor in
                            applyPaste(pasted)
                        }
                    }
                } header: {
                    Text("Verse text")
                } footer: {
                    Text("Copy the verse in your Bible app, then tap Paste. If the reference comes along on its own line, it is filled in for you.")
                }
            }
            .navigationTitle(verse == nil ? "Add Verse" : "Edit Verse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        let cleanReference = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTranslation = translation.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanText = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        if let verse {
            verse.reference = cleanReference
            verse.translation = cleanTranslation
            verse.text = cleanText
        } else {
            context.insert(Verse(reference: cleanReference, text: cleanText, translation: cleanTranslation))
        }
        try? context.save()
        dismiss()
    }

    /// Accepts plain verse text, or text with the reference on its first or last line
    /// (as most Bible apps copy it). Drops share links.
    private func applyPaste(_ pasted: String) {
        var lines = pasted
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.lowercased().hasPrefix("http") }

        if lines.count > 1, reference.isEmpty {
            if let first = lines.first, Self.looksLikeReference(first) {
                setReference(from: first)
                lines.removeFirst()
            } else if let last = lines.last, Self.looksLikeReference(last) {
                setReference(from: last)
                lines.removeLast()
            }
        }
        text = lines.joined(separator: " ")
    }

    /// "John 3:30 ESV" -> reference "John 3:30", translation "ESV".
    private func setReference(from line: String) {
        var words = line.split(separator: " ").map(String.init)
        if let last = words.last, words.count > 1,
           (2...6).contains(last.count),
           last.allSatisfy({ $0.isUppercase || $0.isNumber }),
           last.contains(where: { $0.isLetter }) {
            if translation.isEmpty { translation = last }
            words.removeLast()
        }
        reference = words.joined(separator: " ")
    }

    static func looksLikeReference(_ line: String) -> Bool {
        guard line.count <= 40 else { return false }
        let pattern = "^[1-3]?\\s?[A-Za-z][A-Za-z .]*\\s\\d+:\\d+"
        return line.range(of: pattern, options: .regularExpression) != nil
    }
}
