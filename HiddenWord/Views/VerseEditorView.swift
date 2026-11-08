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
                        .onChange(of: text) { old, new in textChanged(from: old, to: new) }
                    PasteButton(payloadType: String.self) { strings in
                        let pasted = strings.first ?? ""
                        Task { @MainActor in
                            applyPaste(pasted)
                        }
                    }
                } header: {
                    Text("Verse text")
                } footer: {
                    Text("Copy a verse or passage from any Bible app or website, then tap Paste. Verse numbers, headings and footnote marks are removed, and the reference and translation are filled in when they come along.")
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

    /// Cleans pasted text down to just the passage (see `PassageCleaner`) and fills in the
    /// reference and translation when they came along and the fields are still empty.
    private func applyPaste(_ pasted: String) {
        let result = PassageCleaner.clean(pasted)
        if reference.isEmpty, let ref = result.reference { reference = ref }
        if translation.isEmpty, let tag = result.translation { translation = tag }
        text = result.text
    }

    /// A paste straight into the text box (long-press > Paste) arrives as one big jump in
    /// length. Typing never adds this much at once, so ordinary editing is left alone.
    private func textChanged(from old: String, to new: String) {
        guard new.count - old.count >= 25 else { return }
        let cleaned = PassageCleaner.clean(new)
        guard cleaned.text != new else { return }
        // Apply after the text view finishes its own paste, or it can overwrite our change.
        DispatchQueue.main.async { applyPaste(new) }
    }
}
