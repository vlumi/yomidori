#!/usr/bin/env python3
"""Turn JMdict, KANJIDIC2, KRADFILE, KanjiVG and Kanjium's accent list into the SQLite
database the app bundles.

    Scripts/data/build-jmdict.py [--source FILE|URL] [--accents FILE|URL]
        [--kanjidic FILE|URL] [--kradfile FILE|URL] [--kanjivg DIR|ZIP|URL] [--output FILE]

The source is JMdict_e (the English-only edition) as .gz or plain XML, the accents
Kanjium's accents.txt, the kanji KANJIDIC2's XML and KRADFILE's component list; all are
downloaded once into .build-data/ and reused. The output is a read-only database of
entries with their kanji forms, readings and senses, indexed by headword and by
reading; an accent table of downstep positions keyed by headword and reading; a kanji
table of readings, meanings and school facts with a component table beside it; a stroke
table of KanjiVG's SVG paths in stroke order with where each number is drawn; and a meta
table naming the sources, their dates and licenses. Standard library only. KanjiVG's
"latest release" is resolved through GitHub's API to its -main.zip.

JMdict, KANJIDIC2 and KRADFILE are © the Electronic Dictionary Research and Development
Group and used under its CC BY-SA 4.0 licence (https://www.edrdg.org/edrdg/licence.html);
Kanjium's pitch accent data is © Uros O. under CC BY-SA 4.0; KanjiVG is © Ulrich Apel
under CC BY-SA 3.0. The meta table carries the attributions and THIRD_PARTY_NOTICES.md
reproduces them.
"""

import argparse
import gzip
import os
import re
import sqlite3
import sys
import urllib.request
import xml.etree.ElementTree as ET

DEFAULT_SOURCE = "http://ftp.edrdg.org/pub/Nihongo/JMdict_e.gz"
DEFAULT_ACCENTS = "https://raw.githubusercontent.com/mifunetoshiro/kanjium/master/data/source_files/raw/accents.txt"
DEFAULT_KANJIDIC = "http://www.edrdg.org/kanjidic/kanjidic2.xml.gz"
DEFAULT_KRADFILE = "http://ftp.edrdg.org/pub/Nihongo/kradfile.gz"
DEFAULT_KANJIVG = "https://api.github.com/repos/KanjiVG/kanjivg/releases/latest"
CACHE_DIR = ".build-data"
DEFAULT_OUTPUT = "Sources/Shared/Dictionaries/jmdict.sqlite"
PRIORITY = ("news1", "ichi1", "spec1", "spec2", "gai1")  # the tags that mark a common word

SCHEMA = """
CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE entry (id INTEGER PRIMARY KEY, common INTEGER NOT NULL);
CREATE TABLE kanji (entry INTEGER NOT NULL, ord INTEGER NOT NULL, text TEXT NOT NULL);
CREATE TABLE reading (entry INTEGER NOT NULL, ord INTEGER NOT NULL, text TEXT NOT NULL);
CREATE TABLE sense (entry INTEGER NOT NULL, ord INTEGER NOT NULL, pos TEXT NOT NULL, gloss TEXT NOT NULL);
CREATE INDEX kanji_text ON kanji (text);
CREATE INDEX kanji_entry ON kanji (entry);
CREATE INDEX reading_text ON reading (text);
CREATE INDEX reading_entry ON reading (entry);
CREATE INDEX sense_entry ON sense (entry);
CREATE TABLE accent (headword TEXT NOT NULL, reading TEXT NOT NULL, downsteps TEXT NOT NULL);
CREATE INDEX accent_word ON accent (headword, reading);
CREATE VIRTUAL TABLE gloss_fts USING fts5(gloss, content='sense', content_rowid='rowid', tokenize='unicode61');
CREATE TABLE kanji_info (literal TEXT PRIMARY KEY, onyomi TEXT NOT NULL, kunyomi TEXT NOT NULL, nanori TEXT NOT NULL, meanings TEXT NOT NULL, strokes INTEGER, grade INTEGER, jlpt INTEGER, freq INTEGER);
CREATE TABLE kanji_component (literal TEXT NOT NULL, ord INTEGER NOT NULL, component TEXT NOT NULL);
CREATE INDEX kanji_component_literal ON kanji_component (literal);
CREATE TABLE kanji_stroke (literal TEXT NOT NULL, ord INTEGER NOT NULL, path TEXT NOT NULL, label_x REAL, label_y REAL);
CREATE INDEX kanji_stroke_literal ON kanji_stroke (literal);
"""


def fetch(source):
    """The source as bytes, downloading a URL once into the cache and reusing it."""
    if re.match(r"^https?://", source):
        cached = os.path.join(CACHE_DIR, os.path.basename(source))
        if not os.path.exists(cached):
            os.makedirs(CACHE_DIR, exist_ok=True)
            print(f"downloading {source} → {cached}", file=sys.stderr)
            urllib.request.urlretrieve(source, cached)
        source = cached
    with open(source, "rb") as f:
        data = f.read()
    return gzip.decompress(data) if source.endswith(".gz") else data


def accent_rows(text):
    """Kanjium's accents.txt: headword, reading, accents; a kana headword has an empty
    reading, and an accent list may carry part-of-speech tags like (名)3, which are
    dropped: what stays is the downstep mora of each accent in the file's order, 0 flat."""
    for line in text.splitlines():
        parts = line.split("\t")
        if len(parts) != 3:
            continue
        headword, reading, accents = parts
        numbers = []
        for n in re.sub(r"\([^)]*\)", "", accents).split(","):
            n = n.strip()
            if n.isdigit() and n not in numbers:
                numbers.append(n)
        if numbers:
            yield headword, reading or headword, ",".join(numbers)


def kanjidic_rows(xml_bytes):
    """KANJIDIC2's characters: the literal, its on and kun readings, name readings and
    English meanings, each list space-joined, and the stroke count, school grade, JLPT
    level and newspaper frequency rank where the file has them."""
    for _, character in ET.iterparse(_bytes_stream(xml_bytes)):
        if character.tag != "character":
            continue
        readings = {"ja_on": [], "ja_kun": []}
        for reading in character.iter("reading"):
            kind = reading.get("r_type")
            if kind in readings and reading.text:
                readings[kind].append(reading.text)
        meanings = [m.text for m in character.iter("meaning") if m.text and m.get("m_lang") is None]
        nanori = [n.text for n in character.iter("nanori") if n.text]
        misc = character.find("misc")
        number = lambda tag: int(misc.findtext(tag)) if misc is not None and misc.findtext(tag) else None
        yield (
            character.findtext("literal"),
            " ".join(readings["ja_on"]),
            " ".join(readings["ja_kun"]),
            " ".join(nanori),
            "; ".join(meanings),
            number("stroke_count"),
            number("grade"),
            number("jlpt"),
            number("freq"),
        )
        character.clear()


def kanjivg_files(source):
    """KanjiVG's kanji/XXXXX.svg files as (codepoint, text): from a directory, a zip, or
    a URL; the GitHub releases API URL resolves to the release's -main.zip first."""
    import io
    import json
    import zipfile

    if re.match(r"^https?://api\.github\.com/", source):
        cached = os.path.join(CACHE_DIR, "kanjivg-release.json")
        if not os.path.exists(cached):
            os.makedirs(CACHE_DIR, exist_ok=True)
            urllib.request.urlretrieve(source, cached)
        with open(cached) as f:
            assets = json.load(f)["assets"]
        source = next(a["browser_download_url"] for a in assets if a["name"].endswith("-main.zip"))
    if os.path.isdir(source):
        for name in sorted(os.listdir(os.path.join(source, "kanji"))):
            if re.fullmatch(r"[0-9a-f]{5}\.svg", name):
                with open(os.path.join(source, "kanji", name), encoding="utf-8") as f:
                    yield name[:5], f.read()
        return
    with zipfile.ZipFile(io.BytesIO(fetch(source))) as archive:
        for name in sorted(archive.namelist()):
            match = re.search(r"(?:^|/)kanji/([0-9a-f]{5})\.svg$", name)
            if match:
                yield match.group(1), archive.read(name).decode("utf-8")


def kanjivg_rows(files):
    """Each file's strokes in order, the SVG path of each with where its number sits."""
    for codepoint, text in files:
        literal = chr(int(codepoint, 16))
        paths = re.findall(r'<path[^>]*\sd="([^"]+)"', text)
        labels = {
            int(n): (float(x), float(y))
            for x, y, n in re.findall(r'<text transform="matrix\(1 0 0 1 ([\d.]+) ([\d.]+)\)">(\d+)<', text)
        }
        for i, path in enumerate(paths):
            x, y = labels.get(i + 1, (None, None))
            yield literal, i, path, x, y


def kradfile_rows(data):
    """KRADFILE's lines, `亜 : ｜ 一 口`; the file is EUC-JP, a fixture may be UTF-8."""
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        text = data.decode("euc_jp")
    for line in text.splitlines():
        if line.startswith("#") or " : " not in line:
            continue
        literal, components = line.split(" : ", 1)
        for i, component in enumerate(components.split()):
            yield literal.strip(), i, component


def entity_codes(xml_bytes):
    """JMdict spells parts of speech as entities (&n; → "noun (common) (futsuumeishi)");
    the parser expands them, so map the expansions back to their short codes."""
    head = xml_bytes[:400_000].decode("utf-8", errors="ignore")
    return {text: code for code, text in re.findall(r'<!ENTITY (\S+) "([^"]+)">', head)}


def build(xml_bytes, accents_text, kanjidic_bytes, kradfile_bytes, kanjivg, output):
    codes = entity_codes(xml_bytes)
    created = re.search(r"JMdict created: (\d{4}-\d{2}-\d{2})", xml_bytes[:400_000].decode("utf-8", errors="ignore"))
    if os.path.exists(output):
        os.remove(output)
    db = sqlite3.connect(output)
    db.executescript(SCHEMA)
    db.executemany(
        "INSERT INTO meta VALUES (?, ?)",
        [
            ("source", "JMdict_e (EDRDG)"),
            ("created", created.group(1) if created else "unknown"),
            ("license", "CC BY-SA 4.0 — https://www.edrdg.org/edrdg/licence.html"),
            ("attribution", "This application uses the JMdict dictionary files. These files are the property of the Electronic Dictionary Research and Development Group, and are used in conformance with the Group's licence."),
            ("accents_source", "Kanjium accents.txt (Uros O.)"),
            ("accents_license", "CC BY-SA 4.0 — https://github.com/mifunetoshiro/kanjium"),
            ("accents_attribution", "The pitch accent notation, verb particle data, phonetics, homonyms and other additions or modifications to EDICT, KANJIDIC or KRADFILE were provided by Uros O. through his free database."),
            ("kanji_source", "KANJIDIC2 and KRADFILE (EDRDG)"),
            ("kanji_license", "CC BY-SA 4.0 — https://www.edrdg.org/edrdg/licence.html"),
            ("kanji_attribution", "This application uses the KANJIDIC and KRADFILE dictionary files. These files are the property of the Electronic Dictionary Research and Development Group, and are used in conformance with the Group's licence."),
            ("strokes_source", "KanjiVG (Ulrich Apel)"),
            ("strokes_license", "CC BY-SA 3.0 — https://kanjivg.tagaini.net"),
            ("strokes_attribution", "The stroke order data is KanjiVG, copyright Ulrich Apel, used under the Creative Commons Attribution-ShareAlike 3.0 licence."),
        ],
    )
    if accents_text is not None:
        db.executemany("INSERT INTO accent VALUES (?, ?, ?)", accent_rows(accents_text))
    if kanjidic_bytes is not None:
        db.executemany("INSERT INTO kanji_info VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", kanjidic_rows(kanjidic_bytes))
    if kradfile_bytes is not None:
        db.executemany("INSERT INTO kanji_component VALUES (?, ?, ?)", kradfile_rows(kradfile_bytes))
    if kanjivg is not None:
        db.executemany("INSERT INTO kanji_stroke VALUES (?, ?, ?, ?, ?)", kanjivg_rows(kanjivg_files(kanjivg)))
    count = 0
    for _, entry in ET.iterparse(_bytes_stream(xml_bytes)):
        if entry.tag != "entry":
            continue
        entry_id = int(entry.findtext("ent_seq"))
        kanji = [k.findtext("keb") for k in entry.findall("k_ele")]
        readings = [r.findtext("reb") for r in entry.findall("r_ele")]
        common = any(
            p.text in PRIORITY for ele in entry.findall("k_ele") + entry.findall("r_ele") for p in ele.findall("ke_pri") + ele.findall("re_pri")
        )
        db.execute("INSERT INTO entry VALUES (?, ?)", (entry_id, int(common)))
        db.executemany("INSERT INTO kanji VALUES (?, ?, ?)", [(entry_id, i, k) for i, k in enumerate(kanji)])
        db.executemany("INSERT INTO reading VALUES (?, ?, ?)", [(entry_id, i, r) for i, r in enumerate(readings)])
        pos = []
        for i, sense in enumerate(entry.findall("sense")):
            # A sense without its own <pos> inherits the previous sense's, as JMdict's DTD says.
            pos = [codes.get(p.text, p.text) for p in sense.findall("pos")] or pos
            glosses = [g.text for g in sense.findall("gloss") if g.text and g.get("{http://www.w3.org/XML/1998/namespace}lang", "eng") == "eng"]
            if glosses:
                db.execute("INSERT INTO sense VALUES (?, ?, ?, ?)", (entry_id, i, " ".join(pos), "; ".join(glosses)))
        entry.clear()
        count += 1
    # The full-text index over the glosses, for typed search in English.
    db.execute("INSERT INTO gloss_fts(gloss_fts) VALUES ('rebuild')")
    db.commit()
    db.execute("VACUUM")
    db.close()
    return count


def _bytes_stream(data):
    import io

    return io.BytesIO(data)


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--source", default=DEFAULT_SOURCE, help="JMdict_e as .gz or .xml, a path or a URL")
    parser.add_argument("--accents", default=DEFAULT_ACCENTS, help="Kanjium's accents.txt, a path or a URL; 'none' to skip")
    parser.add_argument("--kanjidic", default=DEFAULT_KANJIDIC, help="KANJIDIC2 as .gz or .xml, a path or a URL; 'none' to skip")
    parser.add_argument("--kradfile", default=DEFAULT_KRADFILE, help="KRADFILE as .gz or plain, a path or a URL; 'none' to skip")
    parser.add_argument("--kanjivg", default=DEFAULT_KANJIVG, help="KanjiVG as a directory, a zip, a URL, or the releases API URL; 'none' to skip")
    parser.add_argument("--output", default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    os.makedirs(os.path.dirname(args.output) or ".", exist_ok=True)
    accents = None if args.accents == "none" else fetch(args.accents).decode("utf-8")
    kanjidic = None if args.kanjidic == "none" else fetch(args.kanjidic)
    kradfile = None if args.kradfile == "none" else fetch(args.kradfile)
    kanjivg = None if args.kanjivg == "none" else args.kanjivg
    count = build(fetch(args.source), accents, kanjidic, kradfile, kanjivg, args.output)
    size = os.path.getsize(args.output) / 1e6
    print(f"wrote {args.output}: {count} entries, {size:.1f} MB")


if __name__ == "__main__":
    main()
