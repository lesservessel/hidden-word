import SwiftUI
import SwiftData

struct DeckView: View {
    @Query(sort: \Verse.createdAt) private var verses: [Verse]
    @Environment(\.modelContext) private var context
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(verses) { verse in
                    NavigationLink {
                        VerseDetailView(verse: verse)
                    } label: {
                        VerseRow(verse: verse)
                    }
                }
                .onDelete(perform: delete)
            }
            .overlay {
                if verses.isEmpty {
                    ContentUnavailableView(
                        "No verses",
                        systemImage: "book.closed",
                        description: Text("Tap + to paste a verse from your Bible app.")
                    )
                }
            }
            .navigationTitle("Deck")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Label("Add verse", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                VerseEditorView(verse: nil)
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(verses[index])
        }
        try? context.save()
    }
}

struct VerseRow: View {
    let verse: Verse

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(verse.displayReference)
                    .font(.headline)
                Spacer()
                BoxDots(box: verse.box)
            }
            Text(verse.text)
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Text(dueText(for: verse))
                .font(.caption)
                .foregroundStyle(verse.isDueToday ? Color.accentColor : Color.secondary)
        }
        .padding(.vertical, 2)
    }
}

func dueText(for verse: Verse) -> String {
    if verse.isDueToday { return "Due today" }
    return "Due " + verse.dueDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
}

/// Six dots, filled up to the verse's Leitner box.
struct BoxDots: View {
    let box: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...Leitner.maxBox, id: \.self) { level in
                Circle()
                    .fill(level <= box ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Box \(box) of \(Leitner.maxBox)")
    }
}

struct VerseDetailView: View {
    let verse: Verse
    @Environment(\.modelContext) private var context
    @State private var editing = false
    @State private var confirmReset = false

    init(verse: Verse) {
        self.verse = verse
    }

    var body: some View {
        List {
            Section {
                Text(verse.text)
                    .font(.system(.title3, design: .serif))
                    .textSelection(.enabled)
                    .padding(.vertical, 4)
            } header: {
                Text(verse.displayReference)
            }

            Section {
                NavigationLink {
                    PracticeView(verse: verse)
                } label: {
                    Label("Practice now", systemImage: "play.fill")
                }
            }

            Section("Progress") {
                LabeledContent("Box") { BoxDots(box: verse.box) }
                LabeledContent("Next review", value: dueText(for: verse))
                LabeledContent("Reviews", value: "\(verse.reviewCount)")
                if let last = verse.lastReviewed {
                    LabeledContent("Last reviewed", value: last.formatted(date: .abbreviated, time: .omitted))
                }
                Button("Reset progress", role: .destructive) { confirmReset = true }
            }
        }
        .navigationTitle(verse.reference)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { editing = true }
            }
        }
        .sheet(isPresented: $editing) {
            VerseEditorView(verse: verse)
        }
        .confirmationDialog("Reset this verse?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset", role: .destructive) {
                Leitner.reset(verse)
                try? context.save()
            }
        } message: {
            Text("It goes back to box 1 and is due today.")
        }
    }
}
