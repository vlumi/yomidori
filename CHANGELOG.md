# Changelog

All notable changes to Yomidori are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Grouped by **marketing version** (a roadmap milestone), then by **build number** within it — the version stays steady while the build climbs each TestFlight upload (see [RELEASING.md](RELEASING.md)). The build heading is just `### build N — <date>`; the version comes from the `## vX.Y.Z` above it.

Each version's top section, **Unreleased (next build)**, collects entries merged to `main` but not yet in a TestFlight build; cutting a release renames it to that build's heading and opens a fresh empty one. Keep that heading immediately followed by its list items (no prose between), so the release script can promote it. A user-facing PR writes its own bullet here.

The `## vX.Y.Z` heading is written by the release lane too, whenever a release cuts a new marketing version — so nothing about a version's heading is hand-set.

**One bullet, one line — no hard wrapping.** Editors soft-wrap and rendered Markdown ignores the line breaks, while hard wraps make an edited entry re-flow into a diff nobody can read. **Order the unreleased list by what a reader notices**, not by merge order, and fold entries that tell one story into one bullet.

## v0.1.0

### Unreleased (next build)

### build 2 — 2026-09-17

- **The still is the sensor's full frame.** Build 1 froze a preview-sized frame of about a megapixel, which is why small print read so badly; the shutter now keeps the full-resolution frame, and reading up close has real pixels to work with.
- **The camera permission asks in a sentence, in English too.** Build 1 showed English devices the raw key instead of the reason.

### build 1 — 2026-09-17

- **The camera reads the page.** Frame a paperback and press the shutter, or choose a screenshot from the photo library; the still freezes on the screen with every line Vision recognized boxed over it, and a tap on a line reads it out large with the recognizer's confidence. A switch at the bottom shows the same still through Live Text instead, with its transcript and its own text selection, or reads up close: tap a word and the whole line under it is cut out at full resolution and read on its own, by both engines, and shown magnified. Pinch the live view to zoom before the shutter; up close the camera goes macro on phones that have it. Both engines run on the device; the image never leaves it. This is the spike the roadmap starts with: which on-device engine, if either, reads a real page and its vertical columns.
- **The mascot on the icon.** A silver Java sparrow, head-on and mochi-round, perched low on a silver rule with its toes showing, drawn in night green and silver; the placeholder roundel retires.
