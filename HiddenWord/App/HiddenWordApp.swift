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

    var body: some View {
        HomeView()
            .task {
                StarterDeck.seedIfNeeded(context: context)
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
