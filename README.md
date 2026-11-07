# Hidden Word

A small SwiftUI app for memorizing Scripture. Builder milestone, app #3. Target: App Store
submission around Nov 21.

> “I have stored up your word in my heart, that I might not sin against you.” (Psalm 119:11)

iOS 17+, SwiftUI, SwiftData, `@Observable`. No accounts, no network, no third-party code.

## Features

- **Deck of verses.** Add a verse by pasting it from your Bible app (the Paste button never shows
  the "allow paste" prompt). If the reference comes along on its own first or last line, as
  YouVersion and most apps copy it, it is filled in for you, and a trailing translation tag like
  `ESV` goes into the Translation field. Share links are dropped. Edit, swipe to delete.
- **Starter deck: twelve "vessel" verses (ESV).** Isaiah 64:8, Jeremiah 18:4, Romans 9:21,
  2 Corinthians 4:7, 2 Corinthians 12:9, John 3:30, Genesis 1:27, 2 Timothy 2:21,
  Philippians 2:7, Ephesians 2:10, Romans 8:29, Matthew 5:16. Inserted once on first launch;
  Settings > Restore starter verses adds back any you deleted.
- **Three practice modes** (segmented picker, last choice remembered):
  1. **Letters**: each word shown as its first letter plus punctuation (`w.”`). Tap a word to
     reveal it, or Reveal all.
  2. **Blanks**: read the verse, then tap Hide more. Each of 5 rounds hides another 20% of the
     words in random order until all are blank. Tap a blank to peek.
  3. **Type**: type the verse from memory and tap Check. Scored word by word, ignoring case,
     punctuation and curly quotes, forgiving one typo in words of 4+ letters (two in 8+).
     Score = matched words / max(verse words, typed words). Missed words are shown in orange.
- **Spaced repetition (Leitner).** Six boxes due every 1, 2, 4, 7, 14 and 30 days. New verses
  start in box 1, due today. "Got it" moves up a box; "Missed it" sends the verse back to box 1,
  due tomorrow. You grade yourself after any mode.
- **Today tab.** Due today count, day streak, mastered count (box 6), a Start review button that
  walks through every due verse, and Today's verse (rotates through the deck one per day).
- **Daily streak.** Any graded verse counts for the day. The streak survives until the end of the
  day after your last practice.
- **Daily reminder (optional, off by default).** One repeating local notification at the time you
  pick in Settings. Permission is asked only when you turn it on.
- **Home-screen widget: skipped for v0.** A widget needs a second target, an App Group and a
  shared SwiftData store location. That is a lot of plumbing to get right without a compiler,
  so it is left for v1.1.

## Scripture text and ESV licensing (read before shipping)

The starter deck quotes the ESV word for word, and the app shows this notice in Settings:

> Scripture quotations are from the ESV® Bible (The Holy Bible, English Standard Version®),
> copyright © 2001 by Crossway, a publishing ministry of Good News Publishers. Used by
> permission. All rights reserved.

Crossway allows limited quotation of the ESV without asking (with the notice above), but its
permission terms are written for printed and similar works. An app that **bundles** ESV text may
need written permission or a license. Before submitting:

1. Check the current terms at esv.org / crossway.org (Permissions) and email Crossway's
   permissions team describing the app: 12 verses bundled, no network, free or paid.
2. Re-check each starter verse against esv.org; the text was entered by hand.
3. If permission is not granted in time, swap the deck. Everything lives in one file,
   `HiddenWord/Models/StarterDeck.swift`: change `translation` and the `verses` array, for example
   to a public-domain translation (KJV, WEB). Then update the notice in
   `HiddenWord/Views/SettingsView.swift` (Scripture section) and this README. No other code
   depends on the wording.

Verses the user pastes in themselves are their own business; the app never fetches text.

## Project layout

```
project.yml                       XcodeGen spec (generates HiddenWord.xcodeproj)
HiddenWord/
  Info.plist                      Display name, portrait only
  App/HiddenWordApp.swift         @main, SwiftData container, tabs, first-launch seeding
  Models/Verse.swift              @Model: reference, text, translation, Leitner box, due date
  Models/StarterDeck.swift        The 12 bundled verses (swap here)
  Logic/Leitner.swift             Box intervals, grading, due check
  Logic/StreakStore.swift         @Observable daily streak (UserDefaults)
  Logic/WordToken.swift           Splits a verse into words + punctuation
  Logic/RecallScorer.swift        Fuzzy word alignment for Type mode
  Services/ReminderService.swift  UNUserNotificationCenter daily reminder
  Views/                          Home, ReviewSession, Practice (3 modes), Deck, VerseEditor,
                                  Settings, FlowLayout
  Resources/Assets.xcassets       AppIcon (empty slot), AccentColor (clay)
  Resources/PrivacyInfo.xcprivacy
```

## Mac setup

1. Install Xcode 15.3 or newer (Xcode 16 is fine) and open it once to install components.
2. Install XcodeGen and generate the project:
   ```sh
   brew install xcodegen
   cd hidden-word
   xcodegen
   open HiddenWord.xcodeproj
   ```
3. Select the **HiddenWord** target > **Signing & Capabilities** and pick your team (or set
   `DEVELOPMENT_TEAM` in `project.yml` and re-run `xcodegen`). Change the bundle ID
   `com.jonathan.HiddenWord` if it is taken. No extra capabilities are needed; local
   notifications do not need an entitlement.
4. Build and run. The simulator covers everything; the reminder is easiest to test on a device.
   The code was written without a compiler, so fix any small errors Xcode reports on the
   first build.

Regenerate with `xcodegen` whenever you add or remove files. The `.xcodeproj` is git-ignored.

## Test before submitting

- First launch: 12 verses in Deck, Today shows 12 due, streak 0.
- Start review: grade a few Got it and a few Missed it. Done screen shows the count. Today's due
  count drops, streak = 1 with a filled flame. Deck rows show box dots and new due dates.
- Each mode: Letters reveals on tap; Blanks hides all words by round 5 and peeks on tap; Type
  gives ~100% for an exact copy, a high score with one typo, low for a wrong verse.
- Add a verse by pasting "John 3:30 ESV" on one line and the text below; reference and
  translation fill in. Edit it, delete it.
- Settings: turn on the reminder, allow notifications, set a time a minute ahead, lock the
  phone. Turn it off. Deny permission once and confirm the toggle flips back with an alert.
- Restore starter verses after deleting one; Reset all progress.
- Dark mode, largest Dynamic Type, VoiceOver on the practice screens.

## App Store checklist

- [ ] ESV permission settled, or starter deck swapped (see above). This is the one real blocker.
- [ ] App icon: add a 1024×1024 PNG to `AppIcon.appiconset` (no transparency).
- [ ] Bundle ID and team set; version 1.0 (1).
- [ ] App Store Connect record: name "Hidden Word" (check availability; fall back to
      "Hidden Word: Scripture Memory"), subtitle, category Reference (secondary: Education
      or Lifestyle).
- [ ] Screenshots for 6.9" and 6.5" iPhone: Today, Letters mode, Type result, Deck.
- [ ] Privacy: App Privacy = **Data Not Collected**. `PrivacyInfo.xcprivacy` declares
      no tracking, no collected data, and UserDefaults (reason CA92.1).
- [ ] Privacy policy URL (required even with no data collected): a one-paragraph page saying
      everything stays on the device.
- [ ] Support URL.
- [ ] Export compliance: `ITSAppUsesNonExemptEncryption` is already `false` in Info.plist.
- [ ] Age rating questionnaire: all "None" (4+).
- [ ] Description and keywords (scripture memory, Bible verses, memorize, flashcards,
      spaced repetition, Psalm 119).
- [ ] Archive in Xcode > Distribute > App Store Connect; TestFlight build on your own phone
      for a few days before submitting for review.

## Later

- Home-screen widget with today's verse (App Group + shared store).
- Optional public-domain deck packs; import from a text list.
- Per-verse history and a calendar of practice days.
