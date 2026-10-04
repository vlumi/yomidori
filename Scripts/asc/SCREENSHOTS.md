# App Store screenshots — the plan and the capture

The carousel's job: make someone who reads Japanese stop and see, in the first
frame, that this is the tap on the page, nothing else. Lead with the tap, then
the words, then what the cards do. The demo data is the stage — the same page,
cards and history in every language, every time — so **nothing is staged by
hand**: every shot is a set of demo arguments in `shots.json`, and `make shots`
relaunches the demo per shot and captures it.

## One command per platform

```sh
make shots PLATFORM=iphone     # LANGS=en,ja by default; OUT=shots
make shots PLATFORM=ipad
make shots PLATFORM=mac        # the window at 1440×900 points, grabbed @2x
```

For each language and each shot: launch the demo with the shot's arguments,
wait `SETTLE` seconds (6), capture to `shots/<platform>/<lang>/<shot>-<platform>.png`.
`PAUSE=1` stops before every capture (⏎ capture · r retake · s skip) for a
look; `ONLY=read,review` redoes some. A shot with a `stage` note in
`shots.json` pauses on its own, since something there is still done by hand.

Before a Mac run, once: the window grab asks for Screen Recording permission
for your terminal; grant it and run again. The Mac demo is opened in the
background and sized by System Events, which needs Accessibility permission
for the terminal too.

## Sizes

iPhone 6.9" (iPhone 17 Pro Max, 1320×2868) · iPad 13" (iPad Pro 13-inch,
2064×2752) · Mac 1440×900 points (2880×1800 pixels). `make asc-screenshots`
refuses a capture at any other size before touching ASC, since a wrong size
uploads fine and then blocks submission.

## The shots

What each shows and why is in `shots.json` (`python3 Scripts/asc/shots.py
iphone` prints it). The set, in **store order**:

1. **read** — the page frozen on the screen, 吾輩 picked, its reading and
   pitch in the drawer. The whole idea in one frame.
2. **phrase** — a longer selection, the phrase looked up whole and each word
   under it. The selection is a stretch, not one word.
3. **review** — the sentence as it stood on the page, the reading typed.
4. **dictionary** — みる's results with the pitch drawn; three columns on the Mac.
5. **cards** — the stacks by collection; the Mac's split with a card open.
6. **study** — what is due and the week ahead by quarter day.
7. **lesson** — a card met for the first time (iPhone, iPad).
8. **progress** — the graphs (iPhone, iPad).

The Mac carries read, phrase, dictionary, review, study and cards. Every
language gets the same set, in that language — a Japanese listing never shows
English screenshots. Dark mode is not in the set; a dark twin of **read** can
be added later as a last slot (`xcrun simctl ui <udid> appearance dark` before
the capture) if the listing wants one.

Captions, if added in ASC, one idea each: "Tap a word. Get its reading." ·
"The sentence you read is the card." · "Type the reading. Pick the pitch." ·
"Birds, not streaks."

## When the pictures are retaken

Any change to a screen in the set means `make shots` for every platform and
`make asc-screenshots-apply`; the tooling replaces each set whole, so a partial
recapture (`ONLY=`) still uploads a complete set from `shots/`.
