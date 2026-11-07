import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("reminder.enabled") private var reminderEnabled = false
    @AppStorage("reminder.hour") private var reminderHour = 7
    @AppStorage("reminder.minute") private var reminderMinute = 0

    @Environment(\.modelContext) private var context
    @Environment(StreakStore.self) private var streak
    @Query private var verses: [Verse]

    @State private var showDenied = false
    @State private var confirmReset = false
    @State private var restoreMessage: String?

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: reminderHour, minute: reminderMinute, second: 0, of: .now) ?? .now
            },
            set: { newValue in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                reminderHour = parts.hour ?? 7
                reminderMinute = parts.minute ?? 0
            }
        )
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Daily reminder", isOn: $reminderEnabled)
                    if reminderEnabled {
                        DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Reminder")
                } footer: {
                    Text("A notification scheduled on this iPhone. Nothing is sent anywhere.")
                }

                Section {
                    LabeledContent("Current streak", value: "\(streak.displayStreak()) days")
                    LabeledContent("Best streak", value: "\(streak.best) days")
                    LabeledContent("Verses", value: "\(verses.count)")
                    Button("Restore starter verses") {
                        let added = StarterDeck.insertMissing(context: context)
                        restoreMessage = added == 0
                            ? "All starter verses are already in your deck."
                            : "Added \(added) starter verse\(added == 1 ? "" : "s")."
                    }
                    Button("Reset all progress", role: .destructive) { confirmReset = true }
                } header: {
                    Text("Progress")
                } footer: {
                    if let restoreMessage {
                        Text(restoreMessage)
                    }
                }

                Section("How review works") {
                    Text("Each verse sits in one of six boxes. Got it moves it up a box; missed sends it back to box 1. Boxes come due every 1, 2, 4, 7, 14 and 30 days.")
                        .font(.footnote)
                }

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("“I have stored up your word in my heart, that I might not sin against you.”")
                            .font(.system(.body, design: .serif).italic())
                        Text("Psalm 119:11")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    LabeledContent("Version", value: appVersion)
                } header: {
                    Text("About Hidden Word")
                }

                Section {
                    Text("Scripture quotations are from the ESV® Bible (The Holy Bible, English Standard Version®), copyright © 2001 by Crossway, a publishing ministry of Good News Publishers. Used by permission. All rights reserved.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Scripture")
                } footer: {
                    Text("Verses you add yourself keep whatever translation you paste.")
                }
            }
            .navigationTitle("Settings")
            .onChange(of: reminderEnabled) { _, isOn in
                if isOn {
                    Task {
                        let granted = await ReminderService.enable(hour: reminderHour, minute: reminderMinute)
                        if !granted {
                            reminderEnabled = false
                            showDenied = true
                        }
                    }
                } else {
                    ReminderService.disable()
                }
            }
            .onChange(of: reminderHour * 60 + reminderMinute) { _, _ in
                if reminderEnabled {
                    ReminderService.schedule(hour: reminderHour, minute: reminderMinute)
                }
            }
            .alert("Notifications are off", isPresented: $showDenied) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("To get a daily reminder, allow notifications for Hidden Word in the Settings app.")
            }
            .confirmationDialog("Reset all progress?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset", role: .destructive) { resetAll() }
            } message: {
                Text("Every verse goes back to box 1 and is due today, and your streak starts over. Your verses are kept.")
            }
        }
    }

    private func resetAll() {
        for verse in verses {
            Leitner.reset(verse)
        }
        streak.reset()
        try? context.save()
    }
}
