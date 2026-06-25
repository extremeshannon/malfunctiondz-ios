#!/usr/bin/env python3
"""Add any AlaskaSkydiveCenter source files missing from ASCPilots target."""
from __future__ import annotations

import os
import re
import secrets

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PBX = os.path.join(ROOT, "MalfunctionDZ.xcodeproj", "project.pbxproj")

ASC_SOURCES = "4735E0D943F8F72014237355"
PILOTS_SOURCES = "8CBE50444F21929A2171976C"
ASC_APP_BUILD = "9253A8FD2FC80F2839C69227"


def nid() -> str:
    return secrets.token_hex(12).upper()


def main() -> None:
    text = open(PBX, encoding="utf-8").read()

    # file basename -> fileRef id
    name_to_fr: dict[str, str] = {}
    for m in re.finditer(
        r"([A-F0-9]{23,24}) /\* ([^*]+\.swift) \*/ = \{isa = PBXFileReference;",
        text,
    ):
        name_to_fr[m.group(2)] = m.group(1)

    asc_m = re.search(
        rf"{ASC_SOURCES} /\* Sources \*/ = \{{[^}}]+files = \(([^)]+)\)",
        text,
        re.DOTALL,
    )
    pilots_m = re.search(
        rf"{PILOTS_SOURCES} /\* Sources \*/ = \{{[^}}]+files = \(([^)]+)\)",
        text,
        re.DOTALL,
    )
    if not asc_m or not pilots_m:
        raise SystemExit("Sources phases not found")

    asc_names = {
        name.replace(" in Sources", "")
        for _, name in re.findall(r"([A-F0-9]{24}) /\* ([^*]+) \*/", asc_m.group(1))
        if "ASCApp.swift" not in name
    }
    pilots_names = {
        name.replace(" in Sources", "")
        for _, name in re.findall(r"([A-F0-9]{24}) /\* ([^*]+) \*/", pilots_m.group(1))
    }

    missing = sorted(asc_names - pilots_names)
    if not missing:
        print("ASCPilots already has all ASC sources.")
        return

    new_build: list[str] = []
    new_lines: list[str] = []
    for fname in missing:
        fr = name_to_fr.get(fname)
        if not fr:
            print("SKIP (no fileRef):", fname)
            continue
        bid = nid()
        new_build.append(
            f"\t\t{bid} /* {fname} in Sources */ = {{isa = PBXBuildFile; fileRef = {fr} /* {fname} */; }};"
        )
        new_lines.append(f"\t\t\t\t{bid} /* {fname} in Sources */,")

    if not new_lines:
        return

    text = text.replace(
        "/* End PBXBuildFile section */",
        "\n".join(new_build) + "\n/* End PBXBuildFile section */",
    )

    # Insert after PilotCurrencyCard line (stable anchor in pilots sources)
    anchor = "E81F815E333EEBA2237ACA6A /* PilotCurrencyCard.swift in Sources */,"
    if anchor not in text:
        raise SystemExit("Anchor not found in pilots sources")
    insert = anchor + "\n" + "\n".join(new_lines)
    text = text.replace(anchor, insert, 1)

    open(PBX, "w", encoding="utf-8").write(text)
    print(f"Added {len(new_lines)} files to ASCPilots:", ", ".join(missing))


if __name__ == "__main__":
    main()
