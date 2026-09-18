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

| | `YomidoriCore` | `YomidoriDictionary` | `YomidoriMeCab` | `YomidoriMangaOCR` | `YomidoriKit` |
| --- | --- | --- | --- | --- | --- |
| holds | kana and reading helpers, the token model and the OS's tokenizer, the dictionary entry model, the cards and the scheduler | `JMdict`, the reader over the bundled SQLite database, behind Core's `WordDictionary` | MeCab with IPADic behind Core's `Tokenizer`, the one third-party dependency, kept apart so it can be cut | manga-ocr through Core ML, a `CGImage` in and a `String` out, present only when the models are bundled | SwiftUI screens, the camera, Vision text recognition, the palette |
| imports | Foundation | YomidoriCore, the system's SQLite3 | YomidoriCore, Mecab-Swift | YomidoriCore, CoreML | SwiftUI, UIKit and Vision (iOS only), YomidoriCore, YomidoriDictionary, YomidoriMeCab, YomidoriMangaOCR |
| tested | headless, coverage-gated | headless, on a fixture built by the same script | headless, on the same fixture | coverage-ignored (the models are not in the tests) | coverage-ignored |

The rule: **testable logic goes in YomidoriCore.** The Kit compiles on macOS
too, today because `swift test` runs on the Mac and later for the Mac app the
roadmap plans; UIKit-, camera- and Vision-only code sits behind `#if os(iOS)` /
`#if canImport(UIKit)` with a fallback, which is the same seam a Mac target will
use for its own input.

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
  zoom-before-capture that small print needs. From iOS 17.2 the volume buttons
  and the Camera Control press the shutter too, through the capture event
  interaction the system offers camera apps, so the book stays in the other hand;
  before that the shutter is on screen only.
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
  reads better than a square that halves the glyphs at its edges. In every
  mode the frozen still pinches to zoom and drags to pan, a double tap bringing
  it back; the tap on a line or a word is reported in the still's own
  coordinates whatever the zoom, so the geometry seam knows nothing of it. The screen shows any of the
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
- **`Deinflector`** (Core): from a stem as the OS's analyzer cuts it to the forms a
  dictionary might list it under. The stem's last kana says which conjugation
  rows it can come from, a table gives one candidate per row (頷い → 頷く and
  頷ぐ, 漂っ → 漂う, 漂つ and 漂る, 点け → 点ける, 存在し → 存在する, 古く → 古い), the
  word itself comes first for nouns and dictionary forms, and the dictionary
  decides which exist, so 降り is both 降る and 降りる until a lookup says
  otherwise. Tested on the stems the tokenizer fixture actually produces.
- **`MeCabTokenizer`** (its own target): MeCab with IPADic behind the same
  `Tokenizer` protocol, so the two can be switched under the Live Text
  transcript and compared on real pages; it also knows dictionary forms. It is
  the one third-party runtime dependency (Mecab-Swift, MIT; MeCab under its BSD
  option; IPADic under its own notice, all in THIRD_PARTY_NOTICES.md), pinned to
  a commit and quarantined so that keeping or cutting it is one line.
- **`PitchAccent`** (Core): Tokyo pitch as dictionaries give it, the mora after
  which the pitch drops, 0 for flat; it splits a reading into morae (a small kana
  joins the one before it) and says which morae are high, the three shapes
  learners know. **`PitchReading`** (Kit) draws that: a line over the high morae
  dropping where the accent falls, the number in brackets beside it. This is the
  app's one notation, decided here.
- **`DictionaryEntry`** (Core) and **`JMdict`** (its own target): a word as
  JMdict has it, kanji forms, readings, senses with parts of speech and glosses,
  and its frequency mark; read from a SQLite database through the system's own
  SQLite, by exact kanji form or reading, common words first. The same database
  holds Kanjium's accent table, keyed by headword and reading, and the reader
  answers pitch questions from it. The database is
  built from JMdict_e by `Scripts/data/build-jmdict.py` (standard-library
  Python, a few seconds, ~50 MB) into the app target at build time and never
  committed; its `meta` table carries the source date and the EDRDG attribution.
  The tests read a sliver built by the same script from a hand-made XML.
- **`TokenFlow`** and **`TranscriptReadout`** (Kit): the transcript as its
  words, a line per line of the page, wrapping, each word with its reading over
  it where the reading adds something; a tap fills the word and shows it large
  with its reading and dictionary form, and under a fold, its meaning: the
  entries for its dictionary form, else the word as it stands, else its reading,
  and "not in the dictionary" where none matches, which is what a misread word
  looks like. The first shape of the reading sheet.
- **`Card`**, **`Sighting`** and **`FileCardStore`** (Core): a card is one word
  in its dictionary form with its reading, the key together; a sighting is the
  word as it was met once, the sentence as it stood on the page, the word's form
  and offset in it, the still it came from by id, a source in the reader's
  words, and when. Keeping a word already kept adds a sighting, never a card;
  the same kanji read another way is another card. The store is one JSON
  document in Application Support, written whole and atomically on every
  change: a reader's cards number in the hundreds or low thousands, which one
  file reads in a blink, and one file is what a sync or a backup copies. The
  reading, pitch and meaning are not stored; they are looked up live.
- **`Sentence`** (Core): the sentence around a word, from the previous full stop
  to the next with its closing quote, across the page's wrapped lines, which in
  a book are wraps and nothing more; open when the page ends before a full stop.
  Its continuation on the next page is that page's beginning up to its first
  full stop. Tested on a page of wrapped lines with quotes.
- **`LineCrop`** (Core): where a sentence sits on the still, as the union of the
  recognized lines whose text is part of it, padded by a line's thickness; a line
  counts when a run of it is in the sentence, six characters or six tenths of the
  shorter, since the recognizer and the sentence rarely agree on every character.
  Nil where no line matches, the vertical case, and the whole still stands in.
- **Keeping a word** (Kit): *Keep* beside the tapped word saves the sentence it
  stands in, as `Sentence` cuts it, with the word's form and offset, the crop of
  its lines where `LineCrop` finds them, shown on the card's front, and the still
  it was read from, scaled to two thousand pixels on its longer side as a JPEG
  in Application Support (`StillArchive`). The card's key is the dictionary
  entry's headword and reading when the word was found, else the tokenizer's
  form. A spread of several pages is read as one text: *Add next page* keeps
  this page's text and takes the next, and `Spread` joins the pages at the seam
  with no break, so a word cut by the page turn tokenizes whole and a sentence
  runs on; a kept sighting carries every page's still, saved once each.
  **`CardsView`** lists the cards, newest first, and **`CardView`** shows
  one: the word with its pitch, every sentence it was met in with the word
  marked, the crop, and the still.
- **`FSRS`**, **`Grade`** and **`ReviewState`** (Core): the free spaced
  repetition scheduler, version 5, with its published default parameters and a
  desired retention of 90 %. Two grades, Again and Good, mapped to FSRS's 1 and
  3; the state a card carries is stability, difficulty, due and last review with
  the counts, nil until the first review, which makes a new card due at once.
  Intervals are whole days, one at least; a same-day answer uses the short-term
  rule. Tested for the shapes that matter: a first Good comes back in three
  days, a first Again tomorrow, intervals grow, a lapse shrinks stability,
  retrievability is one at review and 90 % at the due date. **`ReviewView`**
  (Kit) runs the due queue one card at a time: the latest sentence with the word
  marked as the front, the question being its reading; a tap turns it to the
  reading with its pitch and the meaning under a fold; two buttons. No streak,
  no count kept against anyone. With *Type the reading* on, remembered, the
  front takes the reading typed in kana instead, `ReadingCheck` (Core) judges it
  strictly with katakana and half-width folded, the verdict shows with the
  back, and the grade it suggests is the prominent button; every review is then
  a few words of kana typing on vocabulary actually met. A card can also ask
  what the word means, a switch on the card, off by default since the reading
  is the gap the app is for: a second question with its own schedule, the
  reading given away on its front, the senses and the system dictionary on its
  back. The queue is of questions, not cards.
- **`AboutView`** (Kit): the name, the version with its build and commit, the
  promise that nothing leaves the device, the pitch notation explained on four
  words, and the notices every bundled license asks for, which are the
  repository's own THIRD_PARTY_NOTICES.md bundled as a resource so there is one
  copy to keep current.
- **Selecting on the page** (Kit, `LiveTextSelection`): in Live Text mode the
  word selected on the still itself, through the engine's own selection, is the
  word the readout shows, with its line as the sentence for Keep; the selection's
  range into the transcript finds the line. Live Text tells no one when the
  selection changes, so the image's coordinator polls it four times a second
  while that mode is showing and stops when it goes. Reading the selection is
  iOS 17 and up; on iOS 16 the strip below stays the way to a word.
- **Typed search** (`SearchView`, `EntryView` in Kit; `SearchQuery` and
  `WordDictionary.search` in Core): for words met off the page. Kana or kanji
  finds headwords and readings that start with it, a hiragana query tried as
  katakana too since JMdict spells loanwords so; anything else searches the
  English glosses through a full-text index the build script adds to the
  database. No mode switch, the query says which; common words first. A result
  opens as a tapped word does, with its pitch, senses and the system dictionary,
  and *Keep* makes a card with no sentence yet, which the review then asks by
  the word alone until a page supplies one.
- **`MangaOCR`** (its own target): manga-ocr, a vision transformer reading one
  line or bubble of Japanese at a time, vertical included, converted to Core ML
  by `Scripts/data/build-mangaocr.py`: the encoder as it is, the decoder
  re-expressed as one cache-free step with an explicit mask, the vocabulary
  beside them; ~210 MB at half precision, MIT, optional at build and absent from
  the engine list when not bundled. In Close-up it reads a window of about eight
  characters along the line around the tap (`TextGeometry.window`), which is the
  bubble's worth it was trained on; a whole long line squeezed into its 224
  pixels fails, so it is never given one. Nothing leaves the device.
- **`DictionaryButton`** (Kit): beside a tapped word, on a card and on the
  review's back, a button that opens the system's own dictionaries on the
  headword through the reference library view, スーパー大辞林 among them on a
  Japanese phone: the ja-ja meaning at a quality no free data matches, as a view
  the app never quotes. Present only when an installed dictionary has the term;
  absent on the macOS test build, which has no such library.
- **`HomeView`** and **`AppRoot`** (Kit): a fresh start opens on home, the name
  and the bird's reading, one big *Read* button, *Cards* with what is due, and
  *About*; the camera starts only when asked, so the permission prompt comes
  with its reason and a review costs no battery. The navigation path is kept in
  scene storage and restored on launch, so the app reopens where it was left,
  the camera included; the frozen still is not restored, being a second's work
  to take again.

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

JMdict is in the app now, built into a SQLite database at build time, and the
lookup from a tokenizer's stem to its headword goes through `Deinflector`;
what remains here is the card, and the meaning views described below.

A card is one **word** (the dictionary form), never one sighting. Its front is a
sentence as it stood on the page — the OCR text with the word highlighted, and
the crop of the line behind it for when the OCR misread something. Its back is
the reading in large kana, the pitch mark, the meaning collapsed below (usually
known already), and the book and page it came from. Meeting the word again in
another book adds a sentence to the same card, and reviews rotate through them.
The default question is "how is this read", because that is the gap the app is
for; a meaning card is an option ticked when the meaning was the gap.

The two-page glue is built (see *What exists*) as attaching pages: the next
still's text joins the current one at the seam by plain concatenation, Japanese
having no hyphenation, so a word or a sentence cut by the page turn is whole, and
every page's still is kept. E-book screens end sentences mid-way exactly as
pages do, so the glue is not a paperback feature.

### Scheduling and storage

The scheduler is built (see *What exists*): FSRS, not SM-2, two grades, no
streaks, the queue whatever is due when the app is opened, the meaning as a
second question per word when asked for. Storage is one JSON document, local,
with iCloud sync as a later option for the iPad. What remains here is the
parameters staying the published defaults until there are enough reviews to
fit them, which is a question for much later.

### Dictionary and meaning

The meaning is one tap away, never on the card by default. The system
dictionary button and the typed search are built (see *What exists*); JMdict
supplies the English gloss under the fold, and Japanese Wiktionary may one day
supply a ja gloss where it has one, since 大辞林 is a view and cannot be quoted.

### Pitch accent and audio

Word-level pitch is in the app, from Kanjium, drawn as the line over the morae
with the downstep number beside it (see *What exists*). A sentence's contour,
which shifts with conjugation and compounding, would come from UniDic's
connection rules or Open JTalk's accent estimation, which VOICEVOX exposes
together with speech. All of it is standard Tokyo accent, which every free
source and most paid ones are limited to.

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
