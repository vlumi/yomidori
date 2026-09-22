# Yomidori · ヨミドリ

[![CI](https://github.com/vlumi/yomidori/actions/workflows/ci.yml/badge.svg)](https://github.com/vlumi/yomidori/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/vlumi/yomidori/branch/main/graph/badge.svg)](https://codecov.io/gh/vlumi/yomidori)

A reading companion for Japanese paperbacks, for iPhone and iPad. Point the
camera at a word you can't read, tap it, and get its reading. The sentence you
were reading becomes a card, and the cards are what you study.

> **Status: alpha on TestFlight, nothing on the App Store yet.** The whole
> first form is there and has been read with on a real paperback: freeze the
> page, select a word, every word in the selection with its reading, pitch and
> meaning, the kanji behind them with stroke order, cards with the sentences you
> met the word in, lessons and typed reviews with bird ranks, collections by book,
> and a history of what you looked up. How it's built: [ARCHITECTURE.md](ARCHITECTURE.md).
> How to work on it: [AGENTS.md](AGENTS.md). What's next: [ROADMAP.md](ROADMAP.md).

## The idea

You're reading a novel in one hand. A kanji you don't know stops you: you know
the word from the meaning, or you don't, but either way you want the reading,
now, without leaving the page. Every dictionary makes you draw the character or
type a guess, and a translation app translates the whole page.

Yomidori does one thing at that moment. Frame the line, tap *Read the page*,
and the page freezes on the screen; reading on the phone itself, share a
screenshot to it instead. Tap the word, in a vertical column or a horizontal
line, and the whole word lights up with its reading in kana and its pitch
accent, in a sheet your thumb can reach. The meaning is one more tap away, and never shown before
you ask.

Then the word keeps working for you. The sentence you met it in, as it stood on
the page, becomes a card; a lesson starts it when you have time for it, and it
asks three things by typing: the reading, the meaning, and which pitch. Meet the
same word in another book and the card gains a second sentence. Reviews happen
when you open the app, on the train or not at all; there is no streak to keep,
and a card you truly forgot goes back to waiting instead of haunting you.

## Principles

- **Help only where asked.** No furigana over the whole page, no translation of
  anything you didn't tap. Recognizing the kanji you know is the point of
  reading; the app speaks when you say you don't.
- **Everything on the device.** Text recognition, tokenizing, readings, pitch,
  cards: all local, offline, from dictionaries bundled with the app. No account,
  no server, no model in the cloud. A word you look up never leaves the phone.
- **The book is the corpus.** Example sentences are the ones you actually read,
  cropped from your own capture, not a corpus written for someone else.
- **iPhone and iPad, iOS 26 up.** A Mac app is planned,
  for reading on the screen and reviewing on a keyboard.
- **English and Japanese** interfaces from day one, on a String Catalog.
- Free, open source, no ads, no tracking.

## The name

読み鳥, the reading bird, said the way 読み取り, text recognition, is said. Read
another way it is 夜緑, night green, the color of the app. The mascot is a Java
sparrow, whose Japanese name 文鳥 happens to mean "text bird".

## Version history

Builds 1 to 7 went to TestFlight between 2026-09-17 and 22; nothing on the App
Store yet. See [CHANGELOG.md](CHANGELOG.md) for what each build carried and
[ROADMAP.md](ROADMAP.md) for what's next.

## License

MIT for the code. See [LICENSE](LICENSE); the name and the artwork are covered by
[TRADEMARKS.md](TRADEMARKS.md).
