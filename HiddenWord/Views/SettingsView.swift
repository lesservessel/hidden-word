import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("reminder.enabled") private var reminderEnabled = false
    @AppStorage("reminder.hour") private var reminderHour = 7
    @AppStorage("reminder.minute") private var reminderMinute = 0

    @Environment(\.modelContext) private var context
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
            Form {
                Group {
                Section {
                    Toggle("Daily reminder", isOn: $reminderEnabled)
                    if reminderEnabled {
                        DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    FormHeader("Reminder")
                } footer: {
                    FormFooter("Each morning brings that day's verse. Scheduled on this iPhone; nothing is sent anywhere.")
                }

                Section {
                    Button("Restore starter verses") {
                        let added = StarterDeck.insertMissing(context: context)
                        restoreMessage = added == 0
                            ? "All starter verses are already in your deck."
                            : "Added \(added) starter verse\(added == 1 ? "" : "s")."
                    }
                    Button("Start every verse fresh") { confirmReset = true }
                } header: {
                    FormHeader("Verses")
                } footer: {
                    if let restoreMessage {
                        FormFooter(restoreMessage)
                    }
                }

                Section {
                    Text("Verses you mark Hidden come back less and less often. Verses you mark Again soon come back tomorrow. When nothing is ready, rest.")
                        .font(.serif(19, relativeTo: .body))
                        .foregroundStyle(Color.ink)
                        .padding(.vertical, 4)
                } header: {
                    FormHeader("How it works")
                }

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("“I have stored up your word in my heart, that I might not sin against you.”")
                            .font(.serifItalic(20, relativeTo: .body))
                        Eyebrow("Psalm 119:11")
                    }
                    .padding(.vertical, 4)
                    LabeledContent("Version", value: appVersion)
                } header: {
                    FormHeader("About")
                }

                Section {
                    Text("Scripture quotations are from the ESV® Bible (The Holy Bible, English Standard Version®), copyright © 2001 by Crossway, a publishing ministry of Good News Publishers. Used by permission. All rights reserved.")
                        .font(.sans(12, relativeTo: .footnote))
                        .foregroundStyle(Color.muted)
                } header: {
                    FormHeader("Scripture")
                } footer: {
                    FormFooter("Verses you add yourself keep whatever translation you paste.")
                }
                }
                .listRowBackground(Color.wash)
                .font(.serif(19, relativeTo: .body))
                .foregroundStyle(Color.ink)
            }
            .paperScreen()
            .serifTitle("Settings")
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
            .confirmationDialog("Start every verse fresh?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Start fresh") { resetAll() }
            } message: {
                Text("Every verse will come back often again, as if you just added it. Your verses are kept.")
            }
    }

    private func resetAll() {
        for verse in verses {
            Leitner.reset(verse)
        }
        try? context.save()
    }
}
