import SwiftUI
import SwiftData

/// Every verse you're hiding away, newest last. No progress marks, no dates.
struct DeckView: View {
    @Query(sort: \Verse.createdAt) private var verses: [Verse]
    @Environment(\.modelContext) private var context
    @State private var showingAdd = false

    var body: some View {
        List {
            ForEach(verses) { verse in
                NavigationLink {
                    VerseDetailView(verse: verse)
                } label: {
                    VerseRow(verse: verse)
                }
                .listRowBackground(Color.clear)
                .listRowSeparatorTint(Color.hairline.opacity(0.6))
                .listRowInsets(EdgeInsets(top: 14, leading: 24, bottom: 14, trailing: 20))
            }
            .onDelete(perform: delete)
        }
        .listStyle(.plain)
        .overlay {
            if verses.isEmpty {
                VStack(spacing: 18) {
                    VesselMark(size: 96, brightness: 0.2, breathing: false)
                    Text("No verses yet.")
                        .font(.serif(26, relativeTo: .title2, weight: .medium))
                        .foregroundStyle(Color.ink)
                    Button("Add a verse") { showingAdd = true }
                        .buttonStyle(.pill)
                }
            }
        }
        .paperScreen()
        .serifTitle("Verses")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .light))
                        .foregroundStyle(Color.ink)
                }
                .accessibilityLabel("Add a verse")
            }
        }
        .sheet(isPresented: $showingAdd) {
            VerseEditorView(verse: nil)
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
        VStack(alignment: .leading, spacing: 6) {
            Text(verse.reference)
                .font(.serif(22, relativeTo: .title3, weight: .medium))
                .foregroundStyle(Color.ink)
            Text(verse.text)
                .font(.serif(18, relativeTo: .body))
                .foregroundStyle(Color.muted)
                .lineLimit(2)
        }
        .padding(.vertical, 2)
    }
}

struct VerseDetailView: View {
    let verse: Verse
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var confirmFresh = false
    @State private var confirmDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Eyebrow(verse.displayReference)
                Text(verse.text)
                    .font(.verse)
                    .lineSpacing(4)
                    .foregroundStyle(Color.ink)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                NavigationLink {
                    PracticeView(verse: verse)
                } label: {
                    Text("Practice")
                }
                .buttonStyle(.pill)
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 40)
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .paperScreen()
        .serifTitle(verse.reference)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit", systemImage: "pencil") { editing = true }
                    Button("Start fresh", systemImage: "arrow.counterclockwise") { confirmFresh = true }
                    Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = true }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .light))
                        .foregroundStyle(Color.ink)
                }
                .accessibilityLabel("More")
            }
        }
        .sheet(isPresented: $editing) {
            VerseEditorView(verse: verse)
        }
        .confirmationDialog("Start this verse fresh?", isPresented: $confirmFresh, titleVisibility: .visible) {
            Button("Start fresh") {
                Leitner.reset(verse)
                try? context.save()
            }
        } message: {
            Text("It will come back often again, as if you just added it.")
        }
        .confirmationDialog("Delete this verse?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                context.delete(verse)
                try? context.save()
                dismiss()
            }
        }
    }
}
