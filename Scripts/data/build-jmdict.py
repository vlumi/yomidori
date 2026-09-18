#!/usr/bin/env python3
"""Turn JMdict's XML into the compact SQLite database the app bundles.

    Scripts/data/build-jmdict.py [--source FILE|URL] [--output FILE]

The source is JMdict_e (the English-only edition) as .gz or plain XML; by default
it is downloaded once into .build-data/ and reused. The output is a read-only
database of entries with their kanji forms, readings and senses, indexed by
headword and by reading, plus a meta table naming the source, its date and its
license. Standard library only.

JMdict is © the Electronic Dictionary Research and Development Group and used under
its CC BY-SA 4.0 licence (https://www.edrdg.org/edrdg/licence.html); the meta table
carries the attribution and THIRD_PARTY_NOTICES.md reproduces it.
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
CACHE = ".build-data/JMdict_e.gz"
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
"""


def fetch(source):
    """The source as bytes of XML, downloading and caching a URL once."""
    if re.match(r"^https?://", source):
        if not os.path.exists(CACHE):
            os.makedirs(os.path.dirname(CACHE), exist_ok=True)
            print(f"downloading {source} → {CACHE}", file=sys.stderr)
            urllib.request.urlretrieve(source, CACHE)
        source = CACHE
    with open(source, "rb") as f:
        data = f.read()
    return gzip.decompress(data) if source.endswith(".gz") else data


def entity_codes(xml_bytes):
    """JMdict spells parts of speech as entities (&n; → "noun (common) (futsuumeishi)");
    the parser expands them, so map the expansions back to their short codes."""
    head = xml_bytes[:400_000].decode("utf-8", errors="ignore")
    return {text: code for code, text in re.findall(r'<!ENTITY (\S+) "([^"]+)">', head)}


def build(xml_bytes, output):
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
        ],
    )
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
    parser.add_argument("--output", default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    os.makedirs(os.path.dirname(args.output) or ".", exist_ok=True)
    count = build(fetch(args.source), args.output)
    size = os.path.getsize(args.output) / 1e6
    print(f"wrote {args.output}: {count} entries, {size:.1f} MB")


if __name__ == "__main__":
    main()
