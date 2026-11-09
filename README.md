# Hidden Word

> “I have stored up your word in my heart, that I might not sin against you.” (Psalm 119:11)

A minimal iOS app for hiding Scripture in your heart. The app itself is meant to be a jar of
clay: plain, quiet and beautiful only because of what it holds. It shares its look with
[lesservessel.com](https://lesservessel.com): warm paper, near-black ink, Cormorant Garamond
and Inter.

iOS 17+, SwiftUI, SwiftData, WidgetKit. No accounts, no network, no third-party code.

## What it does

- **Paste a verse or a passage** from any Bible app or website. Verse numbers, headings,
  footnote marks, share links and site buttons are removed, and the reference and translation
  are filled in. A passage can be kept whole or saved as one card per verse.
- **One button: Start review.** No streaks, no counts, no "due". When nothing is ready the app
  says *Rest. Come back tomorrow.* and offers *Practice anyway*.
- **Four ways to practice:** Letters (first letters), Blanks (words fall away), Say (recite
  aloud; each word appears as it is heard, on device), Type (write it out, forgiving typos).
  A verse opens in the mode that fits how well you know it.
- **Two gentle choices: Again soon / Hidden.** Spaced repetition underneath (1, 2, 4, 7, 14, 30
  days). A missed verse gets one more look at the end of the session.
- **Today's verse** on the home screen, in a home and lock-screen widget, and in the optional
  daily reminder.
- **Share a verse** as a 1080×1080 image on paper or ink.
- A three-page welcome on first launch; twelve "vessel" verses to start, or none.

## Project layout

```
HiddenWord.xcodeproj       Hand-written project; folders are synchronized, so new files are
                           picked up automatically. No XcodeGen.
HiddenWord/
  App/                     App entry, root view, launch repair of garbled text
  Logic/                   PassageCleaner (paste cleanup), Leitner, RecallScorer, WordToken
  Models/                  Verse (SwiftData), StarterDeck
  Services/                ReminderService, Listener (speech)
  Shared/                  SharedVerses + WidgetSync (data handed to the widget)
  Views/                   Theme, Vessel, Home, Practice, Session, Deck, Editor, Share, Welcome
  Resources/               Fonts (OFL licenses included), assets, privacy manifest
HiddenWordWidget/          Today's verse widget (keep SharedVerses.swift identical to the app's)
HiddenWordTests/           Paste-cleaner and reminder tests (Cmd-U)
design/                    App icon (black and cream) and the script that draws them
```

## Building

Open `HiddenWord.xcodeproj` in Xcode and run. Signing is automatic for team `Y7Z3GSX525`.
The app and widget share the App Group `group.com.lesservessel.HiddenWord`; the first signed
build registers it and the widget's bundle ID (`com.lesservessel.HiddenWord.Widget`).

Pushing to `main` starts Xcode Cloud, which archives and sends the build to TestFlight.

## Before submitting to the App Store

- [ ] **ESV permission.** The starter deck bundles ESV text. Ask Crossway's permissions team,
      or swap the deck in `Models/StarterDeck.swift` for a public-domain translation and
      update the notice in `Views/SettingsView.swift`. Pasted verses are the user's own.
- [ ] Re-check each starter verse against esv.org (entered by hand).
- [ ] Try Say mode on a real iPhone (the simulator has no microphone).
- [ ] Add the widget on a device and confirm it shows the day's verse.
- [ ] Screenshots: Home, Practice (Blanks), Add a verse, Share card, widget.
- [ ] App Privacy: **Data Not Collected**. Privacy policy and support URLs.
- [ ] Age rating 4+; category Reference (secondary: Lifestyle).
- [ ] Description and keywords: scripture memory, memorize Bible verses, Psalm 119.
