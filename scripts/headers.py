#!/usr/bin/env python3
"""Hold every module header to the module underneath it.

Each file in src/ ends its header with a Return type line. Where that line
enumerates names, they have to be the names the file actually returns or
exports. A header that describes itself in prose is left alone, since prose
is a fair way to describe a table of forty constants.

Exits non-zero and prints what drifted.
"""
import os
import re
import sys

EXPORTS = re.compile(r"^\t([A-Za-z_]\w*)\s*=", re.M)
TYPES = re.compile(r"^export type (?:function )?([A-Za-z_]\w*)", re.M)
BLURB = re.compile(r"Return type:\s*(.*?)(?:\n\tExample|\n--\]=\])", re.S)
TABLE = re.compile(r"return table\.freeze\(\{(.*?)\n\}\)", re.S)
NAMES = re.compile(r"\b([A-Z][A-Za-z0-9_]*)\b")


PROSE = re.compile(r"\b(?!and\b|or\b)[a-z]\w*")


def listed(blurb, lead):
    """The names a header enumerates after `lead`, and whether it enumerated them all.

    A header may name some and describe the rest, as the constants files do with
    "MAP, CONFIRM_ID and those answers". Prose like that means the list is open, so
    an omission is fair; naming something the module does not have never is.
    """
    found = re.search(lead + r" ([^.]*)\.", blurb)
    if found is None:
        return None, False
    said = found.group(1)
    return NAMES.findall(said), PROSE.search(said) is None


def drifted(path):
    held = open(path, encoding="utf-8").read()
    blurb = BLURB.search(held)
    if blurb is None:
        return []

    said = blurb.group(1)
    out = []

    names, whole = listed(said, r"[Aa] table with")
    table = TABLE.search(held)
    if names is not None and table is not None:
        real = EXPORTS.findall(table.group(1))
        out += [(path, "exports, named but absent", n) for n in names if n not in real]
        if whole:
            out += [(path, "exports, not named", n) for n in real if n not in names]

    kinds, every = listed(said, r"The types? (?:are|is)")
    if kinds is not None:
        real = TYPES.findall(held)
        out += [(path, "types, named but absent", n) for n in kinds if n not in real]
        if every:
            out += [(path, "types, not named", n) for n in real if n not in kinds]

    return out


def main():
    bad = []
    for root, _, files in os.walk("src"):
        for name in sorted(files):
            if name.endswith(".luau"):
                bad += drifted(os.path.join(root, name))

    for path, what, name in bad:
        print(f"{path}: {what}: {name}")

    if bad:
        print(f"\n{len(bad)} name(s) where a header and its module disagree", file=sys.stderr)
        return 1

    print(f"every header matches its module")
    return 0


if __name__ == "__main__":
    sys.exit(main())
