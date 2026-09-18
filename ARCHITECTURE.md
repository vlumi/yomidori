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

| | `YomidoriCore` | `YomidoriMeCab` | `YomidoriKit` |
| --- | --- | --- | --- |
| holds | kana and reading helpers, the token model and the OS's tokenizer; later the card model, the scheduler, the dictionary lookups | MeCab with IPADic behind Core's `Tokenizer`, the one third-party dependency, kept apart so it can be cut | SwiftUI screens, the camera, Vision text recognition, the palette |
| imports | Foundation | YomidoriCore, Mecab-Swift | SwiftUI, UIKit and Vision (iOS only), YomidoriCore, YomidoriMeCab |
| tested | headless, coverage-gated | headless, on the same fixture | coverage-ignored |

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
- **`RecognizedLine`** and **`TextGeometry`** (Core): one line as a recognizer
  read it, with its box normalized to the image and y up as Vision reports it;
  and the one seam where that box meets a view — the aspect-fitted frame a still
  lands in, the flip to y-down view space, and the hit test that picks the
  smallest line under a tap. Nothing else in the app does coordinate arithmetic.
- **The capture screen** (Kit, `Capture/`): the spike's instrument, and the
  shape of the app to come. `Camera` is the back camera behind a preview that
  only frames, with one shutter that keeps the next frame of the stream at the
  sensor's full resolution: a frame grab, not a photo capture, so nothing is
  written to the library and there is no shutter sound (mandatory for photo
  capture in Japan, where the app is read). The video output must be told to
  deliver full frames; with the photo preset it defaults to preview-sized ones,
  about a megapixel, which is no still to read small print from.
  On a phone with several back cameras it opens them as one virtual device, so
  the system hands a page held close to the ultra-wide (macro) and a pinch past
  the wide's reach to the telephoto, both optical; autofocus is kept to the near
  range, since a book is read at arm's length. The pinch on the preview is the
  zoom-before-capture that small print needs.
  `Still` is the frozen frame, upright, so orientation is settled once; from the
  picker it is decoded upright. A still also comes from the photo picker, which
  is how a screenshot enters and how the simulator, having no camera, is used.
  Two recognizers run over every still, both shipped with the OS and both on
  device: `TextRecognizer` wraps Vision's `VNRecognizeTextRequest` for Japanese
  and yields `RecognizedLine`s, drawn back over the page, tap one to read it;
  `LiveText` wraps VisionKit's `ImageAnalyzer`, the Live Text engine, which
  yields a transcript and, on iOS, its own text selection over the image. A
  third mode reads *up close*: a tap cuts the line under it, as the page pass
  found it, out of the still at full resolution with the paper around it, and
  both engines read only that; where no line was found (a vertical column, which
  only Live Text reads and without positions) a square around the tap stands in.
  Recognizers downscale a whole page before reading, so a dense kanji reaches
  them at a fraction of the pixels the sensor caught; the crop hands them the
  pixels back without the reader zooming, and a whole line with clean margins
  reads better than a square that halves the glyphs at its edges. The screen shows any of the
  three, switched at the bottom; the roadmap's spike is the comparison against
  a real book.
- **`Token`** and **`SystemTokenizer`** (Core): a sentence cut into words by the
  OS's own Japanese analyzer, each with its reading in context as hiragana. The
  analyzer is reached through `CFStringTokenizer`, which offers a Latin
  transcription per word; ICU turns that back into kana without loss, づ and
  ず, おう and おお kept apart. Inflections come cut from their stem (頷い + た),
  punctuation is kept as non-word tokens so the sentence rebuilds from its
  tokens, and ranges point back into the text. Measured equal to MeCab with
  UniDic on the fixture in its tests; the dictionary form and pitch are the
  dictionary layer's to add.
- **`MeCabTokenizer`** (its own target): MeCab with IPADic behind the same
  `Tokenizer` protocol, so the two can be switched under the Live Text
  transcript and compared on real pages; it also knows dictionary forms. It is
  the one third-party runtime dependency (Mecab-Swift, MIT; MeCab under its BSD
  option; IPADic under its own notice, all in THIRD_PARTY_NOTICES.md), pinned to
  a commit and quarantined so that keeping or cutting it is one line.
- **`TokenFlow`** and **`TranscriptReadout`** (Kit): the transcript as its
  words, a line per line of the page, wrapping, each word with its reading over
  it where the reading adds something; a tap fills the word and shows it large
  with its reading and dictionary form. The first shape of the reading sheet.
- **`AppRoot`** (Kit): hosts the capture screen; the place navigation will hang
  from.

## Planned

Nothing below is built. Each section is the current intent and the reasoning;
the [ROADMAP.md](ROADMAP.md) says in which order they are tried.

### Capture: freeze first, then one tap

The camera view only frames. The shutter (on-screen, the volume button, or the
Camera Control) takes a still, and everything after happens on the photo: the
other hand is holding a book, text recognition runs once on a sharp frame, and
the page can be pinched to zoom into small print. Recognition is on device and
from what the OS ships; which engine is the spike's open question. Vision's
`VNRecognizeTextRequest` returns each line with character positions, exactly
enough to map a tap to a character and a character to a token, but on a
rendered page it read no vertical text at all; the Live Text engine
(`ImageAnalyzer`) read the same columns cleanly but returns a transcript and a
selection UI, no positions. A tap highlights the whole token, in a
column or a line alike; tapping the neighbor extends the highlight over a
compound the tokenizer split, and the lookup retries on the joined form. Two
taps at most, never a drag. Everything touchable lives at the bottom of the
screen, inside the thumb's arc; the page can be nudged so a word at the top of
a column comes down into reach.

The recognized characters are shown as editable text in the sheet, so an OCR
error on one stroke is a one-character fix, and the same field is the fallback
when the print is truly too small.

The camera is one source of a still, not the only one. A screenshot of an
e-book app or a web page enters the same screen, through the photo picker or a
share extension that receives the image from the screenshot preview; from the
still on, camera and screenshot are the same path, vertical columns included,
since Japanese e-book novels flow the way the paperbacks do. Watching the screenshots
album is deliberately not offered: it needs photo-library access for everything
in exchange for one tap the share sheet already saves.

### The tokenizer and its dictionaries — the open decision

A reading needs a tokenizer with a dictionary that carries readings and pitch,
and there is no first-party one. The candidates, to be settled by the spike in
the roadmap:

| | readings | pitch | size | license |
| --- | --- | --- | --- | --- |
| The OS's analyzer (`CFStringTokenizer`, Latin transcription → kana) | yes, in context; measured equal to UniDic's on the fixture | no | none | none |
| MeCab + UniDic | yes, per lexeme | yes, with compound rules | large (the lite dictionary is tens of MB, the full one far more) | BSD/LGPL/GPL |
| MeCab + IPADIC | yes | no | ~50 MB | BSD-style |
| Apple `NLTokenizer` + JMdict furigana data | segmentation only from Apple; readings from data | no | small | JMdict CC BY-SA 4.0 |
| Kanjium pitch database | — | yes, keyed to JMdict headwords | small | free |

Both the OS's analyzer and MeCab with IPADic are in the app now, switchable
under the transcript, so the choice is made on real pages rather than on a
fixture. Whatever is chosen is the one deliberate exception to "no third-party
code at runtime", and its attribution goes on an About screen; JMdict and
Kanjium both require it. Until the About screen exists the notices live in
THIRD_PARTY_NOTICES.md.

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
"continues on next page" and leaves the sentence open; the next still, whether a
second shutter or a second screenshot shared in, is where the continuation is
tapped, and the two fragments join with plain concatenation — Japanese has no
hyphenation — and are re-tokenized. Both crops are kept. E-book screens end
sentences mid-way exactly as pages do, so the glue is not a paperback feature.

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
