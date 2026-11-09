import SwiftUI
import SwiftData

/// One quiet screen: the vessel, today's verse, and a single way in.
/// No counts, no streaks, nothing that reads like homework.
struct HomeView: View {
    @Query(sort: \Verse.createdAt) private var verses: [Verse]
    @State private var sessionVerses: [Verse] = []
    @State private var showingSession = false
    @State private var showingAdd = false
    @State private var appeared = false

    /// Verses ready to come back today, most overdue first. Never shown as a number.
    private var ready: [Verse] {
        verses.filter(\.isReadyToday).sorted { $0.dueDate < $1.dueDate }
    }

    /// For "practice anyway": the verses longest since you last spent time with them.
    private var restful: [Verse] {
        let sorted = verses.sorted { ($0.lastReviewed ?? .distantPast) < ($1.lastReviewed ?? .distantPast) }
        return Array(sorted.prefix(5))
    }

    /// Same verse all day, rotating through the deck one per day.
    private var verseOfTheDay: Verse? {
        guard !verses.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: .now) ?? 0
        return verses[day % verses.count]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                GeometryReader { geo in
                    ScrollView {
                        VStack(spacing: 0) {
                            VesselMark(size: 132)
                                .padding(.bottom, 34)

                            if let verse = verseOfTheDay {
                                todayVerse(verse)
                            } else {
                                emptyVessel
                            }
                        }
                        .frame(maxWidth: 560)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 24)
                        // Centered in the space between header and button; scrolls if a long passage needs it.
                        .frame(maxWidth: .infinity, minHeight: geo.size.height)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }

                if !verses.isEmpty {
                    action
                        .padding(.horizontal, 28)
                        .padding(.bottom, 18)
                        .padding(.top, 8)
                }
            }
            .opacity(appeared ? 1 : 0)
            .background { PaperBackground() }
            .toolbar(.hidden, for: .navigationBar)
            // Driven by state so the session stays on screen as verses are let go.
            .navigationDestination(isPresented: $showingSession) {
                ReviewSessionView(verses: sessionVerses)
            }
            .sheet(isPresented: $showingAdd) {
                VerseEditorView(verse: nil)
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.8)) { appeared = true }
            }
        }
    }

    // MARK: Pieces

    /// The site's header: wordmark left, spaced-capital links right.
    private var header: some View {
        // Side by side when it fits; at very large text sizes the links drop below the name.
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                wordmark.fixedSize()
                Spacer(minLength: 16)
                links.fixedSize()
            }
            VStack(alignment: .leading, spacing: 10) {
                wordmark
                links
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 44)
    }

    private var wordmark: some View {
        Text("Hidden Word")
            .font(.serif(25, relativeTo: .title2, weight: .medium))
            .foregroundStyle(Color.ink)
            .accessibilityAddTraits(.isHeader)
    }

    private var links: some View {
        HStack(spacing: 18) {
            NavigationLink { DeckView() } label: { Eyebrow("Verses").frame(minHeight: 44) }
            NavigationLink { SettingsView() } label: { Eyebrow("Settings").frame(minHeight: 44) }
        }
    }

    private func todayVerse(_ verse: Verse) -> some View {
        NavigationLink {
            PracticeView(verse: verse)
        } label: {
            VStack(spacing: 18) {
                Eyebrow("Today")
                Text("“\(verse.text)”")
                    .font(.serifItalic(25, relativeTo: .title2))
                    .lineSpacing(3)
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(9)
                    .fixedSize(horizontal: false, vertical: true)
                Eyebrow(verse.displayReference)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens this verse to practice")
    }

    private var emptyVessel: some View {
        VStack(spacing: 20) {
            Text("An empty vessel.")
                .font(.serif(30, relativeTo: .title, weight: .medium))
                .foregroundStyle(Color.ink)
            Text("Paste a verse from any Bible app to begin.")
                .font(.serifItalic(20, relativeTo: .title3))
                .foregroundStyle(Color.muted)
                .multilineTextAlignment(.center)
            Button("Add a verse") { showingAdd = true }
                .buttonStyle(.pill)
                .padding(.top, 10)
        }
    }

    @ViewBuilder
    private var action: some View {
        if ready.isEmpty {
            // The quiet rest state: nothing scheduled, nothing owed.
            VStack(spacing: 4) {
                Text("Rest. Come back tomorrow.")
                    .font(.serifItalic(21, relativeTo: .title3))
                    .foregroundStyle(Color.muted)
                    .frame(minHeight: 50)
                Button("Practice anyway") { start(restful) }
                    .buttonStyle(.quiet)
            }
        } else {
            Button("Start review") { start(ready) }
                .buttonStyle(.pill(filled: true, wide: true))
                .frame(maxWidth: 360)
                .sensoryFeedback(.impact(weight: .light), trigger: showingSession)
        }
    }

    private func start(_ verses: [Verse]) {
        guard !verses.isEmpty else { return }
        sessionVerses = verses
        showingSession = true
    }
}
