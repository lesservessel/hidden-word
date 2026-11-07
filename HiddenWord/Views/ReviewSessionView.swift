import SwiftUI
import SwiftData

/// Walks through a snapshot of today's due verses, one at a time.
struct ReviewSessionView: View {
    @State private var queue: [Verse]
    @State private var index = 0
    @State private var remembered = 0
    @Environment(\.dismiss) private var dismiss

    init(verses: [Verse]) {
        // Snapshot: grading changes due dates, which must not reshuffle this session.
        _queue = State(initialValue: verses)
    }

    var body: some View {
        Group {
            if index < queue.count {
                PracticeView(
                    verse: queue[index],
                    progressLabel: "\(index + 1) of \(queue.count)"
                ) { gotIt in
                    if gotIt { remembered += 1 }
                    withAnimation { index += 1 }
                }
                .id(queue[index].persistentModelID)
            } else {
                finished
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: index)
    }

    private var finished: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
            Text("Done for today")
                .font(.title2.weight(.semibold))
            Text("You remembered \(remembered) of \(queue.count).")
                .foregroundStyle(.secondary)
            Text("“Let the word of Christ dwell in you richly.”")
                .font(.system(.body, design: .serif).italic())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("Colossians 3:16")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Back home") { dismiss() }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
        }
        .padding()
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
    }
}
