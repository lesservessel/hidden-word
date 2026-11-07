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
        }
    }
}
