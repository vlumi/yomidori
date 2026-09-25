# Architecture

What Yomidori **is**, as built, with the *why* behind each choice woven in.
Process and conventions live in [AGENTS.md](AGENTS.md); *when* things happen is
[ROADMAP.md](ROADMAP.md). A big, still-undecided feature may get its own
`docs/*-plan.md` to think it through; once it ships, its decisions fold into
this file and the plan is retired.

Everything before "[Planned](#planned)" describes shipped code. That chapter is
fenced off deliberately: mixing the two is what lets architecture notes drift
into describing a model that was never built. The first form of the whole app
is above the fence; below it is the reasoning that has not yet become code.

## The rule everything hangs on

**Help only where asked.** The app annotates the one word you tapped and
nothing else. No furigana over the page, no translation, no "you might also
not know". Recognizing what you already know is the reading practice, and an
app that helps unasked takes it away. Every screen is checked against this
before it is built.

## Two targets, one seam

| | `YomidoriCore` | `YomidoriDictionary` | `YomidoriMeCab` | `YomidoriMangaOCR` | `YomidoriSync` | `YomidoriKit` |
| --- | --- | --- | --- | --- | --- | --- |
| holds | kana and reading helpers, the token model and the OS's tokenizer, the dictionary entry model, the cards and the scheduler | `JMdict`, the reader over the bundled SQLite database, behind Core's `WordDictionary` | MeCab with IPADic behind Core's `Tokenizer`, the one third-party dependency, kept apart so it can be cut | manga-ocr through Core ML, a `CGImage` in and a `String` out, present only when the models are bundled | `CloudSync`, iCloud sync through CloudKit's sync engine, the one code that talks off the device | SwiftUI screens, the camera, Vision text recognition, the palette |
| imports | Foundation | YomidoriCore, the system's SQLite3 | YomidoriCore, Mecab-Swift | YomidoriCore, CoreML | YomidoriCore, CloudKit | SwiftUI, UIKit and Vision (iOS only), YomidoriCore, YomidoriDictionary, YomidoriMeCab, YomidoriMangaOCR |
| tested | headless, coverage-gated | headless, on a fixture built by the same script | headless, on the same fixture | coverage-ignored (the models are not in the tests) | coverage-ignored (CloudKit needs an account; the naming, payload and merges it uses are Core's, tested) | coverage-ignored |

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
- **The capture screen** (Kit, `Capture/`): the page frozen and read.
  `Camera` is the back camera behind a preview that
  only frames, with one round button, the text-scanning glyph named *Read the page*,
  that keeps the next frame of the stream at the sensor's full resolution: a
  frame grab, not a photo capture, so nothing is written to the library and
  there is no shutter sound (mandatory for photo capture in Japan, where the
  app is read). Nothing in the app is named or drawn as a camera's shutter: the
  frame is read, not kept as a photo, and the app says so. The video output
  must be told to deliver full frames; with the photo preset it defaults to
  preview-sized ones, about a megapixel, which is no still to read small print
  from.
  On a phone with several back cameras it opens them as one virtual device, so
  the system hands a page held close to the ultra-wide (macro) and a pinch past
  the wide's reach to the telephoto, both optical; autofocus is kept to the near
  range, since a book is read at arm's length. The pinch on the preview is the
  zoom-before-capture that small print needs. The volume buttons
  and the Camera Control freeze the page too, through the capture event
  interaction the system offers camera apps, so the book stays in the other hand.
  Text can stand in for a page: the paste button beside the photo library
  (the system's, so iOS asks nothing) puts cleaned text, up to twenty thousand
  characters, where the still would be (`TextPage`, a selectable text view that
  reports its selection as Live Text does), and the drawer reads it the same way.
  `Still` is the frozen frame, upright, so orientation is settled once; from the
  picker it is decoded upright. A still also comes from the photo picker, which
  is how a screenshot enters and how the simulator, having no camera, is used.
  Two recognizers run over every still, both shipped with the OS and both on
  device: `TextRecognizer` wraps Vision's `RecognizeDocumentsRequest` (iOS 26)
  for Japanese and yields `RecognizedLine`s with their boxes, vertical columns
  included (confirmed on a paperback, 2026-09-22; the older text request, which
  never read vertical print, is gone), drawn back over the page, tap one to
  read it; `LiveText` wraps VisionKit's `ImageAnalyzer`, the Live Text engine,
  which yields a transcript and, on iOS, its own text selection over the image.
  A third mode reads *up close*: a tap cuts the line under it, as the page pass
  found it, out of the still at full resolution with the paper around it, and
  every engine reads only that; where no line was found a square around the tap
  stands in.
  Recognizers downscale a whole page before reading, so a dense kanji reaches
  them at a fraction of the pixels the sensor caught; the crop hands them the
  pixels back without the reader zooming, and a whole line with clean margins
  reads better than a square that halves the glyphs at its edges. The readout
  sits in a drawer under the still whose height the reader drags and the app
  remembers, most of the screen for the page while looking for a word, more
  drawer once it is found, its content scrolling and its buttons fixed. In every
  mode the frozen still pinches to zoom and drags to pan, a double tap bringing
  it back; the tap on a line or a word is reported in the still's own
  coordinates whatever the zoom, so the geometry seam knows nothing of it. The
  screen shows any of the three, switched at the bottom, so they can be
  compared on the same page.
- **The tap in Vision mode** (`VisionPage`, `RecognizedLine.characterBoxes` in
  Core): the document request gives a box for any range of a line's text, so each
  character's box is kept with its line. A tap picks the line under it and the
  character nearest along the line (across a column hardly counts), which is a
  place in the page's reading, and so a chunk; a selection is outlined by the
  union of its characters' boxes on each line it touches. Without character
  boxes, a character is placed by its share of the line.
- **The page read once** (`PageReading` in Core, `PageReader` in Kit): when a
  page's text is known or changes (a new page, a fix, another tokenizer), every
  line is cut into chunks, off the main thread and one page at a time: the words
  as `WordFinder` finds them and the pieces between (punctuation, particles,
  endings), each with its range in the page's text. The selection is one range of
  that text, kept whole to its chunks, and everything shows it: the recognized-text
  strip (`ChunkFlow`) lights its chunks, the picture outlines it (Vision mode, by
  the characters' boxes) or shows it as Live Text's or the pasted text's own
  selection, and the drawer lists it, the phrase first when it spans several
  chunks (looked up whole, for an expression the tokenizer split) and then each
  word. A tap anywhere selects a word, a long press stretches the selection to
  another; a tap is a lookup in the reading, nothing is parsed again.
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
  answers pitch questions from it; and KANJIDIC2's kanji with KRADFILE's
  components (`KanjiEntry`: readings, meanings, strokes, grade, JLPT level,
  frequency rank) and KanjiVG's strokes in order, SVG paths read by a small
  parser in Core and drawn one after another on the kanji screen. Around a word the reader also finds the
  words it appears in (a scan of the kanji forms, a few milliseconds) and the
  words read the same way (the reading index). The database is
  built from JMdict_e by `Scripts/data/build-jmdict.py` (standard-library
  Python, a few seconds, ~78 MB) into the app target at build time and never
  committed; its `meta` table carries the source dates and the EDRDG attribution.
  The tests read a sliver built by the same script from hand-made sources.
- **`TranscriptReadout`**, **`WordFinder`** and **`WordReadout`** (Kit, Core):
  the drawer under a frozen page. Its header is the collection Keep files a word
  under (a menu, remembered), the tokenizer as a small menu (the system's or
  MeCab, so the same page can be cut both ways) and Copy. A
  selection on the still, or a tap in the *Recognized text* strip (`TokenFlow`,
  folded by default), is tokenized and read as words by `WordFinder`: consecutive
  tokens the dictionary knows as one word join (蛍光灯), an inflected stem finds
  its dictionary form through `Deinflector` (照らされていた → 照らす), lone kana,
  kana-only fragments with no entry and words JMdict marks as particles or
  auxiliaries drop out. Each word is a row: the word, its reading with the pitch
  where known (`WordTitle` puts the reading on a second line when one is
  short), and Keep; a tap anywhere along the row opens the meaning, the system
  dictionary button and *Full entry*, which pushes the entry screen over the
  page. "Not in the dictionary" is what a misread word looks like.
- **`Card`**, **`Sighting`** and **`FileCardStore`** (Core): a card is one word
  in its dictionary form with its reading, the key together; a sighting is the
  word as it was met once, the sentence as it stood on the page, the word's form
  and offset in it, where it was met, and when; never a photo. Keeping a word
  already kept adds a sighting, never a card; the same kanji read another way is
  another card. A card also carries when it was created and last modified (a
  sighting added, a sentence corrected; never a review), its
  three review states, a log of every answer (`ReviewEntry`: date, question,
  grade, overruled or not), the meanings the reader accepts beside the glosses,
  where it stands (waiting, started, or shelved) and the collections it is in.
  The store is one JSON document in Application Support, written whole and
  atomically on every change: a reader's cards number in the hundreds or low
  thousands, which one file reads in a blink, and one file is what a sync or a
  backup copies; Settings shares that file as it is, which is the export. Every shape the file has had still decodes, and the tests keep
  one of each, the cards that once carried page photos and crops among them,
  whose photo fields are no longer read. The reading, pitch and meaning are not
  stored; they are looked up live.
- **Progress** (`Progress`, `RankSnapshot` in Core; `ProgressScreen` in Kit): the
  reviewing done, by day. The answers, how many were right and the seconds spent
  are folded from the cards' own logs (`ReviewEntry` keeps the seconds, capped at
  a minute); the words started come from the cards' start dates; the streak is
  the days in a row with an answer, today forgiven until it ends. The ranks by
  day are the one thing kept apart: `FileRankSnapshots` writes the day's first
  look at the counts to `progress.json`, this device's own, since every device
  sees the same cards. The screen is reached from the Study tab; its span is
  four weeks by day, three months by week, or a year or everything by month
  (`Progress.rollUp`, `RankSnapshot.thinned`), and a finger on a chart puts
  that period's numbers in the caption above it, as the rank chart does.
- **Sync** (`CloudSync` in `YomidoriSync`, `Sync` in Kit): the cards, the
  collections with their covers and the lookup history kept the same on the
  reader's devices through their own iCloud, CloudKit's private database
  driven by `CKSyncEngine`. One record per card, collection and looked-up word
  (`SyncName`, the store key made ASCII; `SyncPayload`, the same JSON the
  stores write), a cover as the collection record's asset, and one record for
  the date the history was last cleared. A card's id is made from its word
  (`WordKey.cardID`, a name-based UUID), so the same word kept on two devices
  is one record, merged like any other. Changes made while sync is off are
  kept (`UnsentChanges`) and sent when it starts. The local files are the
  truth: this device's writes go out as they are made (the stores report them
  as local), another device's are laid over them (reported as remote, so they
  are not sent back), merged by Core's rules only where this device changed
  the same record and had not sent it yet; a save that finds a newer version
  on the server merges it in and goes again on top of it. Each record's server
  system fields are kept so a save updates the version it knows. Deletions are
  CloudKit's own, not tombstones; a zone deleted from iCloud, or a new
  account, is filled again from this device. Pushes wake the engine, and the
  app fetches when it comes to the front. On unless turned off in Settings,
  never in the demo, and nothing happens without an iCloud account.
- **Intake** (`Sanitize`, `Intake`, `ImageIntake` in Core): what comes from
  outside, a shared collection, a record from another device, a photo, pasted
  text, is made safe before it is stored or shown. Text loses control
  characters, bidirectional overrides and isolates (which can make a word read
  other than it is) and byte-order marks, and is cut to a length per field; lists
  are bounded (words per file, sightings per card, answers, tags); a sighting
  whose offset falls outside its sentence is unmarked; a schedule with a zero or
  negative stability is dropped, and the scheduler never divides by one; a
  shared file over five megabytes, a synced record over CloudKit's megabyte and
  a history clear dated past tomorrow are refused. Images are decoded only when
  the data is an image, under sixty megabytes and a hundred megapixels by its
  header, straight to the size wanted and upright; a cover from another device is
  decoded and drawn anew, never stored as it came.
- **`RecordFile`** (Core): the one JSON store under the cards, the collections
  and the lookup history: loaded once, changed under a lock, written whole and
  atomically, and every write reported by the keys it saved and deleted and by
  whether it was made here or came from another device, so sync sends only what
  was done here and the screens refresh for both. The merges sync needs when a
  record changed on two devices at once are Core's too: a card keeps the union
  of its sightings, answers, accepted meanings and collections, each question
  the schedule of its later answer, and where it stands from the side touched
  last; a collection is stamped on every save and the later one wins whole; a
  lookup keeps its later date, and a clear of the history is a date every device
  drops older lookups by, so one that was offline does not bring them back.
- **`Sentence`** (Core): the sentence around a word, from the previous full stop
  to the next with its closing quote, across the page's wrapped lines, which in
  a book are wraps and nothing more; open when the page ends before a full stop.
  Its continuation on the next page is that page's beginning up to its first
  full stop. Tested on a page of wrapped lines with quotes.
- **Keeping a word** (Kit): *Keep* on a word's row saves the sentence it stands
  in, as `Sentence` cuts it, with the word's form and offset, into the current
  collection. No photo of the page is kept: the text is the card, and photos
  would be what makes the cards heavy to sync (they were kept on request until
  2026-09-23; the first launch after deletes them). The card's key is the dictionary entry's headword and reading
  when the word was found, else the tokenizer's form. A spread of several pages
  is read as one text: the + over the picture keeps this page's text and takes
  the next, and `Spread` joins the pages at the seam with no break, so a word
  cut by the page turn tokenizes whole and a sentence runs on. **`CardsView`**
  lists the cards by stack (in review, waiting, shelved), filtered by any number
  of collections or by a tag, each row with its rank mark; **`CardView`** shows
  one: the word with its pitch, the dictionary's sections around it
  (`WordSections`), its collections ticked, the moves between the stacks, the
  reader's own accepted meanings, the dates and the good/again counts per
  question (`CardFacts`), and every sighting with the word marked and a row to
  correct the sentence (the word is found again in the corrected text).
- **`FSRS`**, **`Grade`** and **`ReviewState`** (Core): the free spaced
  repetition scheduler, version 5, with its published default parameters and a
  desired retention of 90 %, with one departure: a lapse costs at most one rank,
  stability divided by four with FSRS's own value as the floor, since the
  model's own drop (four months to three days) felt harsh; a card truly
  forgotten goes back to waiting from the review and returns through a lesson.
  Two grades, Again and Good, mapped to FSRS's 1 and
  3; the state a card carries is stability, difficulty, due and last review with
  the counts, nil until the first review, which makes a new card due at once.
  Intervals are whole days, one at least; a same-day answer uses the short-term
  rule. Tested for the shapes that matter: a first Good comes back in three
  days, a first Again tomorrow, intervals grow, a lapse shrinks stability,
  retrievability is one at review and 90 % at the due date. **`ReviewView`**
  (Kit) runs the due queue one question at a time, the latest sentence with the
  word marked as the front. Every question is answered, not just revealed: the
  reading typed in kana and judged strictly by `ReadingCheck` (Core), katakana
  and half-width folded, long vowels not forgiven; the meaning typed in English
  and judged leniently by `MeaningCheck` (Core) against every gloss and the
  card's own accepted meanings, case, articles, parentheticals and punctuation
  set aside, a whole gloss or a phrase of one, one typo forgiven with a
  transposition counting as one; the pitch picked from every pattern the reading
  allows. The verdict shows with the back and only suggests the grade, the
  prominent of two buttons; on a miss, *Count it right* overrules it and *Add as
  an answer* also keeps the typed meaning on the card. *Show the answer* gives
  up. Every answer is logged on the card with its grade and whether it was
  overruled (`ReviewEntry`), for the graphs to come. No streak, no count kept
  against anyone. The queue is of questions, not cards.
- **Lessons, stacks and ranks** (`Lesson`, `Rank` in Core; `LessonView`,
  `StudyView`, `RankChart` in Kit): a kept card *waits*; only a lesson *starts*
  it, and a *shelved* card (a name, a place) is kept for the record and never
  asked. A lesson takes the next few waiting cards, oldest, newest, random or
  common first (JMdict's mark), from chosen collections or all, and shows each
  whole: Start, Later (back to the stack) or Drop; then *Review them now*. The
  due queue is ordered most recently answered first, a just-started card counting
  from its start, so a short session churns the fresh cards and the backlog
  trails; *Forgot it. Back to waiting* on a review clears the schedule and the
  card returns through a lesson. `Rank` bands the reading's stability in birds:
  nest 0 (shelved), egg 1 (waiting), hatchling 2 (under a week), chick 3 (under
  a month), fledgling 4 (under four months), flying 5 (under a year), migrating
  6; nothing retires. Study draws the ranks as bars in each rank's color with a
  selection, and the mark everywhere is the rank's number on a dot of its
  color, the name beside it where there is room and as the accessibility label
  where not.
- **Collections** (`Collection`, `FileCollectionStore` in Core; `CollectionsView`,
  `CollectionEditor`, `CoverScanView`, `TagsEditor`, `CollectionPicker`,
  `CollectionFilter` in Kit): named groups of cards, a book usually, a card in
  as many as the reader likes, with a note (an author), tags as chips (the
  reader's own words; the ones other collections use are offered) and a cover.
  The cover is scanned with the camera or picked from the photos, and the words
  read off it, Vision's lines tallest first with Live Text filling in, are
  offered for the name and the note so a title is picked rather than typed.
  Covers are the one image the app keeps, scaled to six hundred pixels as JPEGs
  beside the stores (`CoverArchive`), since the reader takes each on purpose.
  Removing a collection only takes it off its cards. Their own JSON beside the
  cards.
  A collection is shared as a `.yomidori` file (`SharedCollection`, JSON, a type
  the app declares and opens): name, note, tags and each word with its sentences,
  never a photo, the cover or a review, so the file is small and the receiver
  starts fresh. Importing merges into the collection of the same name, new words
  waiting, known ones gaining the sentences they lacked, in one write.
- **Kanji** (`KanjiEntry`, `KanjiStroke`, `SVGPath` in Core; `KanjiView`,
  `StrokeOrderView`, `WordDetails`, `WordSections` in Kit): KANJIDIC2's readings,
  meanings and school facts, KRADFILE's components and KanjiVG's strokes are in
  the same database. A word's screen, from a card, a search or *Full entry*,
  lists every reading with its pitch, the senses, the kanji as rows, the words
  read the same way with their pitch side by side (はし: 橋 箸 端) and the words
  it appears in (a scan of the kanji forms, milliseconds); a kanji opens with its
  readings, meanings, stroke count, grade, JLPT level, frequency, components,
  the words it is in, and its stroke order drawn stroke by stroke over the faint
  finished form, a tap replaying it. `SVGPath` reads the path subset KanjiVG
  writes.
- **`AboutView`** (Kit): the name, the version with its build and commit, the
  promise that nothing leaves the device, the pitch notation explained on four
  words, and the notices every bundled license asks for, which are the
  repository's own THIRD_PARTY_NOTICES.md bundled as a resource so there is one
  copy to keep current. **`SettingsView`**: the swipe-back switch, on as iOS has
  it; off, the navigation controller's pop gesture is disabled on every screen
  through a small UIKit helper (`SwipeBack`), for a reader whose swipe meant a
  word.
- **Selecting on the page** (Kit, `LiveTextSelection`): in Live Text mode the
  word selected on the still itself, through the engine's own selection, is the
  word the readout shows, with its line as the sentence for Keep; the selection's
  range into the transcript finds the line. Live Text tells no one when the
  selection changes, so the image's coordinator polls it four times a second
  while that mode is showing and stops when it goes.
- **Lookup history** (`Lookup`, `FileLookupHistory` in Core; `LookupHistoryView`
  in Kit): every word opened from a search and every word shown under a page,
  one line per word with the latest date, newest first, capped at five
  hundred, in its own JSON; particles, auxiliaries and the copula are skipped
  by JMdict's part-of-speech marks. It is what the search tab shows while the
  field is empty; a swipe forgets a line, a button all.
- **Typed search** (`SearchView`, `EntryView` in Kit; `SearchQuery` and
  `WordDictionary.search` in Core): for words met off the page. Kana or kanji
  finds headwords and readings that start with it, a hiragana query tried as
  katakana too since JMdict spells loanwords so; anything else searches the
  English glosses through a full-text index the build script adds to the
  database. No mode switch, the query says which; common words first. A result
  opens as a tapped word does, with its pitch, senses and the system dictionary,
  and *Keep* makes a card with no sentence yet, which the review then asks by
  the word alone until a page supplies one.
- **Kanji by parts** (`KanjiPart` in Core, `KanjiByPartsView` in Kit): KRADFILE's
  parts by stroke count, as a grid in a sheet from search. KRADFILE writes some
  radicals as a kanji that contains them (汁 for 氵, 化 for 亻); those show as the
  radical with its own stroke count and query as written. Chosen parts give the
  kanji that have them all, fewest strokes first, and fade the parts no kanji
  shares with them; a kanji picked closes the sheet and goes in at the search
  field's cursor, or over its selection (`Insertion`, in UTF-16 offsets as the
  field counts them, a stale cursor held to the text, never splitting a
  character; the field's cursor comes from iOS 26's `searchSelection`). It opens
  from a button at the end of the search box itself: SwiftUI's search field takes
  no accessory, so `SearchFieldButton` finds the `UISearchTextField` once it has
  the keyboard and sets the button as its right view, and nothing happens if it
  is not found.
- **`MangaOCR`** (its own target): manga-ocr, a vision transformer reading one
  line or bubble of Japanese at a time, vertical included, converted to Core ML
  by `Scripts/data/build-mangaocr.py`: the encoder as it is, the decoder
  re-expressed as one cache-free step with an explicit mask, the vocabulary
  beside them; ~210 MB at half precision, Apache 2.0, optional at build and absent from
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
- **`AppRoot`, the tabs and the page** (Kit): five along the bottom, each with
  its own stack (`TabStack`): Home (the name, the Read button, Review and Lesson
  with their counts, Settings and About in the corner; its path stored so a
  restart reopens where it was), Read (the live camera, or the frozen page; the
  tab bar stays, collapsing into its pill as the drawer scrolls), Study, Cards
  and the search pill. Tapping the tab already
  showing pops its stack and scrolls its list to the top (`TabTaps`); on Read it
  is the retake. The page's state (`CaptureState`: the still, its pages, the
  mode, the lines, the analysis or a transcript of its own, the zoom) lives above
  the screen, so switching tabs or pushing an entry over the page keeps it. The
  drawer follows the finger, settles at one of three detents on release (a
  strip, half, most of the screen; a double tap on the handle goes to the
  largest and back), and the page is laid out down to the drawer's settled edge,
  its zoom kept. The camera follows the phone's orientation through a rotation
  coordinator, and a tap on the live image focuses there.
- **Demo mode** (`YomidoriKit/Demo`): launched with `-yomidori-demo`
  (`make demo-iphone`), every store lives in a folder wiped and reseeded at each
  start and the settings in their own suite. `DemoText` and `DemoData` seed a
  hundred cards from the openings of four public-domain works (漱石, 太宰, 芥川,
  賢治) spread over the ranks as months of reading would leave them, collections
  with rendered covers, a shelf of names, searched words and a history; dates
  relative to now, so every launch is the same. `DemoRenderer` draws the page
  and the covers from text with CoreText, and Read opens on that page with its
  transcript known, since Live Text does not run on the simulator. The same cast
  is meant for the App Store screenshots.

## Planned

What is built is above; each section here is what remains of the intent and the
reasoning behind it. The [ROADMAP.md](ROADMAP.md) says in which order it is tried.

### Capture: positions on a vertical page

Live Text is the recognizer a page opens in: its own selection over the still
is the tap, and the readout, Keep and the sentences work from its text. What it
withholds is positions, and Vision's `RecognizeDocumentsRequest` (iOS 26)
supplies them: on a real paperback (2026-09-22) it read the vertical Mincho
columns as lines with boxes, where the older text request, now gone, read
nothing vertical. Each line comes with its direction and a box for any range of
its text.
Built on the boxes: the app's own tap in Vision mode (see *What exists*). Still
to build: a furigana filter by height, dropping the thin
ruby lines beside the columns, if the request returns them as lines of their
own. Once the tap on the page is the app's own, whether Live Text's selection
stays the default is a field question. manga-ocr over a whole page remains
possible as a second reading, the boxes cutting the page into the lines it
reads, but no longer stands between the app and positions.

The recognized characters are shown as editable text on the card, and one
misread character is fixed on the page itself: `CharacterFix` offers the
characters of the dictionary's words spelled like the rest of the word (a `LIKE`
with one wildcard over the kanji forms, a stem also tried as its dictionary
forms), and the correction is a `TextFix` over the transcript, so the lookup,
the kept sentence and the copy all read corrected. Editing longer runs on the
page is still to do.

The camera is one source of a still, not the only one. A screenshot of an
e-book app or a web page enters the same screen through the photo picker, and
later a share extension that receives the image from the screenshot preview;
from the still on, camera and screenshot are the same path, vertical columns
included. Watching the screenshots album is deliberately not offered: it needs
photo-library access for everything in exchange for one tap the share sheet
already saves.

### The tokenizer and its dictionaries

A reading needs a tokenizer with a dictionary that carries readings and pitch,
and there is no first-party one. What the app runs: the OS's analyzer
(`CFStringTokenizer`, its Latin transcription turned back to kana) cuts the page
and gives readings in context, `Deinflector` takes a cut stem to the forms
JMdict lists, JMdict gives the dictionary form and the meanings, Kanjium the
pitch; no third-party code at runtime. MeCab with IPADic stays in its own target
as the switchable alternative under the page, because on real pages it still
earns comparison: it knows dictionary forms and parts of speech, and it gives
name readings where the system does not (照 あきら). The candidates as they
were weighed:

| | readings | pitch | size | license |
| --- | --- | --- | --- | --- |
| The OS's analyzer (`CFStringTokenizer`, Latin transcription → kana) | yes, in context; measured equal to UniDic's on the fixture | no | none | none |
| MeCab + UniDic | yes, per lexeme | yes, with compound rules | large (the lite dictionary is tens of MB, the full one far more) | BSD/LGPL/GPL |
| MeCab + IPADIC | yes | no | ~50 MB | BSD-style |
| Apple `NLTokenizer` + JMdict furigana data | segmentation only from Apple; readings from data | no | small | JMdict CC BY-SA 4.0 |
| Kanjium pitch database | — | yes, keyed to JMdict headwords | small | free |

Whatever third-party code stays is the one deliberate exception to "no
third-party code at runtime", and its attribution is on the About screen.

### Scheduling and storage

The scheduler, the lessons, the ranks and the one-document store are built (see
*What exists*). What remains: the FSRS parameters stay the published defaults
until there are enough answers in the cards' logs to fit them, a question for
much later; graphs from those logs (intake against reviews over time, the rank
counts as a history); a fuller export, and its import; and iCloud sync of the document, the Mac section's first step.

### Dictionary and meaning

The meaning is one tap away, never shown unasked; the English gloss from JMdict
and the system dictionary's Japanese one are built (see *What exists*). What
remains is a ja gloss of the app's own, from Japanese Wiktionary where it has
one, since 大辞林 is a view and cannot be quoted.

### Pitch accent and audio

Word-level pitch is built (`PitchAccent`, `PitchReading` and the pick in review,
see *What exists*). What remains is the sentence: its contour, which shifts
with conjugation and compounding, would come from UniDic's connection rules or
Open JTalk's
accent estimation, which VOICEVOX exposes together with speech. All of it is
standard Tokyo accent, which every free source and most paid ones are limited
to.

### Theme

The palette is built (`Palette`, see *What exists*) and follows the system; what
remains is a manual override, and the highlight rule below once the app's own
tap draws one. Dark mode is 夜緑 proper: deep green accent on near-black. Light
mode is the same green on paper-white. The green is the frame and the accent —
the tapped word, the buttons, the bird — never the surface behind text. The highlight of a tapped
word sits on a photograph, so it is a translucent fill with a solid underline,
legible over cream paper and gray print in both modes.

### Localization

Both interfaces exist, every string with its Japanese; what remains is the
native-ear review before the store (the roadmap's *Store* section). The name is
Yomidori on one storefront and ヨミドリ on the other, one bundle. The Japanese
interface is for Japanese users,
which the school-age 国語 idea in the roadmap would need, and it is written by a
native ear, not translated from the English.
