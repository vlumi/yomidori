# One app on three kinds of screen

A plan, to be retired into [ARCHITECTURE.md](../ARCHITECTURE.md) as it ships.
It came out of the first day with the Mac build (2026-09-30): the phone's
screens, run in a Mac window, work but feel wrong in a dozen small ways. The
findings are listed first, then the design that answers them, then the order
to build it in.

## The premise

The three devices differ in two things, and the app should answer to those
two, not to the platform's name:

| | phone | iPad | Mac |
| --- | --- | --- | --- |
| **room** | one column | two columns, three in landscape | as many as the window allows |
| **input** | a thumb, on the glass, one hand holding a book | fingers, and often a keyboard or a pencil, sometimes a trackpad | a keyboard and a pointer, both hands free |

The phone is the home of *help only where asked*: a page in front of the eye
and a drawer for the thumb. The Mac is where the reader sits down: pasted
chapters, cards in bulk, reviews at a keyboard. The iPad is both, by how it is
held: a portrait iPad with a finger is a big phone, a landscape iPad with a
keyboard is a small Mac.

So the rule: **layout follows room, affordances follow input.** SwiftUI's size
classes say the room (compact: one column; regular: columns), and the
platform plus the connected hardware say the input. One Kit, one set of
screens, laid out two ways and touched three ways. Nothing is "the Mac
version": a landscape iPad with a keyboard gets the same splits and the same
keys.

## What is wrong today

Found on the first day, on a Mac window; most of it would show on a landscape
iPad too.

1. **The tab bar is a phone's.** On a Mac the tabs sit in a segmented control
   in the toolbar, one content column under it. The Mac and the iPad idiom for
   the same thing is a sidebar, which also gives every section ⌘1, ⌘2 …
2. **Read is a text box with an afterthought.** The box is right, but once the
   text is read the reading appears *under* it as a separate strip, so the page
   is shown twice, and the thing the reader wants to select in, the reading
   with its words, is the smaller of the two. Dropping or pasting a picture
   does nothing yet.
3. **Search's kanji-by-parts button floats in the toolbar**, nowhere near the
   field it types into. On the phone it sits inside the field.
4. **Search's empty state has a gap** between the field and the history: the
   list's top inset under a toolbar search field, and the history's own header.
5. **Search's history and results look the same**, one list replacing the
   other; with room for two columns the history should stay in view.
6. **Cards is a single list that pushes a detail**, the phone's stack, in a
   window that could show the list and the card side by side; no keyboard
   moves through it.
7. **Review and lesson have no keys.** Return checks, and that is all; *Show
   the answer*, the pitch pick, *Next*, *Forgot it* all want a key. The sentence
   is set at a phone's size in a wide window.
8. **Collections** is the same single list; the editor is a phone form.
9. **Nothing answers a pointer**: no hover on a word in the strip, no
   right-click on a word (Keep, Copy, Look up, Speak), no tooltips on icon-only
   buttons, and *extend the selection* is a long press, which a mouse does not
   discover.
10. **The window has no floor**: shrunk far enough, the split panes overlap.
11. **Detents, sheets and the drawer** are phone furniture: `presentationDetents`
    does nothing on a Mac, so the fix sheet and the parts sheet size to content;
    the review's *stop* is a back button.

## The design

### Structure: tabs on the phone, a sidebar with room

`TabView` with `.tabViewStyle(.sidebarAdaptable)`: the same five sections, a
tab bar in a compact width, a sidebar in a regular one (an iPad in landscape,
any Mac window). The sidebar is where a Mac reader expects to switch, and the
system gives ⌘1 … ⌘5 for free. Read is the first item and the Mac's home; the
phone keeps its Home tab, whose job (the counts, the Read button) the sidebar's
badges and the first item do with room.

Each section owns a `NavigationSplitView` where it has a list and a detail:
Cards, Collections, Search. In a compact width the split collapses to the
stack the phone has today, so the phone changes nothing.

### Read: the page is one thing, with two states

The page pane on the left, the words pane on the right, as now; but the page
pane is *one view with two states*, not a box and a strip:

- **Source.** An editable text box for a pasted chapter, or a picture dropped,
  pasted or opened (⌘O, and the Photos picker as today). Empty, it says so and
  takes a drop.
- **Reading.** Once read, the same pane shows the text as the reading: the
  chunks with their readings over the words (`ChunkFlow`, laid out as a page
  at the box's size), selectable by click, drag and shift-click as text is,
  the selection lit. This is what the strip under the box was trying to be.
  An *Edit* button returns to the source; a picture shows Live Text's own
  selection over it instead (the Mac's `ImageAnalysisOverlayView`).

The words pane keeps the selection's words, the phrase first, Keep, the fixes
and the dictionary. The strip stops existing on a big screen; on the phone it
stays as it is, folded under the words.

Keys: ⌘V with the pane empty pastes a page; Esc clears the selection; ←/→
move the selection a word, ⇧←/→ stretch it (the strip's long press, for a
keyboard); ⌘K keeps the selected word; Space speaks the sentence.

### Search: the history beside the results

A split: the lookup history in the list column, always in view, newest first,
a click of a line searching it; the results in the detail column, and an entry
opening in place of them rather than pushing. In a compact width it collapses
to today's one list.

The kanji-by-parts button goes back beside the field: on a Mac the search
field is the toolbar's, so the button stands next to it in the toolbar and
opens a **popover** anchored to itself, not a sheet, and inserts at the field's
cursor as it does now. The gap goes with the split (the history's header is the
column's title).

### Cards: list and card

`NavigationSplitView`: the stacks and the collection filter in the list, the
card in the detail. ↑/↓ move, Return opens the card (already the detail: it
follows the selection), ⌫ forgets a card after asking, ⌘F focuses the filter.
Collections is a section of the same list's sidebar on a big screen, its own
tab on the phone.

### Study: a keyboard's review

The review as a focused sheet of text: the sentence at a reading size, the
answer field under it, at most 640 points wide and centered, the buttons under
that. Keys: Return checks; ⌘Return shows the answer; 0–9 pick a pitch; Space
goes on after a miss; ⌘. or Esc stops the session. The lesson likewise:
Return starts the card, → later, ⌫ drops. Every button keeps its label, since
the keys are for the second week, not the first.

### Pointer affordances, wherever a pointer is

- Hover lifts a chunk in the reading; the cursor is a pointer over words.
- A word's context menu: Keep, Copy, Look up, Speak, Fix.
- Tooltips on every icon-only button (`.help`), which VoiceOver already has
  the text for.
- Shift-click stretches the selection; the long press stays for a finger.

These are cheap and they apply to an iPad with a trackpad the same way.

### Windows and sheets

The window gets a floor (800 × 500) and remembers its size. Sheets that use
detents on the phone get a frame on the Mac (the fix sheet, kanji by parts,
the card sheet). The drawer stays a phone thing.

## What the phone keeps

Everything. The tab bar, the drawer and its detents, the strip under the
words, the long press, the review as a screen. The changes above are
conditional on room and input, and a compact width with a finger is the
phone. The iPad in portrait is that too; in landscape it gets the sidebar and
the splits, and with a keyboard the keys.

## Order

1. **Structure and pointer basics**: sidebar-adaptable tabs, window floor,
   tooltips, context menus, shift-click. Small, and it frames the rest.
2. **Read as one pane with two states**, text first; the image path (drop,
   paste, open; Live Text's Mac overlay) right after, since it is the same
   pane.
3. **Search** as a split with the popover.
4. **Cards and Collections** as splits with keys.
5. **Review and lesson keys** and the reading-sized layout.
6. Then a first Mac build to TestFlight, and the iPad in landscape looked at
   with the same eyes.
