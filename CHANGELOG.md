# Changelog

All notable changes to Yomidori are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Grouped by **marketing version** (a roadmap milestone), then by **build number** within it — the version stays steady while the build climbs each TestFlight upload (see [RELEASING.md](RELEASING.md)). The build heading is just `### build N — <date>`; the version comes from the `## vX.Y.Z` above it.

Each version's top section, **Unreleased (next build)**, collects entries merged to `main` but not yet in a TestFlight build; cutting a release renames it to that build's heading and opens a fresh empty one. Keep that heading immediately followed by its list items (no prose between), so the release script can promote it. A user-facing PR writes its own bullet here.

The `## vX.Y.Z` heading is written by the release lane too, whenever a release cuts a new marketing version — so nothing about a version's heading is hand-set.

**One bullet, one line — no hard wrapping.** Editors soft-wrap and rendered Markdown ignores the line breaks, while hard wraps make an edited entry re-flow into a diff nobody can read. **Order the unreleased list by what a reader notices**, not by merge order, and fold entries that tell one story into one bullet.

## v0.1.0

### Unreleased (next build)

- **Reviews are typed.** The reading is typed in kana and checked strictly, as before; the meaning is typed in English and checked leniently against every gloss, a whole gloss or a phrase of one, one typo forgiven. The verdict only suggests the grade: on a miss, *Count it right* takes the point for a typo too broken to forgive, and *Add as an answer* also keeps your wording on the card, where it counts from then on; the card lists your meanings and lets you add or remove them. *Show the answer* gives up on a question. The typed-answer switch is gone, since typing is the way.
- **A card's dates and its record.** A card shows when it was added and last changed (a sentence, a photo, a new sighting; reviews do not count), and how each question has gone, good against again; the list shows how long ago each card changed. Every answer is kept on the card, for the graphs to come. Correcting a sentence and removing photos are plain rows on the card now, where before they hid in a section header.
- **Read first, cards as the front page.** The first tab is the camera itself, live; the bar hides while a page is frozen and the page keeps when you switch tabs. The app opens on Cards: what is due with a Review button on top, the cards under it, Settings and About in the top corner.
- **iOS 26 is the floor.** The app asks for iOS 26; the fallbacks for older systems are gone. Nothing changes on a phone that has it.
- **A tab bar.** Home, Cards and Search are tabs along the bottom; on iOS 26 the search is its own pill that opens into the search field. Cards shows how many are due. Settings and About are the gear and the ⓘ at the top right of home, out of the thumb's way. The camera still opens from the big Read button and hides the bar.
### build 5 — 2026-09-21

- **Settings, with a swipe-back switch.** A Settings screen beside About. Swipe back is on, as everywhere on iOS; off, only the back button leaves a screen, so a swipe meant for a word on the page's left edge never pops you home. The typed-answer switch lives there too, as well as in the review's toolbar.
- **The page stays.** Swiping back to home from a frozen page, by accident or not, and coming back to Read finds the still, its pages, the mode and the zoom as they were left; nothing is read again.
- **Stroke order.** A kanji's screen draws it stroke by stroke over its faint finished form, each stroke numbered; tap to watch again. The data is KanjiVG, built into the bundled dictionary.
- **Three questions per card.** The meaning is always asked now, on its own schedule, so the toggle is gone; and where the dictionary knows the word's pitch, a third question shows every pattern the reading allows, drawn as they would be printed, and you pick the right one.
- **Photos on request, sentences you can fix.** A card keeps the page photo and the crop only while the photo toggle beside the book field is on; off by default. On a card, each sentence has a pencil to correct what the recognizer read (the word is found again in the corrected text) and, where photos were kept, a button to drop them.
- **Kanji, and the words around a word.** A word's screen, on a card or from a search, now lists every reading with its pitch, the meaning, each kanji in the word, the other words read the same way with their pitch side by side (はし: 橋, 箸, 端), and the words it appears in. A kanji opens on its own: on and kun readings, name readings, meanings, stroke count, school grade, JLPT level and frequency, the components it is made of, and the words it is in. The data is KANJIDIC2 and KRADFILE, built into the bundled dictionary.
- **Tap to focus.** A tap on the live image focuses and meters on that spot; when the page moves, the camera goes back to following it.
- **The drawer lies over the page.** Dragging it no longer relays the page out under it, so the drag is smooth and the still keeps its zoom; the page is sized for the drawer at its smallest. A still opens filling the width, its top in view, and two buttons beside it zoom in and out one-handed. Live Text's selection highlight re-measures on every layout and zoom, so it no longer drifts off its word.
- **Every word in a selection.** Select a run of text on the page and each word in it is listed, a compound the dictionary knows (蛍光灯) as one word and an inflected verb under its dictionary form (照らされていた finds 照らす). The meaning opens on a tap anywhere along the word's row; the dictionary and Keep buttons are icons, so a long reading no longer wraps them. Live Text is the recognizer a page opens in.

### build 4 — 2026-09-18

- **A drawer you size yourself.** Under a frozen page, the readout is a drawer with a handle: drag it down for the page while looking for a word, up for the reading and the meaning once found; it remembers. The recognized text sits behind a fold, closed unless you open it.

### build 3 — 2026-09-18

- **A home screen.** The app opens on its name with one big *Read* button, *Cards* with how many are due, and *About*; the camera starts only when you ask. Reopened after a restart, it returns to the screen you were on.
- **About.** Top left of the camera: the version, the promise that nothing leaves the device, how the pitch line is read, and the licenses and notices of everything bundled, JMdict, Kanjium, MeCab, IPADic and Mecab-Swift.
- **Keep a word.** Beside a tapped word, *Keep* makes a card of it: the line it stands in as the sentence, with the word marked, and the page it was read from. A word kept again gets another sentence on the same card. *Cards*, top right, lists them and opens each with its reading and pitch, its sentences and its pages; swipe to remove.
- **What a card keeps.** A kept sentence now runs from full stop to full stop across the page's wrapped lines. *Add next page* on a frozen page takes the next still and reads the two as one text, so a word or a sentence cut by the page turn is whole; the card keeps every page. A kept word's card now carries a crop of the sentence's own lines out of the page, shown under the text on the front of a review; on a vertical page, where lines have no positions yet, the whole page stands in as before. A field above the transcript takes where you are reading, in your own words, and remembers it; each sentence you keep records it, and the card shows it.
- **Review what is due.** From *Cards*, *Review* runs the cards whose time has come, one at a time: the sentence from the page with the word marked, then a tap for the reading with its pitch and the meaning, then *Again* or *Good*. The scheduler is FSRS; a new card comes back in three days after a *Good*, tomorrow after an *Again*, and the intervals grow from there. No streaks, no reminders.
- **Type the reading.** A switch on the review asks for the reading typed in kana instead of tapped; it is checked strictly, katakana counting as hiragana, and the verdict shows with the answer, with the grade it suggests ready to press.
- **Ask the meaning too.** A switch on a card makes it also ask what the word means, as its own question with its own schedule; the reading is shown on that question's front, the senses and the dictionary on its back. Off by default: the reading is what the app is for.
- **Search for a word.** From home, type kana or kanji to find words that start with it, or English to search the meanings; a result shows the word with its pitch and senses, and can be kept as a card that asks for the word alone until a page supplies a sentence.
- **The system dictionary, one tap away.** Beside a tapped word, on a card and on the back of a review, *Dictionary* opens the phone's own dictionary on the word, スーパー大辞林 when it is installed, for the Japanese meaning; the button appears only when the dictionary has the word.
- **The pitch over the reading.** A tapped word the dictionary knows shows its reading with the Tokyo pitch accent drawn over it, a line over the high morae dropping where the accent falls, and the downstep number beside it; from Kanjium, built into the app with JMdict.
- **The meaning, one fold away.** Under a tapped word, a "Meaning" fold opens its JMdict entries: headword, readings, and the senses' glosses in English; a word with no entry says so, which is what a misread word looks like. JMdict is built into the app from its source at build time.
- **Inflected words find their entry.** A verb or adjective tapped as its stem (頷い, 漂っ, 古く) now opens the entry for its dictionary form (頷く, 漂う, 古い) under *Meaning*, with either tokenizer.
- **Words and their readings under the transcript.** The Live Text transcript is shown as its words, each with its reading over it, and a tap shows the word large with its reading and dictionary form; a switch runs the same page through the OS's own analyzer or through MeCab with IPADic, to compare them on real pages, and the transcript copies out with one button.
- **Select a word on the page.** In Live Text mode, a word selected on the page itself, the way text is selected in Photos, is read out below as if tapped in the strip, with its reading, pitch, meaning and Keep, and its line as the sentence. iOS 17 and up; on iOS 16 the words under the transcript remain the way.
- **The frozen page zooms.** Pinch the still to zoom and drag it to pan, in every mode, so a small word is easy to hit; a double tap brings the page back.
- **The volume buttons are a shutter.** Either volume button, or the Camera Control on phones that have one, freezes the page, so the book stays in the other hand. iOS 17.2 and up; before that the shutter is on screen.
- **A third reader up close.** Reading up close now also shows what manga-ocr, an on-device model built for Japanese lines, makes of the few characters around the tap, beside Vision and Live Text; it reads vertical print and bold print where the others stumble. Only in builds that bundle the model.
- **The close-up reads the whole line.** Reading up close now cuts the whole line under the tap out of the still, with the paper around it, instead of a square that halved the glyphs at its edges; a word near the end of a line reads as well as one in the middle.
- **ヨミドリ under the icon** on a phone set to Japanese; Yomidori elsewhere, as on the two storefronts.

### build 2 — 2026-09-17

- **The still is the sensor's full frame.** Build 1 froze a preview-sized frame of about a megapixel, which is why small print read so badly; the shutter now keeps the full-resolution frame, and reading up close has real pixels to work with.
- **The camera permission asks in a sentence, in English too.** Build 1 showed English devices the raw key instead of the reason.

### build 1 — 2026-09-17

- **The camera reads the page.** Frame a paperback and press the shutter, or choose a screenshot from the photo library; the still freezes on the screen with every line Vision recognized boxed over it, and a tap on a line reads it out large with the recognizer's confidence. A switch at the bottom shows the same still through Live Text instead, with its transcript and its own text selection, or reads up close: tap a word and a full-resolution square around it is read on its own, by both engines, and shown magnified. Pinch the live view to zoom before the shutter; up close the camera goes macro on phones that have it. Both engines run on the device; the image never leaves it. This is the spike the roadmap starts with: which on-device engine, if either, reads a real page and its vertical columns.
- **The mascot on the icon.** A silver Java sparrow, head-on and mochi-round, perched low on a silver rule with its toes showing, drawn in night green and silver; the placeholder roundel retires.
