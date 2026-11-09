import SwiftUI
import WidgetKit

struct VerseEntry: TimelineEntry {
    let date: Date
    let verse: SharedVerses.Item
}

struct VerseProvider: TimelineProvider {
    func placeholder(in context: Context) -> VerseEntry {
        VerseEntry(date: .now, verse: SharedVerses.fallback)
    }

    func getSnapshot(in context: Context, completion: @escaping (VerseEntry) -> Void) {
        completion(entry(for: .now))
    }

    /// One entry per day for a week, each starting at midnight, so the verse turns over
    /// even if the app isn't opened.
    func getTimeline(in context: Context, completion: @escaping (Timeline<VerseEntry>) -> Void) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var entries = [entry(for: .now)]
        for offset in 1...7 {
            if let day = calendar.date(byAdding: .day, value: offset, to: today) {
                entries.append(entry(for: day))
            }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(for date: Date) -> VerseEntry {
        let verse = SharedVerses.verse(for: date, in: SharedVerses.load()) ?? SharedVerses.fallback
        return VerseEntry(date: date, verse: verse)
    }
}

// MARK: - Look

private enum W {
    static let paper = Color(red: 0xFA / 255, green: 0xF9 / 255, blue: 0xF5 / 255)
    static let ink = Color(red: 0x14 / 255, green: 0x14 / 255, blue: 0x13 / 255)
    static let muted = Color(red: 0x5E / 255, green: 0x5D / 255, blue: 0x59 / 255)
    static let glow = Color(red: 0xE9 / 255, green: 0xB4 / 255, blue: 0x4C / 255)

    static func verse(_ size: CGFloat) -> Font { .custom("Cormorant Garamond", size: size).italic() }
    static func label(_ size: CGFloat) -> Font { .custom("Inter", size: size).weight(.medium) }
}

struct VerseWidgetView: View {
    let entry: VerseEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme

    private var ink: Color { scheme == .dark ? W.paper : W.ink }
    private var muted: Color { scheme == .dark ? Color(red: 0xB0 / 255, green: 0xAE / 255, blue: 0xA5 / 255) : W.muted }

    var body: some View {
        switch family {
        case .accessoryInline:
            Text(entry.verse.reference)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.verse.reference.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.2)
                    .widgetAccentable()
                Text(entry.verse.text)
                    .font(.system(size: 13, design: .serif).italic())
                    .lineLimit(3)
            }
        case .systemSmall:
            VStack(alignment: .leading, spacing: 8) {
                Circle().fill(W.glow).frame(width: 7, height: 7)
                    .shadow(color: W.glow.opacity(0.8), radius: 4)
                Text(entry.verse.text)
                    .font(W.verse(15))
                    .foregroundStyle(ink)
                    .lineLimit(5)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 0)
                Text(entry.verse.reference.uppercased())
                    .font(W.label(8))
                    .tracking(1.6)
                    .foregroundStyle(muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        default:
            HStack(alignment: .center, spacing: 16) {
                Circle().fill(W.glow).frame(width: 9, height: 9)
                    .shadow(color: W.glow.opacity(0.8), radius: 5)
                VStack(alignment: .leading, spacing: 8) {
                    Text("“\(entry.verse.text)”")
                        .font(W.verse(19))
                        .foregroundStyle(ink)
                        .lineLimit(5)
                        .minimumScaleFactor(0.7)
                    Text(entry.verse.reference.uppercased())
                        .font(W.label(9))
                        .tracking(2)
                        .foregroundStyle(muted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct VerseWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HiddenWordVerse", provider: VerseProvider()) { entry in
            VerseWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetPaper() }
        }
        .configurationDisplayName("Today’s verse")
        .description("The day’s verse from your Hidden Word deck.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

private struct WidgetPaper: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View { scheme == .dark ? W.ink : W.paper }
}

@main
struct HiddenWordWidgets: WidgetBundle {
    var body: some Widget { VerseWidget() }
}

#Preview(as: .systemMedium) {
    VerseWidget()
} timeline: {
    VerseEntry(date: .now, verse: SharedVerses.fallback)
}
