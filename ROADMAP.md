# Roadmap

The implementation plan, as **named milestones in rough order** — and *only open work*. This file is *expected to churn*: milestones get reshaped as prototyping answers questions. As work ships it leaves this file — brief summaries go to the [README version history](README.md#version-history), full detail to [CHANGELOG.md](CHANGELOG.md), and settled rules and design decisions to [ARCHITECTURE.md](ARCHITECTURE.md). This file is only *when*, not *why*.

**No hard line wraps** — one paragraph or bullet, one line; editors soft-wrap and rendered Markdown ignores the breaks anyway.

**Milestones are not version numbers.** A version is assigned when a milestone is *cut*, not when it is planned — some of these will be reordered, split, or dropped outright, and renumbering the rest each time is the churn that stops a roadmap being updated at all.

Guiding order: **the tap is the app**, and **what comes early is whatever answers a question that changes the plan**.

Done so far (builds 1–7 on TestFlight, 2026-09-17 to 22): the whole first form of the app, described in [ARCHITECTURE.md](ARCHITECTURE.md) under *What exists*: the camera and the frozen page with Live Text's selection as the tap, every word of a selection read against JMdict with pitch, kanji screens with stroke order, cards with sightings and photos on request, lessons, three typed questions per card under FSRS with bird ranks, collections with scanned covers, a lookup history, five tabs, and a seeded demo mode for the simulator and the store screenshots. Two field rounds on a real paperback (2026-09-21 and 22) shaped it.

## The spike — *does the camera read a paperback?*

The whole idea rests on on-device text recognition reading real books: vertical columns, small serif print on cream paper, a lamp. Nothing else is worth building until this is known.

- [ ] **Positions on a vertical page.** *Answered on a paperback (2026-09-21 and 22): Live Text reads the vertical Mincho columns and its own selection is the tap; iOS 26's `RecognizeDocumentsRequest`, which Vision mode now runs alone, reads the same columns as lines with boxes, so the sentence crop works on a vertical page.* Left to build on the boxes: the app's own tap-to-token highlight in Vision mode (under *Tap a word* below), and a furigana filter by height, once a page with ruby has shown whether the request returns it as lines of its own.
- [ ] **manga-ocr over the whole page.** *Built in first form as Close-up: manga-ocr converted to Core ML (encoder as it is, decoder re-expressed as a cache-free step; ~210 MB at half precision, Apache 2.0), reading a window of about eight characters around a tap. Measured on rendered lines: 12 of 13 short windows exact, Mincho, vertical and blurred alike; whole long lines squeezed into its 224 pixels fail, hence the window. Optional at build (`make models`).* Wanted instead: the page cut into lines and every line read, so the engine gives a second transcript to compare with Live Text's and Vision's. Vision's document request cuts the page into lines on vertical print too, so no column finder is needed; speed on the phone (thirty to forty lines a page) is the unknown.
- [ ] **Tokenizer choice.** Feed the recognized lines to the candidates in [ARCHITECTURE.md](ARCHITECTURE.md) — MeCab with UniDic or IPADIC, Apple's tokenizer with JMdict furigana data — and compare segmentation on OCR output that has a wrong character here and there, the reading quality, the bundle size, and the licensing chores. One of them becomes the dependency; the table in ARCHITECTURE becomes a decision. *Measured on the Mac (2026-09-18), on a fixture of thirteen literary sentences with hard readings:* the OS's own analyzer, reached through `CFStringTokenizer` with its Latin transcription turned back to kana, and MeCab with UniDic-lite cut every sentence identically and gave the same reading for every word, in context (生地 きじ beside 生 なま, 頷い うなずい, 相槌 あいづち, 椨 たぶのき). The system analyzer is in Core now as `SystemTokenizer`, with the fixture as its tests. What MeCab adds is the dictionary form (UniDic normalizes it: 点ける becomes 付ける, which a card key would not want) and the accent type per word; what it costs is a C library, a dictionary of tens of megabytes and its license. Recommended: the system analyzer for cutting and readings, JMdict for the dictionary form and meanings, Kanjium for pitch, no third-party code at runtime; the deinflection from a cut stem to its JMdict headword is the one piece to write. Both tokenizers are in the app, switched by a small menu under the page, so the comparison continues on real pages; the field so far: the system analyzer splits compounds the dictionary knows (蛍光灯, joined again by `WordFinder`), MeCab gives name readings for lone kanji (照 あきら). Still open: which to keep, or both.

## Freeze & tap — *the reading, one-handed*

- [ ] **Tap a word.** *Done as Live Text's selection: the selected run is read as words, each a row with reading, pitch, Keep and the meaning under it, its line the sentence.* Still to do: the app's own tap-to-token highlight in Vision mode, now that the document request gives every line its box and a box for any range of its text: the tap lands on a character, the line is cut into words, and the word lights up on the page and reads out below; and editing more than a character at a time on the page. *One misread character is fixed on the page since 2026-09-23: tap it, pick from the dictionary's words spelled like the rest, or type it.*
- [ ] **Reach.** *Done: the drawer with three detents and a double tap, zoom buttons, the + for the next page and the retake on the tab, all at the bottom.* Still to try on the phone: whether the live camera as a tab feels right, and the drawer following the finger on a device.
- [ ] **A screenshot as the still.** *Later; the photo picker covers the case for now.* Reading on the same device — an e-book app, a web page — the still comes from a screenshot instead of the camera: the photo picker inside the app first, then a share extension so Share → Yomidori from the screenshot preview lands straight on the freeze-and-tap screen. Everything after the still is the same code, the vertical columns of an e-book novel included; screenshots are only sharper than any camera frame.

## Cards — *the word keeps working*

- [ ] **Export whole, and import.** *A single collection is shared and imported as a .yomidori file since 2026-09-23, words and sentences only.* *Done in first form: Settings shares the cards file as it is.* Wanted: one archive with the collections, the lookup history and the stills, and a way to bring it back into a fresh install; the Mac's iCloud sync may make the moving part moot, the keeping part not.
- [ ] **Graphs from the log.** Every answer is on its card; wanted once there is data: intake against reviews over time, and the rank counts as a history rather than the snapshot Study draws now.
- [ ] **FSRS parameters fitted** to the reader's own answers, much later, when the logs are long enough.
- [ ] **Stills stitched into one page**, later, not for the first prototype. The visual side of the same glue: consecutive stills laid out as one canvas in reading order — a vertical page continues to the left of the previous, a horizontal one below — so the sentence is seen to flow while its continuation is tapped. The gap between them is trimmed by what Vision recognized, each still cropped to its text block plus a margin, which drops page margins, running heads and an e-reader's chrome without guessing at empty pixels; the seam stays visible as a thin line, and the raw frames remain an option; nothing of it is kept on the card, which keeps text.

## Dictionary — *meaning on request*

- [ ] **A ja gloss** from Japanese Wiktionary where it has one, since 大辞林 is a view and cannot be quoted. Not scheduled.

## Pitch & sound — *the part dictionaries lack*

- [ ] **Sentence contour and speech**, later and offline: accent phrases from Open JTalk's estimation or UniDic's connection rules, spoken through VOICEVOX, generated on a Mac and bundled or skipped — nothing runs a model on the phone.

## Mac — *the same cards on a keyboard*

Decided 2026-09-18: a Mac app is wanted, after the phone's recognizer question is settled, since the Mac inherits whatever that decides. Core is pure and the Kit already compiles on macOS, so the cost is the input, the sync and a target.

- [ ] **Cards that follow.** iCloud sync of the cards, the collections with their covers and the lookup history, so a card kept on the phone is reviewed on the Mac and the other way round; conflicts merged by sightings and reviews, never by picking a side. The prerequisite for the rest of this section, and it serves an iPad too.
- [ ] **A Mac target.** No camera: a pasted sentence goes straight to the tokenizer, a pasted or dropped screenshot goes through Live Text as on the phone, with the Mac's own selection overlay on the image. Same bundle id under the same App Store record. The release lane's macOS scope, inherited from the siblings, comes back into use.
- [ ] **Review on a keyboard.** Space to reveal, two keys to grade. *Typing is how every review is answered already, on every platform: the reading strictly, the meaning leniently with the reader's own accepted meanings, the pitch by a pick. What remains is the Mac's own keys.* A typing tutor proper, with drills and speed, is a different product and stays out.

## Store — *out the door*

- [ ] **Japanese interface** completed and reviewed by a native ear; the ヨミドリ storefront name.
- [ ] **Screenshots and listing tooling.** The demo mode's cast is the screenshot stage; a guided `make shots` like the siblings' captures the chosen screens per language, and `Scripts/asc/` syncs the listing once one exists.
- [ ] **TestFlight, then the App Store.** Privacy answers are all "no" except the camera, which is used on device and never uploaded.

## Ideas to evaluate — *not scheduled*

- [ ] **Generated example sentences.** A word's card could carry sentences built from only the words the reader already knows, generated by a language model on a Mac and synced, never on the phone. Worth trying once a few hundred cards exist and the book's own sentences have shown what they lack.
- [ ] **国語 mode for Japanese schoolchildren.** The same tap, cards turned around: read the kanji in the sentence, write it from the reading on a stroke canvas. The data is free and official — MEXT's grade-by-grade kanji lists, the 常用漢字表, KanjiVG stroke order, Aozora Bunko texts with furigana, BCCWJ's textbook frequencies. Meaning stays out, since no good monolingual children's dictionary is free. Apple's Kids Category rules are already met by the local-only design.
- [ ] **Finnish interface**, a strings file away, once there is Finnish content worth the promise.

## Deliberately out of scope

Per [ARCHITECTURE.md](ARCHITECTURE.md): no server, no accounts, no analytics, no ads, no network at runtime, no cloud model. No furigana over the whole page and no page translation, ever — help only where asked. No watch or TV target; the Mac has its own section above. No third-party runtime code beyond the one tokenizer decision.
