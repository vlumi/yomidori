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
before it is built. The one place with a reading over every word is the
*Recognized text* strip in the drawer, folded until the reader opens it, which
is asking.

## Five targets, one seam

| | `YomidoriCore` | `YomidoriDictionary` | `YomidoriMeCab` | `YomidoriSync` | `YomidoriKit` |
| --- | --- | --- | --- | --- | --- |
| holds | kana and reading helpers, the token model and the OS's tokenizer, the dictionary entry model, the cards and the scheduler | `JMdict`, the reader over the bundled SQLite database, behind Core's `WordDictionary` | MeCab with IPADic behind Core's `Tokenizer`, the one third-party dependency, kept apart so it can be cut | `CloudSync`, iCloud sync through CloudKit's sync engine, the one code that talks off the device | SwiftUI screens, the camera, Vision text recognition, the palette |
| imports | Foundation | YomidoriCore, the system's SQLite3 | YomidoriCore, Mecab-Swift | YomidoriCore, CloudKit | SwiftUI, UIKit and Vision (iOS only), AppKit (macOS only), YomidoriCore, YomidoriDictionary, YomidoriMeCab, YomidoriSync |
| tested | headless, coverage-gated | headless, on a fixture built by the same script | headless, on the same fixture | coverage-ignored (CloudKit needs an account; the naming, payload and merges it uses are Core's, tested) | coverage-ignored |

The rule: **testable logic goes in YomidoriCore.** The Kit is one for the
phone and the Mac: `swift test` runs it on the Mac, and the Mac app
(`Yomidori-macOS`, the same bundle id under the same App Store record) is the
same Kit under an AppKit shell. UIKit-, camera- and Vision-only code sits
behind `#if os(iOS)` / `#if canImport(UIKit)`; where the Mac needs the same
thing its own way there is an AppKit branch (appearance-aware colors, the
pasteboard, the Dictionary app opened on a word), and where it does not (the
camera, the orientation lock, the phone's Shortcuts section) the
fallback does nothing and the view is hidden. On the Mac there is no camera
and no drawer: Read is the home tab, and the page is one pane with two
states (`MacReadView`): *Text*, a box the reader pastes into (`TextBox` over an
`NSTextView`, which says when something was pasted), and *Reading*, the same
text laid out as its reading, the readings over the words (`ReadingPage`),
selected by click, shift-click, ← and → (⇧ stretches, Escape clears; the keys
are watched at the window, `KeyCatcher`, since the page is no text view). A
paste goes to reading by itself once read; *Edit* (⌘E) and *Read* (⌘↩) go
between. A picture is a page too: dropped on the pane, pasted (⌘V, in the box
or on the page) or opened (File › Open a Picture…, ⌘O), it is read by both
recognizers as on the phone and shown with Live Text's own selection over it
(`PictureView`, the Mac's `ImageAnalysisOverlayView` tracking an image view in
a magnifying scroll view); *Reading* shows its transcript as the page instead,
*Clear* (⌘⌫) puts it away. The words of the selection stand beside. The
sections are a sidebar with ⌘1 … ⌘4 (`SectionCommands`), and switching to
Read or Search puts the focus in the box or the field. The dictionary (the
search tab, named for what it is) with room is three columns: the history,
which folds away; the results under the field, which is the column's own (⌘F)
and not the window toolbar's; and the entry picked from either, with what it
opens (a plain split under the
sections' sidebar, its buttons in the columns' title bars: a second navigation
sidebar, or items of the split's own beside an entry's, puts two of a kind in
one toolbar, which AppKit refuses), the kanji parts a sized sheet; Cards likewise, the
list on the left and the card on the right, ↑ and ↓ moving through it and ⌫
forgetting after asking. The review and the lesson have their keys wherever
there is a keyboard (⌘↩ shows the answer, the digits pick a pitch, ⌘Y counts a
miss right, ⌘⇧A adds the typed meaning, ⌘⌫ sends the card back; ↩, ⌘→ and ⌘⌫
in a lesson) and read at most 640 points wide. The app is opened
in the background by `make run-mac`, so a build every few minutes takes no
screen from anyone. Settings is ⌘, and About is the app menu's. [docs/big-screen-plan.md](docs/big-screen-plan.md)
has what remains.

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
  On a phone the Read tab stays upright, as the Camera app does
  (`OrientationLock`): the controls keep to the phone's bottom edge and only
  their icons turn with it (`HeldOrientation`, `turnsWithPhone`); an iPad turns
  as it likes. The video output's angle is set once and never touched between
  shots, since turning it makes the camera rebuild its pipeline and the frame
  after comes dark, or from another of its cameras; the frame is turned in
  software instead (`QuarterTurn` in Core), the way the icons stood when the
  button was pressed, which is what the reader saw, and on an iPad the way the
  preview stood. The camera's own reading of gravity is not asked: on a train it
  leans with the braking and the curves, and a still came out sideways under an
  upright screen.
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
  never read vertical print, is gone), and with the furigana Vision reads into a
  line taken out again (`droppingRuby`: a kana well under the line's own
  characters in size and off its axis, so っ and ゃ stay), and lines that are
  furigana of their own dropped. Vision works at a size of its own however
  large the frame — the same 0.4 s for 48 megapixels as for 2,000 pixels — so
  on a full page of small print the furigana melt into the kanji beside them
  and the kanji come out wrong, while a crop reads right; a dense page (the
  characters' pitch under a fortieth of the frame's long side) is therefore read
  again in four overlapping tiles at once, and `TileStitch` (Core, tested) lays
  the tiles' characters into the whole page's lines, each from the tile whose
  centre is nearest so the seams echo nothing, furigana dropped as above; on a
  rendered test page this halved Vision's misreadings and put 名前, 所, 吾輩,
  獰悪 and 書生 right. `make demo-iphone PICTURE=<path>` reads a picture file as
  a page for looking at this. `LiveText` wraps
  VisionKit's `ImageAnalyzer`, the Live Text engine,
  which yields a transcript and, on iOS, its own text selection over the image.
  The readout
  sits in a drawer under the still whose height the reader drags and the app
  remembers, most of the screen for the page while looking for a word, more
  drawer once it is found, its content scrolling and its buttons fixed; in a
  regular width lying down, an iPad on its side, the same content stands in a
  440-point column beside the page instead, as on the Mac, with no drawer; Cards and
  the Dictionary are splits there too, list beside card or entry, picked as the Mac
  picks them, since a list that selects takes the taps a link would. In every
  mode the frozen still pinches to zoom and drags to pan, a double tap bringing
  it back, and pans half the view's width beyond its own edge on every side
  (`Zoom.margin`), so a word at the page's edge comes out from under the
  controls that stand over it there; the tap on a line or a word is reported
  in the still's own coordinates whatever the zoom, so the geometry seam knows
  nothing of it. What
  is done to the page stands in one column over the picture (`PageControls`),
  on the side of the hand that holds the phone, chosen in Settings: the
  spread's buttons on top, then the camera for another photo and the zoom as a
  slider (`ZoomSlider`) nearest the thumb. The screen shows the still's
  `preview`, drawn down to 3,072 pixels on the long side where the frame is
  made, off the main thread, since putting the full frame into an image view
  held the main thread for seconds after the shutter. Live Text analyzes that
  same preview — its overlay draws against the image it analyzed, and analyzed
  at one size and shown at another the highlight landed a tenth off — while
  Vision reads the full 48-megapixel frame, its boxes being normalized. While the page is being read a spinner lies
  over the whole picture. The + for a spread shows the camera with *Cancel* at
  the top (`SpreadNotice`), which brings the page already taken back.
  The screen shows any of the three modes, switched at the bottom, so they can
  be compared on the same page.
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
  otherwise. A stem with its ending cut off after it (吹き出し + た, 揺すり +
  ながら, 見 + て) is a verb or an adjective whatever noun the dictionary spells
  the same way (`attachedEndings`, `isEnding`): its deinflections' conjugable
  entries come first, the common one before an old one (見せ → 見せる, not 見す),
  and the endings that follow the first (て + い + た) are the inflection, not
  words. A word that comes with its ending still on and is in no dictionary as
  it stands is taken by the ending to the forms it may be of (`conjugated`:
  頼みたい → 頼む, 認めよう → 認める, 読もう → 読む), and only a verb or an
  adjective is taken from those, since the stem alone may be a noun. Tested on
  the stems the tokenizer fixture actually produces, and probed against the
  built dictionary on real sentences when the rows change.
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
  app's one notation, decided here. Where the accent dictionary has no pitch,
  an estimate is shown in the same notation, phrase by phrase for an expression
  (`PitchPhrase`: けんとうが [3] and つく [1] for 見当がつく), marked *estimated*
  (`EstimatedPitch`) and never asked in a review, which asks only what the
  dictionary gives. The estimates are made at build time
  (`Scripts/data/estimate-pitch.py`, `make pitch`): an expression's accent
  phrases from Open JTalk; a compound's drop by the habit of its last element,
  learned from the compounds Kanjium does have (88% agreement on compounds held
  out, against 58% for Open JTalk's own rule), and none where the last element
  is unfamiliar; a single kanji word from Open JTalk's lexicon. Nothing of it
  runs on the phone.
- **`Speaker`** (Kit): a sentence read aloud by the system's own Japanese voice,
  the best one installed, on the device and at a press: on a card's sentence,
  in a lesson, and the sentence around the selection on the page
  (`PageReading.sentence(around:)`). Its pitch is fair, not always right; the
  drawn pitch is the dictionary's word.
- **`DictionaryEntry`** (Core) and **`JMdict`** (its own target): a word as
  JMdict has it, kanji forms, readings, senses with parts of speech and glosses,
  and its frequency mark; read from a SQLite database through the system's own
  SQLite, by exact kanji form or reading, common words first. The same database
  holds Kanjium's accent table, keyed by headword and reading, and the reader
  answers pitch questions from it; the estimates in a table of their own
  (`accent_estimate`), absent from a database built without them; and KANJIDIC2's kanji with KRADFILE's
  components (`KanjiEntry`: readings, meanings, strokes, grade, JLPT level,
  frequency rank) and KanjiVG's strokes in order, SVG paths read by a small
  parser in Core and drawn one after another on the kanji screen. Around a word the reader also finds the
  words it appears in (a scan of the kanji forms, a few milliseconds) and the
  words read the same way (the reading index). The reader works on a queue of
  its own, each SQL prepared once and its statement kept, the entries and the
  word matches it has read kept in bounded caches, since a page asks for the
  same words over and over; a typed search runs off the main thread. The database is
  built from JMdict_e by `Scripts/data/build-jmdict.py` (standard-library
  Python, a few seconds, ~78 MB) into the app target at build time and never
  committed; its `meta` table carries the source dates and the EDRDG attribution.
  The tests read a sliver built by the same script from hand-made sources.
- **`TranscriptReadout`**, **`WordFinder`** and **`WordReadout`** (Kit, Core):
  the drawer under a frozen page. Its header is the collection Keep files a word
  under (a menu, remembered), the tokenizer as a small menu (the system's or
  MeCab, so the same page can be cut both ways) and Copy. It lists the
  selection, a range of the page's reading wherever it was made: on the
  picture, or in the *Recognized text* strip (`ChunkFlow`, folded by default,
  its title staying at the top while its lines scroll under it). The words are
  `WordFinder`'s, found when the page was read: consecutive
  tokens the dictionary knows as one word join (蛍光灯), an inflected stem finds
  its dictionary form through `Deinflector` (照らされていた → 照らす), lone kana,
  kana-only fragments with no entry and words JMdict marks as particles or
  auxiliaries drop out. Each word is a row: the word, its reading with the pitch
  where known (`WordTitle` puts the reading on a second line when one is
  short), and Keep; a tap anywhere along the row opens the meaning, the system
  dictionary button and *Full entry*, which pushes the entry screen over the
  page. Under a word joined from several stand the words it is made of
  (`WordFinder.parts`, kept on the chunk: トロイ and 木馬 under トロイの木馬), each
  read and kept by itself, since the reader may have wanted the one; a piece in
  hiragana alone is left out as the whole's ending, and a stem in a verb joined
  from stems (走り + 出し) reads as its verb. A word with a card carries a mark
  that opens the card over the page;
  where the card lacks this page's sentence, Keep reads *Add this sentence*.
  "Not in the dictionary" is what a misread word looks like, and it is fixed
  on the spot (`FixButton`, `CharacterFixView`): one character, from the
  characters of the dictionary's words spelled like the rest of the word
  (`CharacterFix`: a `LIKE` with one wildcard over the kanji forms, a stem also
  tried as its dictionary forms), or the run retyped whole where it stays
  within a line (`PageFix`). Either is a `TextFix` over the transcript, so the
  lookup, the kept sentence and the copy all read corrected, and it is applied
  once its sheet has gone, since a row taken away under its own sheet froze the
  screen.
- **`Card`**, **`Sighting`** and **`FileCardStore`** (Core): a card is one word
  in its dictionary form with its reading, the key together; a sighting is the
  word as it was met once, the sentence as it stood on the page, the word's form
  and offset in it, where it was met, and when; never a photo. Keeping a word
  already kept adds a sighting, never a card; the same kanji read another way is
  another card. A card also carries when it was created and last modified (a
  sighting added, a sentence corrected; never a review), its
  three review states, a log of every answer (`ReviewEntry`: date, question,
  grade, overruled or not, and the seconds it took), the meanings the reader accepts beside the glosses,
  where it stands (waiting, started, or shelved) and the collections it is in.
  The store is one JSON document in Application Support, written whole and
  atomically on every change: a reader's cards number in the hundreds or low
  thousands, which one file reads in a blink, and one file is what a sync or a
  backup copies. Settings shares a backup (`Backup` in Core): the cards, the
  collections and the lookup history as one JSON file, the covers left out;
  and restores one, merged as sync merges and taking nothing away, a card
  joining its word's card whatever id the file gave it, each record cleaned as
  any coming in. The cards file alone, which earlier builds shared, restores
  too. Every shape the file has had still decodes, and the tests keep
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
  that period's numbers in the caption above it, as the rank chart does. Ahead
  of today the Study tab says what is coming (`Upcoming` in Core,
  `UpcomingReviews` in Kit): the questions that come due in each quarter of
  the next seven days, stacked in the colors of their cards' ranks with a
  hairline between the days, what is overdue in now's bar, and how many lie
  beyond; a finger on a bar puts its span, count and ranks in the caption, the
  whole week's otherwise. So a wall is seen before it arrives, and whether it
  is hatchlings or old birds.
- **A still from outside** (`ReadInYomidori` in the app target, `StillInbox` in
  Kit): an App Intent, an action in Shortcuts, takes an image and opens the Read
  tab on it as a new page, decoded and limited as any image coming in. After
  Shortcuts' *Take Screenshot*, on Back Tap or the Action button, it reads what
  is on the screen of any app, and nothing goes to Photos. The intent lives in
  the app target, where Shortcuts finds it; the Kit only takes the image.
- **The icon's count** (`BadgeSchedule` in Core, `AppBadge` in Kit): on when
  the reader turns it on in Settings, which asks for badges alone. The questions
  due now are set at once; the rest come due while the app is closed, so each
  hour one does, a silent notification carrying only the count is scheduled for
  that hour's end, the first sixty of them. Redone on every change to the cards,
  a sync's included, and as the app goes to the background.
- **Sync** (`CloudSync` in `YomidoriSync`, `Sync` in Kit): the cards, the
  collections with their covers and the lookup history kept the same on the
  reader's devices through their own iCloud, CloudKit's private database
  driven by `CKSyncEngine`. One record per card, collection and looked-up word
  (`SyncName`, the store key made ASCII; `SyncPayload`, the same JSON the
  stores write), a cover as the collection record's asset, one record for
  the date the history was last cleared, and one for the study settings
  (`StudySettings`: the retention, the lesson's order and size, dated; the
  later change wins; `StudySettingsBridge` in Kit keeps it and the defaults the
  screens read the same, so what a device keeps to itself — look, hand, layout
  — stays out of it). A card's id is made from its word
  (`WordKey.cardID`, a name-based UUID), so the same word kept on two devices
  is one record, merged like any other. Changes made while sync is off are
  kept (`UnsentChanges`) and sent when it starts. The local files are the
  truth: this device's writes go out as they are made (the stores report them
  as local), another device's are laid over them (reported as remote, so they
  are not sent back), merged by Core's rules only where this device changed
  the same record and had not sent it yet; a save that finds a newer version
  on the server merges it in and goes again on top of it. Each record's server
  system fields are kept so a save updates the version it knows — kept only
  once the store has written the record, so one that could not be written is
  not held as the server's version: its next save goes up without the fields,
  and the conflict that answers brings the server's copy down to merge; the
  failed write is reported as the sync's status. Deletions are
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
  atomically (and on a phone unreadable while it is locked, unless already open
  — `Data.WritingOptions.store`, the sync state and a file to share the same),
  and every write reported by the keys it saved and deleted and by
  whether it was made here or came from another device, so sync sends only what
  was done here and the screens refresh for both (`Cards.changes(of:)`, which a
  screen listens to for the kinds of record it shows). The file is read record
  by record: one that does not decode, written by a newer build perhaps, is
  kept as it is and written back with the rest, and a file that is no list at
  all is moved aside under a dated name, never written over. What lies in the
  app's folder: `cards.json`, `collections.json`, `lookups.json` with
  `lookups.cleared.json` (the date the history was last cleared),
  `progress.json` (the ranks by day, this device's own), `Covers/`, and
  sync's own three, `sync-unsent.json`, `sync-state.json` and
  `sync-fields.json`. The merges sync needs when a
  record changed on two devices at once are Core's too: a card keeps the union
  of its sightings, answers, accepted meanings and collections, each question
  the schedule of its later answer, and where it stands from the side touched
  last; a collection is stamped on every save and the later one wins whole; a
  lookup keeps its later date, and a clear of the history is a date every device
  drops older lookups by, so one that was offline does not bring them back.
- **`Sentence`** (Core): the sentence around a word, from the previous full stop
  to the next, across the page's wrapped lines, which in a book are wraps and
  nothing more; open when the page ends before a full stop. A quotation is one
  piece: a full stop inside 「」 ends nothing, and what follows the quote (と呟い
  た) stays with it, unless the quote stands on a line of its own as dialogue
  does — then it is a sentence by itself; a quotation longer than 120
  characters, or one running off the page, is cut at its own full stops. A line
  that is only digits, Latin and marks — a page number, a running head — never
  joins a sentence. The depth of quotation at the word is counted from the top
  of the page. Its continuation on the next page is that page's beginning up to
  its first full stop. Tested on wrapped lines, dialogue and furniture.
- **Keeping a word** (Kit): *Keep* on a word's row saves the sentence it stands
  in, as `Sentence` cuts it, with the word's form and offset, into the current
  collection. No photo of the page is kept: the text is the card, and photos
  would be what makes the cards heavy to sync (they were kept on request until
  2026-09-23; the first launch after deletes them). The card's key is the dictionary entry's headword and reading
  when the word was found, else the tokenizer's form. A spread, two pages and
  no more, is read as one text: the + over the picture keeps this page whole (its photo,
  Vision's lines, Live Text's analysis) and takes the next, and `Spread` joins
  the pages' texts at the seam with no break, so a word cut by the page turn
  tokenizes whole and a sentence runs on. The picture shows both pages as one
  sheet (`SpreadLayout`), zoomed and panned as one: the next page left of a page
  of columns, under a page of rows, and moved round by hand if the guess is
  wrong. Each page is still its own photo, read and selected in on its own, and
  a selection carries the page it is on. **`CardsView`**
  lists the cards in sections that fold away, the sort being the grouping
  (`CardSort` in Core: by rank, highest first, or by the month a card was kept
  or last changed, newest first), filtered by any number of collections or by
  a tag and by the kind of word (`WordClass` in Core: noun, verb, adjective,
  adverb, expression or other, folded from JMdict's codes on the entry's first
  sense, looked up by word for a card kept without its entry's id), each row
  with its rank mark; several are picked at
  once, through *Select* on the phone or by picking several rows on the Mac, and
  put in a collection or taken out of one together (`CardsBatch`; one write in
  the store, so one change for sync to send); **`CardView`** shows
  one: the word with its pitch, the dictionary's sections around it
  (`WordSections`), its collections ticked, the moves between the stacks, the
  meanings that count in a review (the dictionary's glosses until the reader
  takes one out or adds one; then the reader's own list, `acceptedMeanings`),
  the dates and the good/again counts per question (`CardFacts`), and every sighting with the word marked and a row to
  correct the sentence (the word is found again in the corrected text).
  *Add a sentence* takes one typed or pasted, for a word met off the page.
- **`FSRS`**, **`Grade`** and **`ReviewState`** (Core): the free spaced
  repetition scheduler, version 5, with its published default parameters and a
  desired retention of 90 %, or 95 % by a switch in Settings (*Aim to
  remember*, `SettingsKey.retention`, per device, counting from the next
  answer): the same stability, each word back about twice as often. One
  departure: a lapse costs at most one rank,
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
  (Kit) runs the due queue (`ReviewQueue` in Core: the front item up, a miss back
  three questions on, a question asked once a repeat that counts for nothing,
  the card as answered standing in its other questions) one question at a time, a sentence with the word
  marked as the front. How many questions are left and what is asked
  (`QuestionTag`, a colored label with its icon) stand in the navigation bar
  beside a small title, which leaves the screen to the sentence. Every question is answered, not
  just revealed: the
  reading typed in kana and judged strictly by `ReadingCheck` (Core), katakana
  and half-width folded, long vowels not forgiven; the meaning typed in English
  and judged leniently by `MeaningCheck` (Core) against the card's meanings
  that count, case, articles, parentheticals and punctuation set aside, a whole
  meaning or a phrase of one, one typo forgiven with a transposition counting
  as one, and the same words in another form (cut for cutting); the pitch
  picked from every pattern the reading allows. The field is UIKit's
  (`AnswerField`), since only there can the keyboard be asked for: each kind
  of question has an input context of its own, so the keyboard last used for a
  reading comes back for the next reading, and a meaning takes the alphabet. *Check*, on the right where the confirming button
  goes, or Return judges what is typed. A right answer is good at once
  and the next question comes; a miss shows the part asked and takes Again,
  unless *Count it right* overrules it or *Add as an answer* also keeps the
  typed meaning on the card. *Show the answer* with nothing typed gives up, and
  is never good; with something typed it checks that first, so a right answer
  is right whichever button was pressed.
  A miss comes back three questions on until it is answered right, but only
  the first answer counts, in the schedule, the log and the summary; one left
  unfinished when the reader stops comes back as its schedule has it.
  The queue is shuffled, and each question shows one of the card's sentences
  at random, with the card's own form beside it on a reading question where
  the sentence has another. The question scrolls, so a long sentence shows whole,
  and its sentence can be corrected there and then; an emptied queue ends in a
  summary of the sitting (`SessionSummary`), as a lesson ends in its counts.
  After a lesson, *Practice them now* drills the cards it started
  (`Screen.practice`, the same view): every question, a miss coming back three
  questions on, until each is answered right; there every answer counts in the
  schedule, the repeats too. Every answer that counts is logged on the card
  with its grade, its seconds and whether it was overruled (`ReviewEntry`),
  which is what Progress draws from. No count is kept against anyone: the
  streak is the reader's own, and a day missed only starts it again. The queue
  is of questions, not cards, so a missed pitch brings back the pitch and
  never the reading or the meaning.
- **Lessons, stacks and ranks** (`Lesson`, `Rank` in Core; `LessonView`,
  `StudyView`, `RankChart` in Kit): a kept card *waits*; only a lesson *starts*
  it, and a *shelved* card (a name, a place) is kept for the record and never
  asked. A lesson takes the next few waiting cards, oldest, newest, random or
  common first (JMdict's mark), from chosen collections or all, and shows each
  whole: Start, Later (back to the stack) or Drop; then *Practice them now*.
  The store hands the due questions most recently answered first, which is the
  order the counts and the icon's number are taken from; a review shuffles
  them. *Forgot it.
  Back to waiting* on a review clears the schedule and the card returns
  through a lesson. `Rank` bands the reading's stability in birds, numbered
  from the egg: egg 0 (waiting), hatchling 1 (under a week), chick 2 (under a
  month), fledgling 3 (under four months), flying 4 (under a year), migrating
  5; the nest (shelved) is outside the climb, raw value −1 so it sorts first
  and a dash where the others show their number; nothing retires. A stored
  count (`RankSnapshot.counts`) is indexed by `Rank.index`, the nest first.
  Study draws the ranks as bars in each rank's color with a selection, and the
  mark everywhere is the rank's number on a dot of its color, the name beside
  it where there is room and as the accessibility label where not.
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
  promise that everything is read on the device and nothing is sent anywhere
  but to the reader's own iCloud while sync is on, the pitch notation explained
  on four words, and the notices every bundled license asks for, which are the
  repository's own THIRD_PARTY_NOTICES.md bundled as a resource so there is one
  copy to keep current. **`SettingsView`**: the side the page's controls stand
  on; the look (`Appearance`: the
  device's, light or dark, `chosenAppearance()` on every window's root) and the
  language (`AppLanguage`: the device's, English or Japanese, written to
  `AppleLanguages` for the system to read at the next start, with a notice
  until then); the retention aimed for; the count on the app's icon; how to
  read any screen through Shortcuts; iCloud sync with its state; and the
  backup, shared and restored.
- **Selecting on the page** (Kit, `LiveTextSelection`, `LiveTextImage`): in
  Live Text mode the engine's own selection on the still is the selection, told
  by the interaction's delegate as it changes and widened to whole chunks of
  the page's reading. Its ranges count characters of the interaction's own
  text, which is not always the analysis's transcript to the character, so that
  text is the one kept per page and counted in. A selection made elsewhere,
  in the strip, is asked of the page view and shown as its own. Each page of a
  spread has its own interaction, and a selection on one clears the other's.
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
  its zoom kept. A tap on the live image focuses there.
- **Demo mode** (`YomidoriKit/Demo`): launched with `-yomidori-demo`
  (`make demo-iphone`), every store lives in a folder wiped and reseeded at each
  start and the settings in their own suite. `DemoText` and `DemoData` seed a
  hundred cards from the openings of four public-domain works (漱石, 太宰, 芥川,
  賢治) spread over the ranks as months of reading would leave them, collections
  with rendered covers, a shelf of names, searched words and a history; dates
  relative to now, so every launch is the same. `DemoRenderer` draws the page
  and the covers from text with CoreText, and Read opens on that page with its
  transcript known, since Live Text does not run on the simulator. The same cast
  is meant for the App Store screenshots. The launch arguments that open a
  tab, a screen, a search or a spread are listed in [AGENTS.md](AGENTS.md).

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
Built on the boxes: the app's own tap in Vision mode and the furigana taken
out of its lines (see *What exists*). Both ways of selecting on the page are
the app's now, so whether Live Text's selection stays the default is a field
question. A second reader over a whole page would be possible, the boxes
cutting the page into the lines it reads, but none stands between the app and
positions. (manga-ocr was tried as a third, up-close reader — a window of eight
characters around the tap through a Core ML conversion of the model — and
taken out on 2026-10-04: 210 MB of a 343 MB app for a mode nobody chose; the
conversion script and the target are in the history before that date.)

The camera is one source of a still, not the only one. A screenshot of an
e-book app or a web page enters the same screen through the photo picker or
the *Read in Yomidori* action in Shortcuts (see *What exists*); from the still
on, camera and screenshot are the same path, vertical columns included. What
remains is a share extension that receives the image from the screenshot's
preview: a second signed target with an app group to pass the image through,
so it touches provisioning and the release lane. Watching the screenshots
album is deliberately not offered: it needs photo-library access for
everything in exchange for one tap the shortcut already saves.

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

The scheduler, the lessons, the ranks, the stores, their sync, the backup and
the graphs are built (see *What exists*). What remains: the FSRS parameters
stay the published defaults until there are enough answers in the cards' logs
to fit them, a question for much later; and sync tried between two real
devices, which the simulator cannot stand in for.

### Dictionary and meaning

The meaning is one tap away, never shown unasked; the English gloss from JMdict
and the system dictionary's Japanese one are built (see *What exists*). What
remains is a ja gloss of the app's own, from Japanese Wiktionary where it has
one, since 大辞林 is a view and cannot be quoted.

### Pitch accent and audio

Word-level pitch is built, the dictionary's and the estimates beside it
(`PitchAccent`, `PitchReading`, `PitchPhrase` and the pick in review), and a
sentence is read aloud by the system's voice (`Speaker`; see *What exists*).
What remains is the sentence drawn: its contour, which shifts with
conjugation and compounding, would come from UniDic's connection rules or
Open JTalk's accent estimation, which VOICEVOX exposes together with a more
natural speech than the system's. All of it is standard Tokyo accent, which
every free source and most paid ones are limited to.

### Theme

The palette is built (`Palette`, see *What exists*) and follows the system; what
remains is a manual override. Dark mode is 夜緑 proper: deep green accent on
near-black. Light mode is the same green on paper-white. The green is the
frame and the accent — the tapped word, the buttons, the bird — never the
surface behind text. The highlight of a tapped word sits on a photograph, so
it is a translucent fill inside a solid outline, legible over cream paper and
gray print in both modes.

### Localization

Both interfaces exist, every string with its Japanese; what remains is the
native-ear review before the store (the roadmap's *Store* section). The name is
Yomidori on one storefront and ヨミドリ on the other, one bundle. The Japanese
interface is for Japanese users,
which the school-age 国語 idea in the roadmap would need, and it is written by a
native ear, not translated from the English.
