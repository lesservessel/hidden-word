import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \Verse.createdAt) private var verses: [Verse]
    @Environment(StreakStore.self) private var streak
    @State private var sessionVerses: [Verse] = []
    @State private var showingSession = false

    private var due: [Verse] {
        verses.filter(\.isDueToday).sorted { $0.dueDate < $1.dueDate }
    }

    /// Same verse all day, rotating through the deck one per day.
    private var verseOfTheDay: Verse? {
        guard !verses.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: .now) ?? 0
        return verses[day % verses.count]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    epigraph

                    if verses.isEmpty {
                        ContentUnavailableView(
                            "No verses yet",
                            systemImage: "book.closed",
                            description: Text("Add a verse in the Deck tab, or restore the starter verses in Settings.")
                        )
                    } else {
                        stats
                        reviewButton
                        if let verse = verseOfTheDay {
                            todayCard(verse)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Hidden Word")
            // Driven by state (not a NavigationLink inside the button) so the session stays
            // on screen when the last due verse is graded and the button is swapped out.
            .navigationDestination(isPresented: $showingSession) {
                ReviewSessionView(verses: sessionVerses)
            }
        }
    }

    private var epigraph: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("“I have stored up your word in my heart, that I might not sin against you.”")
                .font(.system(.body, design: .serif).italic())
            Text("Psalm 119:11")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var stats: some View {
        let daysStreak = streak.displayStreak()
        return HStack(spacing: 12) {
            StatTile(value: "\(due.count)", label: "Due today", systemImage: "tray.full")
            StatTile(
                value: "\(daysStreak)",
                label: "Day streak",
                systemImage: streak.practicedToday() ? "flame.fill" : "flame"
            )
            StatTile(value: "\(verses.filter(\.isMastered).count)", label: "Mastered", systemImage: "seal")
        }
    }

    @ViewBuilder
    private var reviewButton: some View {
        if due.isEmpty {
            Label("All caught up for today.", systemImage: "checkmark.seal")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        } else {
            Button {
                sessionVerses = due
                showingSession = true
            } label: {
                Label("Start review · \(due.count) due", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private func todayCard(_ verse: Verse) -> some View {
        NavigationLink {
            PracticeView(verse: verse)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text("TODAY’S VERSE")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(verse.text)
                    .font(.system(.title3, design: .serif))
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary)
                Text(verse.displayReference)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct StatTile: View {
    let value: String
    let label: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
            Text(value)
                .font(.title.weight(.bold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}
