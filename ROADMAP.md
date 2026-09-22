# Roadmap

The implementation plan, as **named milestones in rough order** — and *only open work*. This file is *expected to churn*: milestones get reshaped as prototyping answers questions. As work ships it leaves this file — brief summaries go to the [README version history](README.md#version-history), full detail to [CHANGELOG.md](CHANGELOG.md), and settled rules and design decisions to [ARCHITECTURE.md](ARCHITECTURE.md). This file is only *when*, not *why*.

**No hard line wraps** — one paragraph or bullet, one line; editors soft-wrap and rendered Markdown ignores the breaks anyway.

**Milestones are not version numbers.** A version is assigned when a milestone is *cut*, not when it is planned — some of these will be reordered, split, or dropped outright, and renumbering the rest each time is the churn that stops a roadmap being updated at all.

Guiding order: **the tap is the app**, and **what comes early is whatever answers a question that changes the plan**.

Done so far: the bootstrap (committed directly to `main` before the PR rule took effect) — the repo with the siblings' toolchain, XcodeGen project, Swift package split into Core and Kit, SwiftLint + swift-format, CI with coverage, the four-step release lane, a `Kana` helper with tests and a generated placeholder icon — and the spike's capture screen, which runs both of the OS's recognizers over a still.

## The spike — *does the camera read a paperback?*

The whole idea rests on on-device text recognition reading real books: vertical columns, small serif print on cream paper, a lamp. Nothing else is worth building until this is known.

- [ ] **The recognizers on real pages.** *Answered on a paperback (2026-09-21): Live Text reads the vertical Mincho columns of a novel, and its own selection over the still is the tap; Vision misreads the same pages and stays only for the line positions the sentence crop needs, until Live Text or manga-ocr can give positions, after which it goes.* Still to measure: how often a selected word's characters come back wrong, and manga-ocr's speed on the phone.
- [ ] **A second opinion on the line.** *Built in first form: manga-ocr converted to Core ML (encoder as it is, decoder re-expressed as a cache-free step; ~210 MB at half precision, MIT), read over a window of about eight characters around the tap in Close-up, beside Vision and Live Text. Measured on rendered lines before conversion: 12 of 13 short windows exact, Mincho, vertical and blurred alike, and 樹皮 right on the bold packaging line both Apple engines misread; whole long lines squeezed into its 224 pixels fail, hence the window. Optional at build (`make models`). Still to try on the phone: speed, and the same words as before.*
- [ ] **Tokenizer choice.** Feed the recognized lines to the candidates in [ARCHITECTURE.md](ARCHITECTURE.md) — MeCab with UniDic or IPADIC, Apple's tokenizer with JMdict furigana data — and compare segmentation on OCR output that has a wrong character here and there, the reading quality, the bundle size, and the licensing chores. One of them becomes the dependency; the table in ARCHITECTURE becomes a decision. *Measured on the Mac (2026-09-18), on a fixture of thirteen literary sentences with hard readings:* the OS's own analyzer, reached through `CFStringTokenizer` with its Latin transcription turned back to kana, and MeCab with UniDic-lite cut every sentence identically and gave the same reading for every word, in context (生地 きじ beside 生 なま, 頷い うなずい, 相槌 あいづち, 椨 たぶのき). The system analyzer is in Core now as `SystemTokenizer`, with the fixture as its tests. What MeCab adds is the dictionary form (UniDic normalizes it: 点ける becomes 付ける, which a card key would not want) and the accent type per word; what it costs is a C library, a dictionary of tens of megabytes and its license. Recommended: the system analyzer for cutting and readings, JMdict for the dictionary form and meanings, Kanjium for pitch, no third-party code at runtime; the deinflection from a cut stem to its JMdict headword is the one piece to write. Both tokenizers are in the app now, switched under the Live Text transcript, each word shown with its reading and, from MeCab, its dictionary form, so the comparison continues on real pages. Still to try: OCR output with a wrong character in it, and the real book's sentences.

## Freeze & tap — *the reading, one-handed*

- [ ] **Freeze the page.** Camera view that only frames; shutter on screen (done), on the volume buttons and on the Camera Control (done); the still is what everything works on, pinch to zoom (done, with macro up close on phones that have it).
- [ ] **Tap a word.** A tap anywhere on a token highlights the whole token, vertical or horizontal; a second tap on a neighbor extends over a compound. The reading appears in a bottom sheet in large kana, meaning collapsed under it. The recognized characters are editable in the sheet; the transcript copies out (done). The frozen still pinches to zoom and pans, so a small word is easy to hit (done). *First form on the page itself: a word selected on the still through Live Text's own selection is shown in the readout as if tapped in the strip, with its line as the sentence; still to do is the app's own tap-to-token highlight, which needs positions Live Text does not give.*
- [ ] **Reach.** Everything touchable in the thumb's arc; the page can be swiped so the top of a column comes down.
- [ ] **A screenshot as the still.** *Later; the photo picker covers the case for now.* Reading on the same device — an e-book app, a web page — the still comes from a screenshot instead of the camera: the photo picker inside the app first, then a share extension so Share → Yomidori from the screenshot preview lands straight on the freeze-and-tap screen. Everything after the still is the same code, the vertical columns of an e-book novel included; screenshots are only sharper than any camera frame.

## Cards — *the word keeps working*

- [ ] **One card per word.** Dictionary form as the key; the sentence from the page as the front, OCR text plus the crop; reading, pitch and the collapsed meaning on the back; book and page recorded. A second sighting adds a sentence, never a card. *Done in first form: Keep on the tapped word saves the page's line as the sentence and the whole still beside it; the cards screen lists the words and shows each card with its sightings. Still to do: the crop of the line rather than the whole still.*
- [ ] **Review.** FSRS with two grades; the queue is what is due when the app opens; no streaks, no reminders. *Done: FSRS-5 with its default parameters at 90 % retention, Again and Good, the queue from the Cards screen; three questions per card, reading, meaning and pitch, each on its own schedule.*
- [ ] **Stills stitched into one page**, later, not for the first prototype. The visual side of the same glue: consecutive stills laid out as one canvas in reading order — a vertical page continues to the left of the previous, a horizontal one below — so the sentence is seen to flow while its continuation is tapped. The gap between them is trimmed by what Vision recognized, each still cropped to its text block plus a margin, which drops page margins, running heads and an e-reader's chrome without guessing at empty pixels; the seam stays visible as a thin line, the raw frames remain an option, and the originals stay on the card either way.

## Dictionary — *meaning on request*


## Pitch & sound — *the part dictionaries lack*

- [ ] **Sentence contour and speech**, later and offline: accent phrases from Open JTalk's estimation or UniDic's connection rules, spoken through VOICEVOX, generated on a Mac and bundled or skipped — nothing runs a model on the phone.

## Mac — *the same cards on a keyboard*

Decided 2026-09-18: a Mac app is wanted, after the phone's recognizer question is settled, since the Mac inherits whatever that decides. Core is pure and the Kit already compiles on macOS, so the cost is the input, the sync and a target.

- [ ] **Cards that follow.** iCloud sync of the one JSON document and the stills, so a card kept on the phone is reviewed on the Mac and the other way round; conflicts merged by sightings and reviews, never by picking a side. The prerequisite for the rest of this section, and it serves an iPad too.
- [ ] **A Mac target.** No camera: a pasted sentence goes straight to the tokenizer, a pasted or dropped screenshot goes through Live Text as on the phone, with the Mac's own selection overlay on the image. Same bundle id under the same App Store record. The release lane's macOS scope, inherited from the siblings, comes back into use.
- [ ] **Review on a keyboard.** Space to reveal, two keys to grade. *The typed-answer mode is built and works on every platform already: the reading typed in kana and checked strictly, katakana and half-width folded, long vowels not forgiven; every review a few words of kana typing on vocabulary actually met. What remains is the Mac's own keys.* A typing tutor proper, with drills and speed, is a different product and stays out.

## Store — *out the door*

- [ ] **Japanese interface** completed and reviewed by a native ear; the ヨミドリ storefront name.
- [ ] **Listing tooling** copied from the siblings when a listing exists to sync: `Scripts/asc/` and `make shots`.
- [ ] **TestFlight, then the App Store.** Privacy answers are all "no" except the camera, which is used on device and never uploaded.

## Ideas to evaluate — *not scheduled*

- [ ] **Generated example sentences.** A word's card could carry sentences built from only the words the reader already knows, generated by a language model on a Mac and synced, never on the phone. Worth trying once a few hundred cards exist and the book's own sentences have shown what they lack.
- [ ] **国語 mode for Japanese schoolchildren.** The same tap, cards turned around: read the kanji in the sentence, write it from the reading on a stroke canvas. The data is free and official — MEXT's grade-by-grade kanji lists, the 常用漢字表, KanjiVG stroke order, Aozora Bunko texts with furigana, BCCWJ's textbook frequencies. Meaning stays out, since no good monolingual children's dictionary is free. Apple's Kids Category rules are already met by the local-only design.
- [ ] **Finnish interface**, a strings file away, once there is Finnish content worth the promise.

## Deliberately out of scope

Per [ARCHITECTURE.md](ARCHITECTURE.md): no server, no accounts, no analytics, no ads, no network at runtime, no cloud model. No furigana over the whole page and no page translation, ever — help only where asked. No watch or TV target; the Mac has its own section above. No third-party runtime code beyond the one tokenizer decision.
