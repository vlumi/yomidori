#!/usr/bin/env python3
"""The shot list from shots.json, for shoot.sh and screenshots.py.

  shots.py <platform>            # the shots that platform carries, in capture order
  shots.py <platform> --plain    # one per line: name <TAB> title <TAB> KEY=value ... <TAB> stage
  shots.py <platform> --store    # names only, in store order
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def load():
    return json.load(open(os.path.join(HERE, "shots.json")))


def for_platform(platform, order="capture"):
    doc = load()
    return [(name, doc["shots"][name]) for name in doc[order]
            if platform in doc["shots"][name]["platforms"]]


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    platform = sys.argv[1]
    flags = sys.argv[2:]
    if "--store" in flags:
        for name, _ in for_platform(platform, "store"):
            print(name)
        return
    for name, shot in for_platform(platform):
        if "--plain" in flags:
            args = " ".join(f"{k}={v}" for k, v in shot.get("demo", {}).items())
            print("\t".join([name, shot["title"], args, shot.get("stage", "")]))
        else:
            print(f"{name}: {shot['title']}\n  {shot['about']}")


if __name__ == "__main__":
    main()
