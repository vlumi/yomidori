# Architecture

What Yomidori **is**, as built, with the *why* behind each choice woven in.
Process and conventions live in [AGENTS.md](AGENTS.md); *when* things happen is
[ROADMAP.md](ROADMAP.md). A big, still-undecided feature may get its own
`docs/*-plan.md` to think it through; once it ships, its decisions fold into
this file and the plan is retired.

Everything before "[Planned](#planned)" describes shipped code. That chapter is
fenced off deliberately: mixing the two is what lets architecture notes drift
into describing a model that was never built. Today almost everything is
planned, and the fence is the point.

## The rule everything hangs on

**Help only where asked.** The app annotates the one word you tapped and
nothing else. No furigana over the page, no translation, no "you might also
not know". Recognizing what you already know is the reading practice, and an
app that helps unasked takes it away. Every screen is checked against this
before it is built.

## Two targets, one seam

| | `YomidoriCore` | `YomidoriKit` |
| --- | --- | --- |
| holds | kana and reading helpers; later the token model, the card model, the scheduler, the dictionary lookups | SwiftUI screens, the camera, Vision text recognition, the palette |
| imports | Foundation | SwiftUI, UIKit and Vision (iOS only), YomidoriCore |
| tested | headless, coverage-gated | coverage-ignored |

The rule: **testable logic goes in YomidoriCore.** The Kit compiles on macOS
too — not for a Mac app (there will be none) but because `swift test` runs on
the Mac; UIKit-, camera- and Vision-only code sits behind `#if os(iOS)` /
`#if canImport(UIKit)` with a fallback.

## What exists

- **`Kana`** (Core): katakana ↔ hiragana over the shared Unicode range, and an
  is-it-all-kana test. Tokenizer dictionaries give readings in katakana; a
  reading shown to a reader wants hiragana, so this conversion happens once, at
  the edge where a token becomes a display. The length mark and the
  katakana-only scalars pass through unchanged, which the tests pin down with
  real words.
- **`Palette`** (Kit): the colors, one value per appearance. 夜緑, night green,
  is the accent in both light and dark; text sits on neutral ground, paper by
  day and near-black by night, so the page is what the eye lands on. A `Color`
  initializer resolves the pair through UIKit's trait collection on iOS and
  falls back to the light value on the macOS test build.
- **`AppRoot`** (Kit): the name, until the camera view replaces it. It exists so
  the app target, the package, the String Catalog with its Japanese unit, and
  the whole build-and-release lane are exercised end to end from the first
  commit.

## Planned

Nothing below is built. Each section is the current intent and the reasoning;
the [ROADMAP.md](ROADMAP.md) says in which order they are tried.

### Capture: freeze first, then one tap

The camera view only frames. The shutter (on-screen, the volume button, or the
Camera Control) takes a still, and everything after happens on the photo: the
other hand is holding a book, text recognition runs once on a sharp frame, and
the page can be pinched to zoom into small print. Recognition is Vision's
`VNRecognizeTextRequest` for Japanese, on device, which handles vertical columns
and small serif print far better than a person counting strokes; it returns
each line with character positions, which is exactly enough to map a tap to a
character and a character to a token. A tap highlights the whole token, in a
column or a line alike; tapping the neighbor extends the highlight over a
compound the tokenizer split, and the lookup retries on the joined form. Two
taps at most, never a drag. Everything touchable lives at the bottom of the
screen, inside the thumb's arc; the page can be nudged so a word at the top of
a column comes down into reach.

The recognized characters are shown as editable text in the sheet, so an OCR
error on one stroke is a one-character fix, and the same field is the fallback
when the print is truly too small.

### The tokenizer and its dictionaries — the open decision

A reading needs a tokenizer with a dictionary that carries readings and pitch,
and there is no first-party one. The candidates, to be settled by the spike in
the roadmap:

| | readings | pitch | size | license |
| --- | --- | --- | --- | --- |
| MeCab + UniDic | yes, per lexeme | yes, with compound rules | large (the lite dictionary is tens of MB, the full one far more) | BSD/LGPL/GPL |
| MeCab + IPADIC | yes | no | ~50 MB | BSD-style |
| Apple `NLTokenizer` + JMdict furigana data | segmentation only from Apple; readings from data | no | small | JMdict CC BY-SA 4.0 |
| Kanjium pitch database | — | yes, keyed to JMdict headwords | small | free |

The likely shape is a C tokenizer wrapped in a Swift module with a trimmed
dictionary, plus Kanjium for pitch where the dictionary lacks it. Whatever is
chosen is the one deliberate exception to "no third-party code at runtime", and
its attribution goes on an About screen; JMdict and Kanjium both require it.

### From token to card

A card is one **word** (the dictionary form), never one sighting. Its front is a
sentence as it stood on the page — the OCR text with the word highlighted, and
the crop of the line behind it for when the OCR misread something. Its back is
the reading in large kana, the pitch mark, the meaning collapsed below (usually
known already), and the book and page it came from. Meeting the word again in
another book adds a sentence to the same card, and reviews rotate through them.
The default question is "how is this read", because that is the gap the app is
for; a meaning card is an option ticked when the meaning was the gap.

A sentence spanning two pages is glued in the capture flow: when expanding to
the sentence boundary runs off the end of the last column, the sheet offers
"continues on next page", a second shutter, a tap on the continuation, and the
two fragments join with plain concatenation — Japanese has no hyphenation — and
are re-tokenized. Both crops are kept.

### Scheduling and storage

FSRS, not SM-2: fewer reviews for the same retention, which matters when input
is a stream from real reading rather than a fixed deck. Two grades are enough
for readings. No streaks, no daily nag: the queue is whatever is due when the
app is opened. Storage is local, with iCloud sync as a later option for the
iPad; the model is small enough that plain files or SQLite suffice, and the
choice is made when the card model is written, not before.

### Dictionary and meaning

The meaning is one tap away, never on the card by default. iOS ships Sanseido's
スーパー大辞林 as a system dictionary, and `UIReferenceLibraryViewController`
shows its entry for a term offline with no license: the ja-ja meaning a reader
wants, at the quality no free data matches. It is a view, not data, so cards
cannot quote it; where a short gloss belongs on a card, JMdict supplies an
English one, and Japanese Wiktionary may supply a ja gloss where it has one.
A typed search box serves words met off the page; Latin input searches JMdict's
glosses, kana or kanji searches headwords, no mode switch.

### Pitch accent and audio

Word-level pitch comes from UniDic's accent type or Kanjium's database; a
sentence's contour, which shifts with conjugation and compounding, from
UniDic's connection rules or Open JTalk's accent estimation, which VOICEVOX
exposes together with speech. All of it is standard Tokyo accent, which every
free source and most paid ones are limited to. Notation is decided early: the
line-over-mora drawing learners know, the downstep number, or both.

### Theme

Two palettes on one token set, following the system with a manual override.
Dark mode is 夜緑 proper: deep green accent on near-black. Light mode is the same
green on paper-white. The green is the frame and the accent — the tapped word,
the buttons, the bird — never the surface behind text. The highlight of a tapped
word sits on a photograph, so it is a translucent fill with a solid underline,
legible over cream paper and grey print in both modes.

### Localization

English and Japanese interfaces; the name is Yomidori on one storefront and
ヨミドリ on the other, one bundle. The Japanese interface is for Japanese users,
which the school-age 国語 idea in the roadmap would need, and it is written by a
native ear, not translated from the English.
