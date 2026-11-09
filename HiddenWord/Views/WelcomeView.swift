import SwiftUI
import SwiftData

/// Shown once, on first launch. Three quiet pages, then the app.
struct WelcomeView: View {
    let onFinish: (_ withStarterVerses: Bool) -> Void

    @State private var page = 0
    @State private var lit = false
    @AppStorage("reminder.enabled") private var reminderEnabled = false
    @AppStorage("reminder.hour") private var reminderHour = 7
    @AppStorage("reminder.minute") private var reminderMinute = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                treasure.tag(0)
                howItWorks.tag(1)
                begin.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.35), value: page)

            PageDots(count: 3, current: page)
                .padding(.bottom, 12)

            if page < 2 {
                Button("Continue") { withAnimation { page += 1 } }
                    .buttonStyle(.pill(filled: true, wide: true))
                    .frame(maxWidth: 360)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 20)
                    .transition(.opacity)
            }
        }
        .background { PaperBackground() }
        .sensoryFeedback(.selection, trigger: page)
        .task {
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation(.easeInOut(duration: 2)) { lit = true }
        }
    }

    // MARK: Pages

    private var treasure: some View {
        VStack(spacing: 0) {
            Spacer()
            VesselMark(size: 180, brightness: lit ? 0.95 : 0.0)
                .padding(.bottom, 44)
            Text("Hidden Word")
                .font(.serif(44, relativeTo: .largeTitle, weight: .medium))
                .foregroundStyle(Color.ink)
                .padding(.bottom, 24)
            Text("“But we have this treasure in jars of clay, to show that the surpassing power belongs to God and not to us.”")
                .font(.serifItalic(21, relativeTo: .title3))
                .foregroundStyle(Color.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 12)
            Eyebrow("2 Corinthians 4:7")
            Spacer()
        }
        .padding(.horizontal, 36)
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 34) {
            Spacer()
            Eyebrow("How it works")
            step("Paste", "Copy a verse from any Bible app. The numbers and headings fall away.")
            step("Practice", "A few minutes a day: first letters, blanks, saying it aloud, or writing it out.")
            step("Let it go", "Mark it Hidden and it comes back less and less often. Nothing to keep up with.")
            Spacer()
        }
        .padding(.horizontal, 36)
        .frame(maxWidth: 560)
    }

    private func step(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.serif(30, relativeTo: .title, weight: .medium))
                .foregroundStyle(Color.ink)
            Text(body)
                .font(.serif(20, relativeTo: .body))
                .foregroundStyle(Color.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var begin: some View {
        VStack(spacing: 0) {
            Spacer()
            Text("Begin")
                .font(.serif(40, relativeTo: .largeTitle, weight: .medium))
                .foregroundStyle(Color.ink)
                .padding(.bottom, 14)
            Text("Start with twelve verses about the potter and the clay, or with an empty vessel.")
                .font(.serifItalic(21, relativeTo: .title3))
                .foregroundStyle(Color.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 36)

            VStack(spacing: 12) {
                Button("Twelve vessel verses") { finish(true) }
                    .buttonStyle(.pill(filled: true, wide: true))
                Button("An empty vessel") { finish(false) }
                    .buttonStyle(.pill(wide: true))
            }
            .frame(maxWidth: 360)

            Toggle(isOn: $reminderEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("A gentle daily reminder")
                        .font(.serif(19, relativeTo: .body))
                        .foregroundStyle(Color.ink)
                    Text("7:00 each morning. Change it any time.")
                        .font(.sans(12, relativeTo: .caption))
                        .foregroundStyle(Color.muted)
                }
            }
            .tint(Color.ink)
            .frame(maxWidth: 360)
            .padding(.top, 34)
            .onChange(of: reminderEnabled) { _, on in
                guard on else { ReminderService.disable(); return }
                Task {
                    if !(await ReminderService.enable(hour: reminderHour, minute: reminderMinute)) {
                        reminderEnabled = false
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private func finish(_ starter: Bool) {
        onFinish(starter)
    }
}

private struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Color.ink : Color.hairline.opacity(0.6))
                    .frame(width: i == current ? 16 : 5, height: 5)
            }
        }
        .animation(.snappy(duration: 0.25), value: current)
        .accessibilityElement()
        .accessibilityLabel("Page \(current + 1) of \(count)")
    }
}
