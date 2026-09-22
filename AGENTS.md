# Yomidori — agent & contributor guide

A reading companion for Japanese paperbacks on iPhone and iPad: freeze the page,
tap a word, get its reading and pitch, keep the sentence as a card. This file is
how to *work on* the repo, for humans and AI agents alike.

**Alpha on TestFlight** (builds 1–7, 2026-09-17 to 22), nothing on the App
Store yet. The first form of the whole app exists and has been read with on a
real paperback; ARCHITECTURE.md's *What exists* is the inventory, ROADMAP.md
what remains, and the spike's one open question, positions on a vertical page,
heads the roadmap. Work goes in PR-sized chunks, one concern each, with a
CHANGELOG bullet under *Unreleased* for anything a reader would notice.

Separate project from its siblings [Donpa Squad](https://github.com/vlumi/donpa)
(Minesweeper), [Puck Around](https://github.com/vlumi/puckaround) (air hockey)
and [Skid Jam](https://github.com/vlumi/skid) (a couch racer). Donpa is the
proving ground for the conventions below; Puck Around is the closest relative in
shape (iOS-only, one app target, the same lane). Reuse their *approach* by
copying and adapting, never by sharing a package — the repo is fully independent
and self-contained, and every convention it carries is repeated here in full, so
nothing cross-repo is needed to act on it. **When the flow changes here, change
it in the siblings too**, so the four repos stay one habit.

## Where things are documented

One place per concern — don't duplicate, link:

| | |
| --- | --- |
| **What the system is** | [ARCHITECTURE.md](ARCHITECTURE.md) — the capture-to-card pipeline, the data it stands on, and a fenced *Planned* chapter |
| **How to work on it** | this file — conventions, toolchain, PR process |
| **What's next, and when** | [ROADMAP.md](ROADMAP.md) |
| **Why a design was chosen** | woven into [ARCHITECTURE.md](ARCHITECTURE.md); a big undecided feature may get a temporary `docs/*-plan.md`, retired once it ships |
| **How it ships** | [RELEASING.md](RELEASING.md) |
| **What shipped** | [CHANGELOG.md](CHANGELOG.md) |

When something ships, move it out of ARCHITECTURE.md's *Planned* chapter and
into the prose above it. The fence exists because architecture notes drift into
describing intent as fact otherwise.

## Project facts

- **Platforms:** iOS 26+ / iPadOS 26+ — iPhone and iPad. **The floor is iOS 26**
  (decided 2026-09-22, up from 16): the tab bar's search pill and Liquid Glass,
  and no `#available` anywhere. Platform-only APIs go behind a wrapper (see
  *Platform wrappers*). **No watch, no TV.** A Mac app is
  planned (ROADMAP's *Mac* section): no camera, a pasted text or screenshot as
  the still, the same cards over iCloud, reviews on a keyboard. Until it has a
  target, `YomidoriKit` compiles on macOS 26 because `swift test` runs on the
  Mac — UIKit- and camera-only code sits behind `#if os(iOS)` /
  `#if canImport(UIKit)`, and keeping it that way is what keeps the Mac cheap.
- **Toolchain:** Xcode 26 / Swift 6 toolchain (Swift 5 language mode),
  **XcodeGen** (`.xcodeproj` generated, gitignored, never committed). The team
  ID IS committed in `project.yml` (it's not a secret, and the release lane's
  headless automatic signing needs it); certs/profiles are fetched by
  `-allowProvisioningUpdates`.
- **Name:** the app ships as **Yomidori** on the English storefront and
  **ヨミドリ** on the Japanese one; `Yomidori` is the repo/target/module name.
  **Bundle id:** `fi.misaki.yomidori`, matching the App Store Connect record —
  **don't change it** (an ASC bundle id can't be edited or reused once the
  record exists). MIT, no monetization.
- **Localization:** English and Japanese from day one — String Catalog +
  `Text(_, bundle:)` / `String(localized:)`, never hardcoded literals. Japanese
  *content* (the words, readings, sentences) is data, not UI, and is never
  localized.
- **Everything runs on the device.** No server, no account, no analytics, no
  network at runtime. No cloud model, ever: a word looked up never leaves the
  phone. This is a product rule as much as a privacy one ([PRIVACY.md](PRIVACY.md)
  promises it).
- **Dictionary data is built, not committed.** `make dictionary` runs
  `Scripts/data/build-jmdict.py`, which downloads JMdict_e, KANJIDIC2, KRADFILE,
  KanjiVG (a pinned release; bump the URL in the script to update) and Kanjium's accent list
  once into `.build-data/` and writes
  `Sources/Shared/Dictionaries/jmdict.sqlite` (~78 MB with its full-text index and the strokes, gitignored); the project generation depends on it, so `make build-ios`
  and the run targets build it on first use, and CI does the same. `swift test`
  needs none of this: the dictionary tests read a fixture in the test target,
  built by the same script from the `*-fixture.*` files beside it (the command
  is in the XML's header comment).
  JMdict, KANJIDIC2, KRADFILE and Kanjium are CC BY-SA 4.0 and KanjiVG CC BY-SA 3.0 — the attributions are in
  [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md), shown on the About screen,
  and in the database's `meta` table.
- **manga-ocr is optional and built, not committed.** `make models` converts
  the model to Core ML into `Sources/Shared/Models/` (~210 MB, gitignored) with
  Homebrew's `python@3.13` and a local venv; the app hides the engine when the
  models are absent, so CI and a fresh clone build without them, and a release
  cut without them ships without the engine (the preflight says so). MIT; the
  notice is in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
- **Third-party code at runtime: none by default.** Everything ships with the OS
  (Foundation, SwiftUI, UIKit, Vision, AVFoundation). The one exception is
  MeCab with IPADic (the Mecab-Swift package, pinned to a commit), which is in
  the app as the *alternative* tokenizer while the choice against the OS's own
  analyzer is compared in the field; it lives in its own target,
  `YomidoriMeCab`, so nothing else imports it and cutting it is one line in
  `Package.swift`. Its notices are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md),
  which every bundled license goes into; the file is bundled into the app and
  shown on the About screen, so editing it is the whole job. Nothing
  else joins without the same write-up in ARCHITECTURE.md. Dev tools (SwiftLint,
  XcodeGen) don't count and aren't SPM deps.

## Architecture: from a tap to a card

The load-bearing decisions and their rationale live in
[ARCHITECTURE.md](ARCHITECTURE.md). The essentials:

- **Help only where asked.** The app never annotates what wasn't tapped: no
  furigana over the page, no translation. Recognizing what you know is the
  reading practice; the app answers the one word you asked about.
- **The reading is the unit.** A selection resolves to *words* (`WordFinder`
  over the tokenizer's cut), each with reading, pitch and dictionary form. A card
  asks three things by typing, reading, meaning and pitch, each on its own
  schedule; the meaning is a tap further on the page and never shown unasked.
- **The book is the corpus.** A card's front is the sentence as it stood on the
  page (OCR text plus the crop), so example sentences need no corpus, no license
  and no generation. One card per word; sentences accumulate across books.
- **Testable logic goes in `YomidoriCore`.** The coverage gate covers Core; the
  SwiftUI/Vision/camera layer (`YomidoriKit`) is ignored wholesale, so logic
  left there is logic left untested.

### Structure

```text
yomidori/
├── project.yml                     XcodeGen spec (the iOS app target)
├── Makefile                        Short targets; run `make` to list them
├── Scripts/                        One job per script; the Makefile wires them
│     generate.sh                   Regenerates the .xcodeproj (refuses if THIS project is open in Xcode)
│     build.sh / test.sh / run-ios.sh / run-device.sh / demo.sh (the seeded demo, make demo-iphone)
│     embed-commit-sha.sh           Stamps GitCommitSHA into the built Info.plist
│     release-*.sh, distribute.sh   The release lane (RELEASING.md)
│     assets/make-icon.swift        Renders the app icon PNG (make icon)
│     data/build-jmdict.py          JMdict, KANJIDIC2, KRADFILE, KanjiVG, Kanjium accents → the bundled SQLite (make dictionary)
│     data/build-mangaocr.py        manga-ocr → Core ML (make models; optional)
├── Sources/iOS/                    Thin @main app shell (+ Info.plist, entitlements)
├── Sources/Shared/                 The asset catalog (AppIcon), the app-level String Catalogs (InfoPlist too)
│     Dictionaries/jmdict.sqlite    Built by make dictionary; gitignored
│     Models/                       manga-ocr's Core ML packages, by make models; gitignored, optional
└── Packages/YomidoriCore/          Swift package — all the code
    ├── Sources/YomidoriCore/       Pure logic — tested, coverage-gated; grouped by domain as it grows:
    │   ├── Kana.swift              katakana ↔ hiragana, the first of the reading helpers
    │   ├── Cards/                  Card, Sighting, CardStore + its JSON file, Collection, Lesson, LookupHistory
    │   ├── Dictionary/             DictionaryEntry, the WordDictionary protocol and its lookups, KanjiEntry, SVGPath
    │   ├── Reading/                Token, Tokenizer, SystemTokenizer, Deinflector, WordFinder, PitchAccent, Sentence, Spread, TranscriptLines
    │   ├── Recognition/            RecognizedLine, TextGeometry, LineCrop, CloseUpGeometry (the Vision-box ↔ view seam)
    │   ├── Scheduling/             FSRS, Rank, ReadingCheck, MeaningCheck
    │   └── Text/                   MarkdownBlocks
    ├── Sources/YomidoriDictionary/ JMdict, the SQLite reader over the bundled database (system SQLite)
    ├── Sources/YomidoriMeCab/      MeCab + IPADic behind Tokenizer — the one third-party dependency, quarantined
    ├── Sources/YomidoriMangaOCR/   manga-ocr through Core ML: a CGImage in, a String out; coverage-ignored
    ├── Sources/YomidoriKit/        SwiftUI + UIKit + Vision, depends on Core, Dictionary, MeCab and MangaOCR; coverage-ignored
    │   ├── App/                    AppRoot (the tabs, TabStack), HomeView, Screen, Destinations, TabTaps, SettingsView, SwipeBack, AboutView, NoticesView, AppInfo, Palette, Compat — one type per file
    │   ├── Capture/                Camera, CameraPreview, FrameSink, Still, TextRecognizer, LiveText*, CaptureState, CaptureView and its drawer (detents), zoom buttons, readouts and reader
    │   ├── Cards/                  CardsView, CardView and its sections, StudyView, LessonView/LessonCard, ReviewView with front, back and PitchChoices, RankName/RankChart, Collection* screens, CoverScanView, TagsEditor, StillArchive (+ the Cards store roots)
    │   ├── Reading/                TranscriptReadout, WordReadout, WordDetails/WordSections, EntryView/EntryRow, KanjiView/KanjiRow, StrokeOrderView, SearchView, LookupHistoryView, TokenFlow, WordTitle, PitchReading, DictionaryButton, SentenceKeeper, TokenizerChoice
    │   ├── Demo/                   DemoMode, DemoData, DemoText, DemoRenderer — the seeded demo (see Demo mode)
    │   └── Resources/              Localizable.xcstrings (the Kit's strings, en + ja)
    └── Tests/YomidoriCoreTests/    Grouped by domain, mirroring Core
```

Both targets and the tests group **by domain, not by type**.

### Art assets

The icon is the one PNG in the repo, and it is *generated*: `make icon` runs
`Scripts/assets/make-icon.swift` (pure CoreGraphics) into
`Sources/Shared/Assets.xcassets/AppIcon.appiconset/icon-1024.png`, flattened to
opaque because App Store Connect silently rejects a transparent icon. To change
the icon, change the script and re-run — never hand-edit the PNG. The icon is
the mascot, the family's silver Java sparrow, drawn head-on and mochi-round on
a perch; every proportion is a named constant at the top of the script, so a
tweak is a number, not a redraw.

## Build, run, test

Everything is a `make` target so Xcode never has to be opened
(`make` / `make help` lists them):

```sh
make test              # package logic tests (swift test; no Xcode project needed)
make lint              # SwiftLint + swift-format, both --strict, as CI runs them
make format            # rewrite sources with swift-format
make build-ios         # generate the project if stale, build the app for the simulator (unsigned)
make run-iphone        # build + install + launch on an iPhone simulator (DEVICE="SE" to pick)
make run-ipad          # same, iPad (DEVICE="Air")
make run-device        # build + install + launch on a paired iPhone/iPad (DEVICE="<name>" to pick)
make demo-iphone       # build + launch the seeded demo on a simulator (DEVICE=<pattern>); demo-ipad likewise
make icon              # regenerate the app icon PNG
make dictionary        # build the bundled JMdict database (downloads JMdict_e once)
make models            # convert manga-ocr to Core ML into the app (optional; python3.13 + venv; ~210 MB)
make clean-models      # remove them again, and nothing else
make generate          # regenerate Yomidori.xcodeproj from project.yml (only if stale)
make clean             # remove the generated project + build output
```

`swift test` runs on the Mac, headless — that's the inner loop. The camera needs
a real device: the simulator has no camera, so the capture flow is tried on a
phone over a real book with `make run-device` (the phone plugged in or on the
same Wi-Fi, unlocked, in Developer Mode; in the simulator the photo picker
stands in for the shutter), and only the logic below it is unit-tested.
`make release` is the release lane, documented in [RELEASING.md](RELEASING.md).

### Lint & format

```sh
swiftlint lint --strict                 # style + light correctness (config: .swiftlint.yml)
swift format lint --strict --recursive --configuration .swift-format \
  Packages/YomidoriCore/Sources Packages/YomidoriCore/Tests Sources
swift format --in-place --recursive --configuration .swift-format <paths>   # auto-format
```

CI runs both with `--strict` (warnings fail). **swift-format is the authority
on whitespace/punctuation**; where SwiftLint conflicts (trailing commas, brace
placement) those SwiftLint rules are disabled rather than fought. Run the
formatter before committing.

**Run SwiftLint from the repo root.** Its `excluded:` paths (`.build`,
`Packages/YomidoriCore/.build`) resolve relative to the invocation directory,
not the config file — run it elsewhere and it lints the build dirs, drowning
you in noise from generated sources.

**SwiftLint is pinned to a specific version** (`SWIFTLINT_VERSION` in
`.github/workflows/ci.yml`, currently **0.65.0**) so CI and local runs agree —
an unpinned `brew install` follows the rolling latest, so a new release can
turn CI red on untouched code. Match it locally where possible (a patch release
ahead is usually fine; a minor one isn't). Bump the CI version deliberately and
update this line. swift-format needs no pin — it ships with the Xcode toolchain,
which CI pins via `XCODE_VERSION`.

## Pull requests & CI

Branch off `main`; the initial bootstrap was committed directly, everything
since goes through a PR (details in [CONTRIBUTING.md](CONTRIBUTING.md)).
Agent-specific mechanics on top of that:

- **One commit per concern.** A commit is one coherent step that builds and
  makes sense on its own; a PR is sized by concern too — not padded out with
  unrelated changes, and not split into fragments that only make sense together.
  Squash the fix-the-previous-commit noise locally before pushing; rewriting an
  open PR branch is fine, `main` is never rewritten.
- **Commit trailer:** end commit messages with a
  `Co-Authored-By: <model> <noreply@anthropic.com>` line.
- **A user-facing PR writes its own CHANGELOG bullet** under the newest
  version's `### Unreleased (next build)` heading — the release lane only
  stamps the build number, it never writes entries. See CHANGELOG.md's preamble.
- **Wait for Codecov before merging.** `codecov/patch` is reported but is NOT a
  required check, so `--auto` merge can land a PR *before* coverage posts —
  merge only once it's green (target 80% on new, non-ignored code).
- **The whole `YomidoriKit` target is coverage-ignored** (the SwiftUI/Vision
  layer), so pure logic goes in `YomidoriCore` to be tracked. If a Kit file
  grows testable logic, move the logic, don't widen the ignore list.
- **BEHIND blocks merge** (branch protection). Merge `origin/main` into the
  branch to catch it up; auto-merge needs required checks, so a base without
  protection falls back to a direct merge after the CI wait.

## Demo mode

`make demo-iphone` launches the simulator build with `-yomidori-demo`
(`Scripts/demo.sh`, like the siblings' launchers). `YomidoriKit/Demo`: `DemoMode`
routes every store (cards, collections, lookups, stills) to a temp folder wiped
and reseeded at each launch and the settings to their own defaults suite;
`DemoData` seeds two public-domain openings (漱石's 吾輩は猫である, 太宰's 走れメロス)
as cards at every rank with sightings, a shelved name, a search-kept word,
collections with rendered covers and a lookup history, dates relative to now so
the queue is always in the same state; `DemoRenderer` draws the page and the
covers from text with CoreText, vertical Mincho on cream, so Read opens on a
page with its transcript already known (`CaptureState.transcript`). The camera
is untouched; the data can be changed in the session and is gone at the next
launch. Nothing of this runs without the argument.

## Conventions

- **Comments minimal:** a comment says only what the code cannot, after the
  names have done their best: a coordinate convention, an API default that
  bites, a linguistic rule, a threshold's reason. A type or function whose
  name says what it is gets no doc comment. No historical / roadmap ("lands
  later", "compared in the field") narration in source — that goes in commit
  messages and the docs.
- **Pitch is drawn one way**: a line over the high morae with a drop where the
  accent falls, and the downstep number in brackets beside it (`PitchReading`).
  Tokyo accent, from Kanjium, keyed by headword and reading.
- **Readings are hiragana when shown, katakana when stored** — dictionaries
  give katakana, readers expect hiragana; `Kana` converts at the edge, once.
- **Unicode-scalar work stays in Core**, tested against real Japanese strings
  (kanji, both kana, the length mark, punctuation); never assume one scalar per
  character in the Kit.
- **Coordinates from Vision are normalized and y-up**; convert to view space at
  the one seam that maps a tap to a character, nowhere else.
- **No network code**, not even behind a flag. If something needs a download
  (a dictionary update, say), it becomes an App Store update.
- `.vscode/` is gitignored and must not be pushed.
- When you change what a tap does or what a card asks, update `README.md` too.

### Platform wrappers

The floor is iOS 26 and the Kit also compiles for macOS 26 (tests), so there
are no version fallbacks; what remains is the platform split, in
`YomidoriKit/App/Compat.swift`:

- **Platform-only wrappers** — no-ops off iOS, so views stay free of `#if`.
  UIKit-, camera- and Vision-only *code* sits in an `#if os(iOS)` block with a
  fallback that keeps the macOS test build compiling. `Palette` already does
  this for appearance-aware colors.

### String catalogs (`.xcstrings`)

- **Xcode's serialized form is canonical** (spaced colons, 2-space indent).
  After any scripted/CLI edit, normalize before committing:
  `plutil -convert json -r -o FILE FILE` — then opening the project in Xcode
  produces no churn.
- **`InfoPlist.xcstrings` needs an explicit `en` unit for every key.** Its keys
  are plist keys, and a catalog falls back to the key as the source-language
  value, so without one English devices see `NSCameraUsageDescription` as the
  camera's reason and App Store Connect flags it (ITMS-90738).
- **Renaming a key must update its explicit `en` unit too.** An entry with an
  `en` localization whose value overrides the key would leave English silently
  showing the old text. Audit: flag any entry whose explicit `en` value ≠ its
  key (positional-format entries like `%1$@…` are the legit exceptions).
- Localize the **concept**, not the word — each locale by a native ear. The
  Japanese interface is for Japanese readers of the app, not a translation
  exercise for learners.

## Gotchas

- SourceKit in-IDE diagnostics may report `No such module 'YomidoriCore'`
  for files it hasn't indexed — these are **false**. The authoritative checks
  are `swift build` / `swift test` / `xcodebuild`.
- The first build of a fresh clone stamps `GitCommitSHA = unknown` until there
  is a commit; `embed-commit-sha.sh` treats that as fine, not as an error.
