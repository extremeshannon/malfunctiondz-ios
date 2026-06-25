#!/usr/bin/env python3
"""Add any ASCPilots source files missing from ASCPackers target."""
from __future__ import annotations

import os
import re
import secrets

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PBX = os.path.join(ROOT, "MalfunctionDZ.xcodeproj", "project.pbxproj")

PILOTS_SOURCES = "8CBE50444F21929A2171976C"
PILOTS_APP_BUILD = "4603925FBF6FA491DBC3999D"


def nid() -> str:
    return secrets.token_hex(12).upper()


def main() -> None:
    text = open(PBX, encoding="utf-8").read()

    packers_m = re.search(
        r"([A-F0-9]{24}) /\* Sources \*/ = \{[^}]+files = \([^)]*ASCPackersApp\.swift in Sources",
        text,
        re.DOTALL,
    )
    if not packers_m:
        raise SystemExit("ASCPackers Sources phase not found")

    packers_sources = packers_m.group(1)
    packers_app_m = re.search(
        rf"([A-F0-9]{{24}}) /\* ASCPackersApp\.swift in Sources \*/",
        text,
    )
    if not packers_app_m:
        raise SystemExit("ASCPackersApp build file not found")
    packers_app_build = packers_app_m.group(1)

    name_to_fr: dict[str, str] = {}
    for m in re.finditer(
        r"([A-F0-9]{23,24}) /\* ([^*]+\.swift) \*/ = \{isa = PBXFileReference;",
        text,
    ):
        name_to_fr[m.group(2)] = m.group(1)

    pilots_m = re.search(
        rf"{PILOTS_SOURCES} /\* Sources \*/ = \{{[^}}]+files = \(([^)]+)\)",
        text,
        re.DOTALL,
    )
    packers_src_m = re.search(
        rf"{packers_sources} /\* Sources \*/ = \{{[^}}]+files = \(([^)]+)\)",
        text,
        re.DOTALL,
    )
    if not pilots_m or not packers_src_m:
        raise SystemExit("Sources phases not found")

    pilots_names = {
        name.replace(" in Sources", "")
        for _, name in re.findall(r"([A-F0-9]{24}) /\* ([^*]+) \*/", pilots_m.group(1))
        if name != "ASCPilotsApp.swift in Sources"
    }
    packers_names = {
        name.replace(" in Sources", "")
        for _, name in re.findall(r"([A-F0-9]{24}) /\* ([^*]+) \*/", packers_src_m.group(1))
        if name != "ASCPackersApp.swift in Sources"
    }

    missing = sorted(pilots_names - packers_names)
    if not missing:
        print("ASCPackers already has all ASCPilots sources.")
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

    text = text.replace(
        f"\t\t\t\t{packers_app_build} /* ASCPackersApp.swift in Sources */,",
        "\n".join(new_lines)
        + f"\n\t\t\t\t{packers_app_build} /* ASCPackersApp.swift in Sources */,",
    )

    open(PBX, "w", encoding="utf-8").write(text)
    print(f"Added {len(new_lines)} source(s) to ASCPackers:", ", ".join(missing))


if __name__ == "__main__":
    main()
