# Privacy Policy

_Last updated: 2026-09-29._

**Yomidori does not collect, store, or transmit any personal data.**

Everything happens on your device:

- **No data is sent to us.** Yomidori has no server, no account, no sign-in, no
  analytics, no advertising, and no third-party SDKs. We receive nothing.
- **Your own iCloud, and nothing else.** With iCloud sync on (Settings, on by
  default), your cards, collections with their covers, and lookup history are
  kept in your private iCloud database, so your devices show the same. Apple
  stores it under your Apple Account; we cannot read it. Turn sync off and
  nothing leaves the device. Apart from that the app makes no network
  connections: text recognition, dictionary lookups and readings all run on the
  device, from dictionaries bundled with the app.
- **The camera.** The app asks for the camera, to read the page in front of
  you. Frames are processed on the device to recognize the text and are never
  uploaded anywhere or kept: a card keeps the sentence as text. The one photo
  the app stores is a collection's cover, when you scan one; with sync on, the
  cover goes to your iCloud with its collection.
- **A number on the app's icon, if you ask for it.** Turning on _Reviews due on
  the app icon_ in Settings asks for permission to show a badge, and nothing
  else: no banners, no sounds. The count is worked out on the device.
- **Pictures and text you hand it.** A photo from your library, pasted text, or
  an image given to the _Read in Yomidori_ action in Shortcuts is read on the
  device like a page from the camera, and not kept.
- **What's stored locally.** Your cards — the words, their sentences, your
  answers — your collections and their covers, a history of the
  last words you looked up, and the app's own settings, kept in the app's own
  local storage so they persist between launches. Deleting the app removes
  them all; Settings saves a backup (the cards, the collections and the lookup
  history as one file, no photos), a collection can be shared as a file of its
  words and sentences (no photos), both only where you send them, and any card,
  collection or history entry can be deleted in the app.
- **No tracking.** The app does not track you across apps or websites and does
  not use any device identifiers for advertising.
- **Children.** Because the app collects no data at all, it collects none from
  children either.

## Verifying any of this

Yomidori is open source under the MIT license. Every claim on this page can be
checked in the code at <https://github.com/vlumi/yomidori> — the entitlements
file shows exactly which capabilities the app requests (iCloud with CloudKit,
and the silent pushes CloudKit sends when another of your devices syncs), and
the Info.plist which permissions it asks for.

## Contact

Questions about this policy: <ville@misaki.fi>, or open an issue at
<https://github.com/vlumi/yomidori/issues>.
