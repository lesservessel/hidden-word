import SwiftUI
import SwiftData

@main
struct HiddenWordApp: App {
    @State private var streak = StreakStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(streak)
        }
        .modelContainer(for: Verse.self)
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Today", systemImage: "sun.max") }
            DeckView()
                .tabItem { Label("Deck", systemImage: "books.vertical") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
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
