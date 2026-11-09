import SwiftUI
import SwiftData

/// Walks through a fixed set of verses, one at a time, then rests.
struct ReviewSessionView: View {
    @State private var queue: [Verse]
    @State private var index = 0
    /// Verses missed once this session come back at the end, a single time.
    @State private var secondLooks: Set<PersistentIdentifier> = []
    @State private var lit = false
    @Environment(\.dismiss) private var dismiss

    private let originalCount: Int

    init(verses: [Verse]) {
        // A snapshot: letting a verse go reschedules it, which must not reshuffle this session.
        _queue = State(initialValue: verses)
        originalCount = verses.count
    }

    var body: some View {
        ZStack {
            if index < queue.count {
                let verse = queue[index]
                let isSecondLook = index >= originalCount
                PracticeView(
                    verse: verse,
                    progress: Double(index) / Double(max(queue.count, 1)),
                    recordsGrade: !isSecondLook
                ) { remembered in
                    if !remembered, !isSecondLook, !secondLooks.contains(verse.persistentModelID) {
                        secondLooks.insert(verse.persistentModelID)
                        queue.append(verse)
                    }
                    withAnimation(.easeInOut(duration: 0.35)) { index += 1 }
                }
                .id("\(verse.persistentModelID.hashValue)-\(index)")
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(y: 12)),
                    removal: .opacity
                ))
            } else {
                finished
                    .transition(.opacity)
            }
        }
        .navigationBarBackButtonHidden(index >= queue.count)
    }

    private var finished: some View {
        VStack(spacing: 0) {
            Spacer()
            VesselMark(size: 170, brightness: lit ? 1 : 0.35)
                .animation(.easeInOut(duration: 1.6), value: lit)
                .padding(.bottom, 36)

            Text("Hidden in your heart.")
                .font(.serif(34, relativeTo: .largeTitle, weight: .medium))
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
                .padding(.bottom, 22)

            Text("“Let the word of Christ dwell in you richly.”")
                .font(.serifItalic(21, relativeTo: .title3))
                .foregroundStyle(Color.muted)
                .multilineTextAlignment(.center)
                .padding(.bottom, 10)
            Eyebrow("Colossians 3:16")

            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.pill)
                .padding(.bottom, 24)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { PaperBackground() }
        .toolbarBackground(.hidden, for: .navigationBar)
        .sensoryFeedback(.success, trigger: lit)
        .task {
            try? await Task.sleep(for: .milliseconds(250))
            lit = true
        }
    }
}
