# Roadmap

The implementation plan, as **named milestones in rough order** — and *only open work*. This file is *expected to churn*: milestones get reshaped as prototyping answers questions. As work ships it leaves this file — brief summaries go to the [README version history](README.md#version-history), full detail to [CHANGELOG.md](CHANGELOG.md), and settled rules and design decisions to [ARCHITECTURE.md](ARCHITECTURE.md). This file is only *when*, not *why*.

**No hard line wraps** — one paragraph or bullet, one line; editors soft-wrap and rendered Markdown ignores the breaks anyway.

**Milestones are not version numbers.** A version is assigned when a milestone is *cut*, not when it is planned — some of these will be reordered, split, or dropped outright, and renumbering the rest each time is the churn that stops a roadmap being updated at all.

Guiding order: **the tap is the app**, and **what comes early is whatever answers a question that changes the plan**.

Done so far (the bootstrap, committed directly to `main` before the PR rule took effect): the repo with the siblings' toolchain — XcodeGen project, Swift package split into Core and Kit, SwiftLint + swift-format, CI with coverage, the four-step release lane — and a first screen with the name, a `Kana` helper with tests, and a generated placeholder icon.

## The spike — *does the camera read a paperback?*

The whole idea rests on on-device text recognition reading real books: vertical columns, small serif print on cream paper, a lamp. Nothing else is worth building until this is known.

- [ ] **Vision on real pages.** A throwaway capture screen: shutter, a still, `VNRecognizeTextRequest` for Japanese, the recognized lines drawn back over the photo. Tried on the paperbacks actually being read, in the light they are read in. Measures: how often the tapped word's characters come back right, and how vertical text fares. The result decides whether the design below stands, needs zoom-before-capture, or needs a different recognizer.
- [ ] **Tokenizer choice.** Feed the recognized lines to the candidates in [ARCHITECTURE.md](ARCHITECTURE.md) — MeCab with UniDic or IPADIC, Apple's tokenizer with JMdict furigana data — and compare segmentation on OCR output that has a wrong character here and there, the reading quality, the bundle size, and the licensing chores. One of them becomes the dependency; the table in ARCHITECTURE becomes a decision.

## Freeze & tap — *the reading, one-handed*

- [ ] **Freeze the page.** Camera view that only frames; shutter on screen, on the volume button and on the Camera Control; the still is what everything works on, pinch to zoom.
- [ ] **Tap a word.** A tap anywhere on a token highlights the whole token, vertical or horizontal; a second tap on a neighbor extends over a compound. The reading appears in a bottom sheet in large kana, meaning collapsed under it. The recognized characters are editable in the sheet.
- [ ] **Reach.** Everything touchable in the thumb's arc; the page can be swiped so the top of a column comes down.

## Cards — *the word keeps working*

- [ ] **One card per word.** Dictionary form as the key; the sentence from the page as the front, OCR text plus the crop; reading, pitch and the collapsed meaning on the back; book and page recorded. A second sighting adds a sentence, never a card.
- [ ] **Review.** FSRS with two grades; the queue is what is due when the app opens; no streaks, no reminders. Readings by default, meaning cards as an option per word.
- [ ] **Two pages, one sentence.** "Continues on next page" in the capture flow; the fragments joined and re-tokenized, both crops kept.

## Dictionary — *meaning on request*

- [ ] **The system dictionary.** A button on the sheet opens the built-in 大辞林 entry through the reference library view; the app shows it only when the dictionary is installed and has the term.
- [ ] **Typed search.** For words met off the page: kana and kanji search headwords, Latin searches JMdict glosses; results become cards the same way.
- [ ] **Attribution screen.** JMdict, the tokenizer's dictionary, Kanjium: the credits each license requires, on the About screen from the first build that bundles them.

## Pitch & sound — *the part dictionaries lack*

- [ ] **Word pitch.** The accent type or downstep number from the dictionary, drawn over the kana of the reading; notation decided once for the whole app.
- [ ] **Sentence contour and speech**, later and offline: accent phrases from Open JTalk's estimation or UniDic's connection rules, spoken through VOICEVOX, generated on a Mac and bundled or skipped — nothing runs a model on the phone.

## Store — *out the door*

- [ ] **The mascot icon.** The silver Java sparrow drawn for the icon, source art committed beside the script; the placeholder roundel retires.
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
