# CLAUDE.md

Context for Claude Code sessions on Hidden Word. Read `README.md` too: it has the feature list,
project layout, build notes and the App Store checklist.

## What this is

A minimal iOS app for memorizing Scripture (Psalm 119:11). Built by Jonathan as a solo
project and as part of shipping apps end to end with Claude Code. The design idea is a "jar of
clay": plain, quiet and beautiful only because of what it holds. It shares its look with
lesservessel.com.

- iOS 17+, SwiftUI, SwiftData, WidgetKit, Swift 5.
- No accounts, no network, no analytics, no third-party packages. Keep it that way.
- Bundle IDs: `com.lesservessel.HiddenWord`, `com.lesservessel.HiddenWord.Widget`.
  App Group `group.com.lesservessel.HiddenWord`. Team `Y7Z3GSX525`, automatic signing.

## Building and testing

- Work locally on a Mac with Xcode. A Linux cloud session cannot build or run this.
- Build: `xcodebuild -project HiddenWord.xcodeproj -scheme HiddenWord -destination 'platform=iOS Simulator,name=iPhone 16' build`
- Test: same with `test` (tests are in `HiddenWordTests/`: paste cleaner and reminders).
  Pick any installed simulator if iPhone 16 is missing (`xcrun simctl list devices`).
- The Xcode project is hand-written with synchronized folders: new files in existing folders
  are picked up automatically. There is no XcodeGen; do not add a `project.yml`.
- **Pushing to `main` starts Xcode Cloud, which archives and uploads to TestFlight.** Only
  push or merge to `main` when Jonathan asks for a build.

## Design rules (do not drift)

- Colors and fonts live in `HiddenWord/Views/Theme.swift`: `paper`, `ink`, `muted`,
  `hairline`, `wash`, `glow`; `Font.serif` (Cormorant Garamond) for titles and Scripture,
  `Font.sans` (Inter) for small labels and buttons. Use these, not raw colors or system fonts.
- No streaks, counts, "due" badges, mastery scores or gamification. These were removed on
  purpose. Empty state is "Rest. Come back tomorrow." with "Practice anyway".
- Review choices are only "Again soon" and "Hidden".
- Copy is short, calm and plain. Sentence case. No exclamation marks.
- Must hold up at the largest Dynamic Type sizes and in dark mode.

## Code map

- `Logic/PassageCleaner.swift`: turns pasted text from Bible apps/sites into clean verses
  plus reference and translation. Most bug reports land here; add a sample to
  `HiddenWordTests/Samples.swift` and a test for each fix.
- `Logic/Leitner.swift`: six boxes, intervals 1, 2, 4, 7, 14, 30 days.
- `Logic/RecallScorer.swift`, `WordToken.swift`: scoring for Say and Type modes (typo tolerant).
- `Views/PracticeView.swift`: the four modes (Letters, Blanks, Say, Type); mode chosen from
  how well the verse is known. `ReviewSessionView.swift`: session flow, missed verses return
  once at the end.
- `Shared/SharedVerses.swift` must stay identical to `HiddenWordWidget/SharedVerses.swift`.
- `Services/Listener.swift`: on-device speech recognition for Say mode.
- `Services/ReminderService.swift`: daily reminder carrying the day's verse.
- `design/make_icon.swift`: draws the app icons.

## Conventions

- Small, focused commits. Subject line describes the change from the user's view in plain
  English, sentence case, no prefix (e.g. "Search the verses list by reference or words").
  Add a short body when the why isn't obvious.
- Keep `README.md` in sync when features or the checklist change.
- Show Jonathan a short plan and wait for approval before making changes.

## Status (Nov 14, 2026)

Feature-complete v1.0 on `main`, shipping to TestFlight through Xcode Cloud. Recent work: Type
mode shows added words struck through, verse search, missed verses get a second look, practice
adapts to familiarity, widget, reminders, share image, welcome flow.

## Next steps

Work through the README's "Before submitting to the App Store" checklist. The blocker is
**ESV permission** for the starter deck (`Models/StarterDeck.swift`): get Crossway's permission
or swap in a public-domain translation and update the notice in `Views/SettingsView.swift`.
Then test on a real device (Say mode, widget), take screenshots, fill in App Privacy, and
submit.
