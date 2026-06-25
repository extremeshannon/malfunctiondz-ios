#!/usr/bin/env python3
"""Add any MalfunctionDZ source files missing from ASCStaff target."""
from __future__ import annotations

import os
import re
import secrets

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PBX = os.path.join(ROOT, "MalfunctionDZ.xcodeproj", "project.pbxproj")

MDZ_SOURCES = "FB367C482F510E6000FBAD05"
MDZ_APP_BUILD = "FB367DCC2F52007600FBAD05"
STAFF_SOURCES = "1D66EDE47759C5074A016BCC"
STAFF_APP_BUILD = "6644DE212236B4912594B8B8"


def nid() -> str:
    return secrets.token_hex(12).upper()


def main() -> None:
    text = open(PBX, encoding="utf-8").read()

    name_to_fr: dict[str, str] = {}
    for m in re.finditer(
        r"([A-F0-9]{23,24}) /\* ([^*]+\.swift) \*/ = \{isa = PBXFileReference;",
        text,
    ):
        name_to_fr[m.group(2)] = m.group(1)

    mdz_m = re.search(
        rf"{MDZ_SOURCES} /\* Sources \*/ = \{{[^}}]+files = \(([^)]+)\)",
        text,
        re.DOTALL,
    )
    staff_m = re.search(
        rf"{STAFF_SOURCES} /\* Sources \*/ = \{{[^}}]+files = \(([^)]+)\)",
        text,
        re.DOTALL,
    )
    if not mdz_m or not staff_m:
        raise SystemExit("Sources phases not found")

    mdz_names = {
        name.replace(" in Sources", "")
        for _, name in re.findall(r"([A-F0-9]{24}) /\* ([^*]+) \*/", mdz_m.group(1))
        if name != "MalfunctionDZApp.swift in Sources"
    }
    staff_names = {
        name.replace(" in Sources", "")
        for _, name in re.findall(r"([A-F0-9]{24}) /\* ([^*]+) \*/", staff_m.group(1))
        if name != "ASCStaffApp.swift in Sources"
    }

    missing = sorted(mdz_names - staff_names)
    if not missing:
        print("ASCStaff already has all MalfunctionDZ sources.")
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
        f"\t\t\t\t{STAFF_APP_BUILD} /* ASCStaffApp.swift in Sources */,",
        "\n".join(new_lines)
        + f"\n\t\t\t\t{STAFF_APP_BUILD} /* ASCStaffApp.swift in Sources */,",
    )

    open(PBX, "w", encoding="utf-8").write(text)
    print(f"Added {len(new_lines)} source(s) to ASCStaff:", ", ".join(missing))


if __name__ == "__main__":
    main()
