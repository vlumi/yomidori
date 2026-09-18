# Changelog

All notable changes to Yomidori are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Grouped by **marketing version** (a roadmap milestone), then by **build number** within it — the version stays steady while the build climbs each TestFlight upload (see [RELEASING.md](RELEASING.md)). The build heading is just `### build N — <date>`; the version comes from the `## vX.Y.Z` above it.

Each version's top section, **Unreleased (next build)**, collects entries merged to `main` but not yet in a TestFlight build; cutting a release renames it to that build's heading and opens a fresh empty one. Keep that heading immediately followed by its list items (no prose between), so the release script can promote it. A user-facing PR writes its own bullet here.

The `## vX.Y.Z` heading is written by the release lane too, whenever a release cuts a new marketing version — so nothing about a version's heading is hand-set.

**One bullet, one line — no hard wrapping.** Editors soft-wrap and rendered Markdown ignores the line breaks, while hard wraps make an edited entry re-flow into a diff nobody can read. **Order the unreleased list by what a reader notices**, not by merge order, and fold entries that tell one story into one bullet.

## v0.1.0

### Unreleased (next build)

- **The book and the page on every kept sentence.** A field above the transcript takes where you are reading, in your own words, and remembers it; each sentence you keep records it, and the card shows it.
- **The system dictionary, one tap away.** Beside a tapped word, on a card and on the back of a review, *Dictionary* opens the phone's own dictionary on the word, スーパー大辞林 when it is installed, for the Japanese meaning; the button appears only when the dictionary has the word.
- **A home screen.** The app opens on its name with one big *Read* button, *Cards* with how many are due, and *About*; the camera starts only when you ask. Reopened after a restart, it returns to the screen you were on.
- **About.** Top left of the camera: the version, the promise that nothing leaves the device, how the pitch line is read, and the licenses and notices of everything bundled, JMdict, Kanjium, MeCab, IPADic and Mecab-Swift.
- **Review what is due.** From *Cards*, *Review* runs the cards whose time has come, one at a time: the sentence from the page with the word marked, then a tap for the reading with its pitch and the meaning, then *Again* or *Good*. The scheduler is FSRS; a new card comes back in three days after a *Good*, tomorrow after an *Again*, and the intervals grow from there. No streaks, no reminders.
- **Keep a word.** Beside a tapped word, *Keep* makes a card of it: the line it stands in as the sentence, with the word marked, and the page it was read from. A word kept again gets another sentence on the same card. *Cards*, top right, lists them and opens each with its reading and pitch, its sentences and its pages; swipe to remove.
- **The pitch over the reading.** A tapped word the dictionary knows shows its reading with the Tokyo pitch accent drawn over it, a line over the high morae dropping where the accent falls, and the downstep number beside it; from Kanjium, built into the app with JMdict.
- **Inflected words find their entry.** A verb or adjective tapped as its stem (頷い, 漂っ, 古く) now opens the entry for its dictionary form (頷く, 漂う, 古い) under *Meaning*, with either tokenizer.
- **The meaning, one fold away.** Under a tapped word, a "Meaning" fold opens its JMdict entries: headword, readings, and the senses' glosses in English; a word with no entry says so, which is what a misread word looks like. JMdict is built into the app from its source at build time.
- **ヨミドリ under the icon** on a phone set to Japanese; Yomidori elsewhere, as on the two storefronts.
- **The frozen page zooms.** Pinch the still to zoom and drag it to pan, in every mode, so a small word is easy to hit; a double tap brings the page back.
- **Words and their readings under the transcript.** The Live Text transcript is shown as its words, each with its reading over it, and a tap shows the word large with its reading and dictionary form; a switch runs the same page through the OS's own analyzer or through MeCab with IPADic, to compare them on real pages, and the transcript copies out with one button.
- **The close-up reads the whole line.** Reading up close now cuts the whole line under the tap out of the still, with the paper around it, instead of a square that halved the glyphs at its edges; a word near the end of a line reads as well as one in the middle.

### build 2 — 2026-09-17

- **The still is the sensor's full frame.** Build 1 froze a preview-sized frame of about a megapixel, which is why small print read so badly; the shutter now keeps the full-resolution frame, and reading up close has real pixels to work with.
- **The camera permission asks in a sentence, in English too.** Build 1 showed English devices the raw key instead of the reason.

### build 1 — 2026-09-17

- **The camera reads the page.** Frame a paperback and press the shutter, or choose a screenshot from the photo library; the still freezes on the screen with every line Vision recognized boxed over it, and a tap on a line reads it out large with the recognizer's confidence. A switch at the bottom shows the same still through Live Text instead, with its transcript and its own text selection, or reads up close: tap a word and a full-resolution square around it is read on its own, by both engines, and shown magnified. Pinch the live view to zoom before the shutter; up close the camera goes macro on phones that have it. Both engines run on the device; the image never leaves it. This is the spike the roadmap starts with: which on-device engine, if either, reads a real page and its vertical columns.
- **The mascot on the icon.** A silver Java sparrow, head-on and mochi-round, perched low on a silver rule with its toes showing, drawn in night green and silver; the placeholder roundel retires.
