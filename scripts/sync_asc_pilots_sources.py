#!/usr/bin/env python3
"""Sync ASCPilots target Sources to match AlaskaSkydiveCenter (minus ASCApp, plus ASCPilotsApp)."""
from __future__ import annotations

import os
import re
import secrets

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PBX = os.path.join(ROOT, "MalfunctionDZ.xcodeproj", "project.pbxproj")

ASC_SOURCES = "4735E0D943F8F72014237355"
PILOTS_SOURCES = "8CBE50444F21929A2171976C"
ASC_APP_BUILD = "9253A8FD2FC80F2839C69227"
PILOTS_APP_BUILD = "4603925FBF6FA491DBC3999D"


def nid() -> str:
    return secrets.token_hex(12).upper()


def main() -> None:
    text = open(PBX, encoding="utf-8").read()

    asc_m = re.search(
        rf"{ASC_SOURCES} /\* Sources \*/ = \{{[^}}]+files = \(([^)]+)\)",
        text,
        re.DOTALL,
    )
    if not asc_m:
        raise SystemExit("AlaskaSkydiveCenter Sources phase not found")

    asc_entries = re.findall(r"([A-F0-9]{24}) /\* ([^*]+) \*/", asc_m.group(1))

    bf_to_fr: dict[str, str] = {}
    for m in re.finditer(
        r"^\t\t([A-F0-9]{24}) /\* ([^*]+\.swift) in Sources \*/ = \{isa = PBXBuildFile; fileRef = ([A-F0-9]{24})",
        text,
        re.MULTILINE,
    ):
        bf_to_fr[m.group(1)] = m.group(3)

    # Reuse existing ASCPilots build entries where file matches; create missing ones.
    pilots_m = re.search(
        rf"{PILOTS_SOURCES} /\* Sources \*/ = \{{[^}}]+files = \(([^)]+)\)",
        text,
        re.DOTALL,
    )
    existing_pilots: dict[str, str] = {}
    if pilots_m:
        for bid, name in re.findall(r"([A-F0-9]{24}) /\* ([^*]+) \*/", pilots_m.group(1)):
            existing_pilots[name] = bid

    new_build_lines: list[str] = []
    pilots_files_list: list[str] = []

    for bid, name in asc_entries:
        if bid == ASC_APP_BUILD or name == "ASCApp.swift in Sources":
            continue
        if name in existing_pilots:
            nb = existing_pilots[name]
        else:
            fr = bf_to_fr.get(bid)
            if not fr:
                print("WARN: no fileRef for", name, bid)
                continue
            nb = nid()
            new_build_lines.append(
                f"\t\t{nb} /* {name} */ = {{isa = PBXBuildFile; fileRef = {fr} /* {name.replace(' in Sources', '')} */; }};"
            )
        pilots_files_list.append(f"\t\t\t\t{nb} /* {name} */,")

    if PILOTS_APP_BUILD not in [b for b, _ in asc_entries]:
        pilots_files_list.append(f"\t\t\t\t{PILOTS_APP_BUILD} /* ASCPilotsApp.swift in Sources */,")

    new_sources = f"""\t\t{PILOTS_SOURCES} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{chr(10).join(pilots_files_list)}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};"""

    if new_build_lines:
        text = text.replace(
            "/* End PBXBuildFile section */",
            "\n".join(new_build_lines) + "\n/* End PBXBuildFile section */",
        )

    text = re.sub(
        rf"\t\t{PILOTS_SOURCES} /\* Sources \*/ = \{{.*?\n\t\t\}};",
        new_sources,
        text,
        count=1,
        flags=re.DOTALL,
    )

    open(PBX, "w", encoding="utf-8").write(text)
    print(f"Synced ASCPilots Sources ({len(pilots_files_list)} files).")


if __name__ == "__main__":
    main()
