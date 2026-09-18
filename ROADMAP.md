# Roadmap

The implementation plan, as **named milestones in rough order** — and *only open work*. This file is *expected to churn*: milestones get reshaped as prototyping answers questions. As work ships it leaves this file — brief summaries go to the [README version history](README.md#version-history), full detail to [CHANGELOG.md](CHANGELOG.md), and settled rules and design decisions to [ARCHITECTURE.md](ARCHITECTURE.md). This file is only *when*, not *why*.

**No hard line wraps** — one paragraph or bullet, one line; editors soft-wrap and rendered Markdown ignores the breaks anyway.

**Milestones are not version numbers.** A version is assigned when a milestone is *cut*, not when it is planned — some of these will be reordered, split, or dropped outright, and renumbering the rest each time is the churn that stops a roadmap being updated at all.

Guiding order: **the tap is the app**, and **what comes early is whatever answers a question that changes the plan**.

Done so far: the bootstrap (committed directly to `main` before the PR rule took effect) — the repo with the siblings' toolchain, XcodeGen project, Swift package split into Core and Kit, SwiftLint + swift-format, CI with coverage, the four-step release lane, a `Kana` helper with tests and a generated placeholder icon — and the spike's capture screen, which runs both of the OS's recognizers over a still.

## The spike — *does the camera read a paperback?*

The whole idea rests on on-device text recognition reading real books: vertical columns, small serif print on cream paper, a lamp. Nothing else is worth building until this is known.

- [ ] **Vision on real pages.** The capture screen is built: shutter or a picked screenshot, a still, and both on-device recognizers over it — Vision's `VNRecognizeTextRequest` for Japanese with its lines drawn back over the photo, and VisionKit's Live Text engine with its transcript and selection. Still to do: try it on the paperbacks actually being read, in the light they are read in, and measure how often the tapped word's characters come back right, and how vertical text fares. *First result, on a rendered page (macOS 26, Vision revision 3, the one iOS 16 ships):* Vision read the horizontal page perfectly and the vertical columns not at all, rotated a quarter turn either way or not; Live Text read both perfectly. *On the phone, horizontal print so far:* both engines read a line of packaging text, and both misread 樹皮 as 街皮 at page scale; zoomed in on the word, Live Text read it right and Vision guessed something unrelated. Pixels per character decide, so the spike screen gained a close-up mode that reads a full-resolution square around the tap. Then the still's size caption gave the game away: every still so far was 1170 × 1560, a preview-sized frame the video output delivers by default under the photo preset, so no reading yet has seen the sensor's pixels. Fixed; the same word and a novel's Mincho are to be tried again at 4032 × 3024. Live Text gives no positions, only a transcript and its own tap-to-select over the image, so if the book confirms this the tap becomes Live Text's selection, or the position comes from elsewhere — `DataScannerViewController` uses the same engine and returns bounds, but only live from the camera, not on a still. The result decides whether the design below stands, needs zoom-before-capture, or needs that different recognizer.
- [ ] **A second opinion on the line.** A Japanese OCR model bundled in the app, on device like everything else, run over the tapped line beside Live Text, so a doubtful kanji has two readings to agree or disagree on, and a third engine where Apple's fall short. The candidate to convert to Core ML and try on the same crops is manga-ocr (MIT, about 110 MB, a line reader built for Japanese, vertical included); its size and license get the write-up the tokenizer's dependency gets.
- [ ] **Tokenizer choice.** Feed the recognized lines to the candidates in [ARCHITECTURE.md](ARCHITECTURE.md) — MeCab with UniDic or IPADIC, Apple's tokenizer with JMdict furigana data — and compare segmentation on OCR output that has a wrong character here and there, the reading quality, the bundle size, and the licensing chores. One of them becomes the dependency; the table in ARCHITECTURE becomes a decision. *Measured on the Mac (2026-09-18), on a fixture of thirteen literary sentences with hard readings:* the OS's own analyzer, reached through `CFStringTokenizer` with its Latin transcription turned back to kana, and MeCab with UniDic-lite cut every sentence identically and gave the same reading for every word, in context (生地 きじ beside 生 なま, 頷い うなずい, 相槌 あいづち, 椨 たぶのき). The system analyzer is in Core now as `SystemTokenizer`, with the fixture as its tests. What MeCab adds is the dictionary form (UniDic normalizes it: 点ける becomes 付ける, which a card key would not want) and the accent type per word; what it costs is a C library, a dictionary of tens of megabytes and its license. Recommended: the system analyzer for cutting and readings, JMdict for the dictionary form and meanings, Kanjium for pitch, no third-party code at runtime; the deinflection from a cut stem to its JMdict headword is the one piece to write. Both tokenizers are in the app now, switched under the Live Text transcript, each word shown with its reading and, from MeCab, its dictionary form, so the comparison continues on real pages. Still to try: OCR output with a wrong character in it, and the real book's sentences.

## Freeze & tap — *the reading, one-handed*

- [ ] **Freeze the page.** Camera view that only frames; shutter on screen (done), on the volume button and on the Camera Control; the still is what everything works on, pinch to zoom (done, with macro up close on phones that have it).
- [ ] **Tap a word.** A tap anywhere on a token highlights the whole token, vertical or horizontal; a second tap on a neighbor extends over a compound. The reading appears in a bottom sheet in large kana, meaning collapsed under it. The recognized characters are editable in the sheet, and the transcript can be copied out. The frozen still pinches to zoom and pans, so a small word is easy to hit.
- [ ] **Reach.** Everything touchable in the thumb's arc; the page can be swiped so the top of a column comes down.
- [ ] **A screenshot as the still.** Reading on the same device — an e-book app, a web page — the still comes from a screenshot instead of the camera: the photo picker inside the app first, then a share extension so Share → Yomidori from the screenshot preview lands straight on the freeze-and-tap screen. Everything after the still is the same code, the vertical columns of an e-book novel included; screenshots are only sharper than any camera frame.

## Cards — *the word keeps working*

- [ ] **One card per word.** Dictionary form as the key; the sentence from the page as the front, OCR text plus the crop; reading, pitch and the collapsed meaning on the back; book and page recorded. A second sighting adds a sentence, never a card.
- [ ] **Review.** FSRS with two grades; the queue is what is due when the app opens; no streaks, no reminders. Readings by default, meaning cards as an option per word.
- [ ] **Two pages, one sentence.** "Continues on next page" in the capture flow, for two shutters and for two screenshots alike: a sentence left open waits for the next still, shared or picked, and its continuation is tapped there; the fragments are joined and re-tokenized, both crops kept.
- [ ] **Stills stitched into one page**, later, not for the first prototype. The visual side of the same glue: consecutive stills laid out as one canvas in reading order — a vertical page continues to the left of the previous, a horizontal one below — so the sentence is seen to flow while its continuation is tapped. The gap between them is trimmed by what Vision recognized, each still cropped to its text block plus a margin, which drops page margins, running heads and an e-reader's chrome without guessing at empty pixels; the seam stays visible as a thin line, the raw frames remain an option, and the originals stay on the card either way.

## Dictionary — *meaning on request*

- [ ] **The system dictionary.** A button on the sheet opens the built-in 大辞林 entry through the reference library view; the app shows it only when the dictionary is installed and has the term.
- [ ] **Typed search.** For words met off the page: kana and kanji search headwords, Latin searches JMdict glosses; results become cards the same way.
- [ ] **Attribution screen.** JMdict, the tokenizer's dictionary, Kanjium: the credits each license requires, on the About screen from the first build that bundles them.

## Pitch & sound — *the part dictionaries lack*

- [ ] **Word pitch.** The accent type or downstep number from the dictionary, drawn over the kana of the reading; notation decided once for the whole app.
- [ ] **Sentence contour and speech**, later and offline: accent phrases from Open JTalk's estimation or UniDic's connection rules, spoken through VOICEVOX, generated on a Mac and bundled or skipped — nothing runs a model on the phone.

## Store — *out the door*

- [ ] **Japanese interface** completed and reviewed by a native ear; the ヨミドリ storefront name.
- [ ] **Listing tooling** copied from the siblings when a listing exists to sync: `Scripts/asc/` and `make shots`.
- [ ] **TestFlight, then the App Store.** Privacy answers are all "no" except the camera, which is used on device and never uploaded.

## Ideas to evaluate — *not scheduled*

- [ ] **Generated example sentences.** A word's card could carry sentences built from only the words the reader already knows, generated by a language model on a Mac and synced, never on the phone. Worth trying once a few hundred cards exist and the book's own sentences have shown what they lack.
- [ ] **国語 mode for Japanese schoolchildren.** The same tap, cards turned around: read the kanji in the sentence, write it from the reading on a stroke canvas. The data is free and official — MEXT's grade-by-grade kanji lists, the 常用漢字表, KanjiVG stroke order, Aozora Bunko texts with furigana, BCCWJ's textbook frequencies. Meaning stays out, since no good monolingual children's dictionary is free. Apple's Kids Category rules are already met by the local-only design.
- [ ] **iCloud sync** for the same cards on an iPad.
- [ ] **Finnish interface**, a strings file away, once there is Finnish content worth the promise.

## Deliberately out of scope

Per [ARCHITECTURE.md](ARCHITECTURE.md): no server, no accounts, no analytics, no ads, no network at runtime, no cloud model. No furigana over the whole page and no page translation, ever — help only where asked. No Mac, watch or TV target. No third-party runtime code beyond the one tokenizer decision.
