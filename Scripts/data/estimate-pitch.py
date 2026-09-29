#!/usr/bin/env python3
"""Estimate the pitch of the words Kanjium has none for, into the dictionary's database.

    Scripts/data/estimate-pitch.py [--database FILE] [--measure]

Run after build-jmdict.py, on its output. For every entry whose headword and reading have
no accent from Kanjium, Open JTalk (through pyopenjtalk) cuts the headword into words and
accent phrases, and then:

- an expression of several accent phrases (見当がつく) gets each phrase's accent as Open
  JTalk gives it, the phrases being a dictionary word and its particles or endings;
- a compound of one accent phrase (読書感想文) gets the habit of its last element, learned
  from the compounds Kanjium does have: flat, a drop at the end of what comes before, at
  the last element's start, or where the last element drops on its own. A last element
  seen fewer than three times is no habit, and the compound is left without pitch;
- a single word gets Open JTalk's own accent, if it is written in kanji and read as
  JMdict reads it; one in kana alone cannot be told from a word Open JTalk does not know.

All of it goes to a table of its own, accent_estimate, which the app shows marked as
estimated and never asks in a review. It is Tokyo standard, as Kanjium is.

--measure writes nothing: it holds a fifth of Kanjium's compounds out, learns from the
rest and prints how often each way agrees with Kanjium on the fifth.

Open JTalk and its NAIST Japanese Dictionary are under the Modified BSD license.
"""

import argparse
import collections
import os
import random
import sqlite3
import sys

DEFAULT_DATABASE = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "..", "Sources", "Shared", "Dictionaries", "jmdict.sqlite")

SMALL = set("ぁぃぅぇぉゃゅょゎァィゥェォャュョヮ")
FUNCTION = {"助詞", "助動詞"}
# A last element seen in fewer compounds than this has no habit to go by.
FAMILIAR = 3

VOWEL = {}
for row, vowel in [
    ("アカサタナハマヤラワガザダバパァャ", "ア"),
    ("イキシチニヒミリギジヂビピィ", "イ"),
    ("ウクスツヌフムユルグズヅブプゥュ", "ウ"),
    ("エケセテネヘメレゲゼデベペェ", "エ"),
    ("オコソトノホモヨロヲゴゾドボポォョ", "オ"),
]:
    for kana in row:
        VOWEL[kana] = vowel


def katakana(text):
    return "".join(chr(ord(c) + 0x60) if "ぁ" <= c <= "ゖ" else c for c in text)


def hiragana(text):
    return "".join(chr(ord(c) - 0x60) if "ァ" <= c <= "ヶ" else c for c in text)


def morae(kana):
    """The kana cut into morae: a small kana joins the one before it."""
    cut = []
    for c in kana:
        if c in SMALL and cut:
            cut[-1] += c
        else:
            cut.append(c)
    return cut


def same_reading(pron, reading):
    """Open JTalk's pronunciation against a dictionary reading: its ー stands for the kana
    that lengthens the vowel before it (オー for おう or おお, エー for えい or ええ)."""
    wanted = katakana(reading)
    if len(pron) != len(wanted):
        return False
    for i, (p, q) in enumerate(zip(pron, wanted)):
        if p == q:
            continue
        if p == "ー" and i > 0:
            vowel = VOWEL.get(pron[i - 1])
            if q == vowel or q == "ー" or (vowel == "オ" and q == "ウ") or (vowel == "エ" and q == "イ"):
                continue
        return False
    return True


def special(pron, position):
    """Whether the mora at 1-based `position` cannot carry the drop: ー, ン, ッ, or the
    second half of a long vowel."""
    cut = morae(pron)
    if not 1 <= position <= len(cut):
        return False
    mora = cut[position - 1]
    if mora in ("ー", "ン", "ッ"):
        return True
    before = cut[position - 2][-1] if position >= 2 else ""
    return (mora == "ウ" and VOWEL.get(before) in ("オ", "ウ")) or (mora == "イ" and VOWEL.get(before) == "エ")


def shifted(pron, drop):
    while drop > 1 and special(pron, drop):
        drop -= 1
    return drop


def has_kanji(text):
    return any("一" <= c <= "鿿" or "㐀" <= c <= "䶿" for c in text)


class Estimator:
    def __init__(self, accents):
        import pyopenjtalk

        self.frontend = pyopenjtalk.run_frontend
        # Kanjium's accents by headword, whatever the reading: for a compound's last element.
        self.known = collections.defaultdict(set)
        for headword, _, downsteps in accents:
            self.known[headword].update(int(n) for n in downsteps.split(",") if n.isdigit())
        self.habits = {}

    def cut(self, headword, reading):
        """The headword as Open JTalk's words, grouped into accent phrases; None if it
        reads the word otherwise than the dictionary does."""
        try:
            nodes = self.frontend(headword)
        except Exception:
            return None
        if not nodes:
            return None
        pron = "".join(n["pron"] for n in nodes).replace("’", "")
        if not same_reading(pron, reading):
            return None
        phrases = []
        for node in nodes:
            if node["chain_flag"] == 1 and phrases:
                phrases[-1].append(node)
            else:
                phrases.append([node])
        return phrases

    def habits_of(self, nodes):
        """The drop each habit would give a compound of these words."""
        first = sum(n["mora_size"] for n in nodes[:-1])
        last = nodes[-1]
        pron = "".join(n["pron"] for n in nodes).replace("’", "")
        own = min(self.known[last["string"]]) if self.known.get(last["string"]) else last["acc"]
        return {
            "flat": 0,
            "end of first": shifted(pron, first),
            "start of last": shifted(pron, first + 1),
            "last's own": first + own if own > 0 else 0,
        }

    def learn(self, compounds):
        seen = collections.defaultdict(collections.Counter)
        for nodes, accepted in compounds:
            for habit, drop in self.habits_of(nodes).items():
                if drop in accepted:
                    seen[nodes[-1]["string"]][habit] += 1
        self.habits = {
            last: counts.most_common(1)[0][0] for last, counts in seen.items() if sum(counts.values()) >= FAMILIAR
        }

    def compounds(self, accents):
        """Kanjium's words that Open JTalk cuts into several words of one accent phrase."""
        found = []
        for headword, reading, downsteps in accents:
            if headword == reading:
                continue
            phrases = self.cut(headword, reading)
            if phrases and len(phrases) == 1 and len(phrases[0]) > 1:
                found.append((phrases[0], {int(n) for n in downsteps.split(",") if n.isdigit()}))
        return found

    def estimate(self, headword, reading):
        """(kind, [(kana, drop)]) or None."""
        phrases = self.cut(headword, reading)
        if not phrases:
            return None
        if len(phrases) == 1:
            nodes = phrases[0]
            if len(nodes) == 1:
                if not has_kanji(headword):
                    return None
                return "word", [(reading, nodes[0]["acc"])]
            habit = self.habits.get(nodes[-1]["string"])
            if habit is None:
                return None
            return "compound", [(reading, self.habits_of(nodes)[habit])]
        # An expression: every phrase one word with its particles and endings.
        cut = morae(reading)
        parts = []
        at = 0
        for nodes in phrases:
            if sum(1 for n in nodes if n["pos"] not in FUNCTION) > 1:
                return None
            size = sum(n["mora_size"] for n in nodes)
            kana = "".join(cut[at : at + size])
            at += size
            if not kana or nodes[0]["acc"] > size:
                return None
            parts.append((kana, nodes[0]["acc"]))
        if at != len(cut):
            return None
        return "phrase", parts


def measure(estimator, accents):
    compounds = estimator.compounds(accents)
    random.Random(11).shuffle(compounds)
    held = len(compounds) // 5
    test, train = compounds[:held], compounds[held:]
    estimator.learn(train)
    tally = collections.Counter()
    for nodes, accepted in test:
        tally["all"] += 1
        tally["open jtalk"] += nodes[0]["acc"] in accepted
        habit = estimator.habits.get(nodes[-1]["string"])
        if habit is None:
            tally["unfamiliar"] += 1
            continue
        tally["familiar"] += 1
        tally["habit"] += estimator.habits_of(nodes)[habit] in accepted
    print(f"compounds in Kanjium cut by Open JTalk: {len(compounds)}, held out: {tally['all']}")
    print(f"Open JTalk's own accent agrees:        {100 * tally['open jtalk'] / tally['all']:.1f}%")
    print(f"with a familiar last element:          {100 * tally['familiar'] / tally['all']:.1f}% of them")
    print(f"the learned habit agrees, on those:    {100 * tally['habit'] / max(tally['familiar'], 1):.1f}%")


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--database", default=DEFAULT_DATABASE)
    parser.add_argument("--measure", action="store_true", help="print the agreement with Kanjium and write nothing")
    args = parser.parse_args()
    db = sqlite3.connect(args.database)
    accents = db.execute("SELECT headword, reading, downsteps FROM accent").fetchall()
    estimator = Estimator(accents)
    if args.measure:
        measure(estimator, accents)
        return
    estimator.learn(estimator.compounds(accents))
    have = {(headword, hiragana(reading)) for headword, reading, _ in accents}
    entries = db.execute(
        """
        SELECT COALESCE((SELECT text FROM kanji WHERE entry = e.id AND ord = 0), r.text), r.text
        FROM entry e JOIN reading r ON r.entry = e.id AND r.ord = 0
        """
    ).fetchall()
    rows = []
    kinds = collections.Counter()
    for headword, reading in entries:
        key = (headword, hiragana(reading))
        if key in have:
            continue
        have.add(key)
        estimate = estimator.estimate(headword, reading)
        if estimate is None:
            continue
        kind, parts = estimate
        kinds[kind] += 1
        rows.append((headword, key[1], "|".join(f"{kana}:{drop}" for kana, drop in parts), kind))
    db.executescript(
        """
        DROP TABLE IF EXISTS accent_estimate;
        CREATE TABLE accent_estimate (
            headword TEXT NOT NULL, reading TEXT NOT NULL, phrases TEXT NOT NULL, kind TEXT NOT NULL,
            PRIMARY KEY (headword, reading)
        ) WITHOUT ROWID;
        """
    )
    db.executemany("INSERT INTO accent_estimate VALUES (?, ?, ?, ?)", rows)
    db.executemany(
        "INSERT OR REPLACE INTO meta VALUES (?, ?)",
        [
            ("estimate_source", "Open JTalk with the NAIST Japanese Dictionary, and habits learned from Kanjium"),
            ("estimate_license", "Modified BSD — https://open-jtalk.sourceforge.net"),
        ],
    )
    db.commit()
    db.execute("VACUUM")
    db.close()
    print(f"{len(rows)} estimates: " + ", ".join(f"{count} {kind}s" for kind, count in kinds.most_common()))


if __name__ == "__main__":
    sys.exit(main())
