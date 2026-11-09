import SwiftUI
import SwiftData

@main
struct HiddenWordApp: App {
    init() {
        Appearance.apply()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Color.ink)
        }
        .modelContainer(for: Verse.self)
    }
}

/// No tab bar: one home screen, with Verses and Settings a quiet link away.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("welcomed") private var welcomed = false

    var body: some View {
        ZStack {
            if welcomed {
                HomeView()
                    .transition(.opacity)
            } else {
                WelcomeView { withStarterVerses in
                    if withStarterVerses { StarterDeck.seedIfNeeded(context: context) }
                    else { StarterDeck.markSeeded() }
                    withAnimation(.easeInOut(duration: 0.6)) { welcomed = true }
                }
                .transition(.opacity)
            }
        }
        .task {
            // People who used the app before the welcome existed already have their verses.
            if !welcomed, StarterDeck.wasSeeded { welcomed = true }
            repairGarbledVerses()
        }
    }

    /// Fixes verses saved before the paste cleanup repaired garbled quotes ("person‚Äôs").
    /// Cheap and idempotent, so it simply runs on every launch.
    private func repairGarbledVerses() {
        guard let verses = try? context.fetch(FetchDescriptor<Verse>()) else { return }
        var changed = false
        for verse in verses {
            let text = PassageCleaner.repairEncoding(verse.text)
            if text != verse.text { verse.text = text; changed = true }
        }
        if changed { try? context.save() }
    }
}
