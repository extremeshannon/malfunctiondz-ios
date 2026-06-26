#!/usr/bin/env python3
"""Add HHIO target to MalfunctionDZ.xcodeproj (mirrors ASCPackers sources + HHIO-specific files)."""
from __future__ import annotations

import os
import re
import secrets

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PBX = os.path.join(ROOT, "MalfunctionDZ.xcodeproj", "project.pbxproj")

PACKERS_SOURCES_PHASE = "BBE22AE7CE0E6145FFC082FD"
PACKERS_APP_BUILD = "A5E4B2555648B9447772D897"
PACKERS_TARGET = "72F4045A7D3B1B1A1A33A1A7"
PACKERS_PROD_REF = "450E32E73B9723DB390B67D8"
PACKERS_ENT_REF = "39B1C7C8C4AA1F02BEBE2EE4"
PACKERS_APP_REF = "DD722EEBB084606F8238F25A"

NEW_FILES = [
    ("HHIOApp.swift", "App"),
    ("LoftRecordsViewModel.swift", "ViewModels"),
    ("LoftRecordsRootView.swift", "Loft"),
]


def nid() -> str:
    return secrets.token_hex(12).upper()


def add_file_to_project(text: str, filename: str, group_hint: str) -> str:
    if f"/* {filename} */" in text and "PBXFileReference" in text:
        return text
    fr = nid()
    # add build files for each target sources phase that includes LoftRootView
    loft_bf = re.search(
        r"([A-F0-9]{24}) /\* LoftRootView\.swift in Sources \*/ = \{isa = PBXBuildFile; fileRef = ([A-F0-9]{24})",
        text,
    )
    if not loft_bf:
        raise SystemExit("LoftRootView build file not found")
    template_bf = loft_bf.group(1)
    phases = re.findall(
        rf"([A-F0-9]{{24}}) /\* Sources \*/ = \{{[^}}]+files = \(([^)]*{template_bf}[^)]*)\)",
        text,
        re.DOTALL,
    )
    new_bfs: list[str] = []
    phase_inserts: list[tuple[str, str]] = []
    for phase_id, _ in phases:
        bf = nid()
        new_bfs.append(
            f"\t\t{bf} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {fr} /* {filename} */; }};"
        )
        phase_inserts.append((phase_id, bf))

    text = text.replace(
        "/* End PBXBuildFile section */",
        "\n".join(new_bfs) + "\n/* End PBXBuildFile section */",
    )
    text = text.replace(
        "/* End PBXFileReference section */",
        f'\t\t{fr} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = "<group>"; }};\n/* End PBXFileReference section */',
    )
    if group_hint == "App":
        text = text.replace(
            f"{PACKERS_APP_REF} /* ASCPackersApp.swift */,",
            f"{PACKERS_APP_REF} /* ASCPackersApp.swift */,\n\t\t\t\t{fr} /* {filename} */,",
            1,
        )
    elif group_hint == "ViewModels":
        text = text.replace(
            "FB063D3B2F54BB280227638 /* JumpCheckViewModel.swift */,",
            f"FB063D3B2F54BB280227638 /* JumpCheckViewModel.swift */,\n\t\t\t\t{fr} /* {filename} */,",
            1,
        )
    elif group_hint == "Loft":
        text = text.replace(
            "681FBD3163B41BF49E8DC0CE /* PackerGearRoomRootView.swift */,",
            f"681FBD3163B41BF49E8DC0CE /* PackerGearRoomRootView.swift */,\n\t\t\t\t{fr} /* {filename} */,",
            1,
        )
    for phase_id, bf in phase_inserts:
        text = text.replace(
            f"\t\t\t\t{template_bf} /* LoftRootView.swift in Sources */,",
            f"\t\t\t\t{template_bf} /* LoftRootView.swift in Sources */,\n\t\t\t\t{bf} /* {filename} in Sources */,",
            1,
        )
    return text


def main() -> None:
    text = open(PBX, encoding="utf-8").read()
    for fname, grp in NEW_FILES:
        text = add_file_to_project(text, fname, grp)

    if "HHIO.app */" in text:
        open(PBX, "w", encoding="utf-8").write(text)
        print("HHIO target exists; updated shared source entries.")
        return

    src_phase = re.search(
        rf"{PACKERS_SOURCES_PHASE} /\* Sources \*/ = \{{[^}}]+files = \(([^)]+)\)",
        text,
        re.DOTALL,
    )
    if not src_phase:
        raise SystemExit("ASCPackers Sources phase not found")

    packers_build_ids = re.findall(r"([A-F0-9]{24}) /\* [^*]+ \*/", src_phase.group(1))
    bf_to_fr: dict[str, str] = {}
    for m in re.finditer(
        r"^\t\t([A-F0-9]{24}) /\* ([^*]+\.swift) in Sources \*/ = \{isa = PBXBuildFile; fileRef = ([A-F0-9]{24})",
        text,
        re.MULTILINE,
    ):
        bf_to_fr[m.group(1)] = m.group(3)

    fr_hhio_app = nid()
    fr_hhio_ent = nid()
    fr_prod = nid()
    bf_hhio_main = nid()
    target_id = nid()
    ph_src = nid()
    ph_fw = nid()
    ph_res = nid()
    cfg_list = nid()
    cfg_dbg = nid()
    cfg_rel = nid()
    bf_core = nid()

    hhio_pairs: list[tuple[str, str, str]] = []
    hhio_build_lines: list[str] = []
    for bid in packers_build_ids:
        if bid == PACKERS_APP_BUILD:
            continue
        fr = bf_to_fr.get(bid)
        if not fr:
            continue
        m = re.search(rf"{fr} /\* ([^*]+) \*/ = \{{isa = PBXFileReference;", text)
        name = m.group(1) if m else "unknown.swift"
        if name == "ASCPackersApp.swift":
            continue
        nb = nid()
        hhio_pairs.append((nb, fr, name))
        hhio_build_lines.append(
            f"\t\t{nb} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fr} /* {name} */; }};"
        )

    new_build = (
        "\n".join(hhio_build_lines)
        + f"\n\t\t{bf_hhio_main} /* HHIOApp.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {fr_hhio_app} /* HHIOApp.swift */; }};"
        + f"\n\t\t{bf_core} /* MalfunctionDZCore in Frameworks */ = {{isa = PBXBuildFile; productRef = FB063FAB2F60000100022763 /* MalfunctionDZCore */; }};"
    )
    text = text.replace("/* End PBXBuildFile section */", new_build + "\n/* End PBXBuildFile section */")

    new_refs = (
        f"\t\t{fr_hhio_app} /* HHIOApp.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = HHIOApp.swift; sourceTree = \"<group>\"; }};\n"
        f"\t\t{fr_hhio_ent} /* HHIO.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = HHIO.entitlements; sourceTree = \"<group>\"; }};\n"
        f"\t\t{fr_prod} /* HHIO.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = HHIO.app; sourceTree = BUILT_PRODUCTS_DIR; }};"
    )
    text = text.replace("/* End PBXFileReference section */", new_refs + "\n/* End PBXFileReference section */")

    text = text.replace(
        f"{PACKERS_APP_REF} /* ASCPackersApp.swift */,",
        f"{PACKERS_APP_REF} /* ASCPackersApp.swift */,\n\t\t\t\t{fr_hhio_app} /* HHIOApp.swift */,",
        1,
    )
    text = text.replace(
        f"{PACKERS_ENT_REF} /* ASCPackers.entitlements */,",
        f"{PACKERS_ENT_REF} /* ASCPackers.entitlements */,\n\t\t\t\t{fr_hhio_ent} /* HHIO.entitlements */,",
        1,
    )
    text = text.replace(
        f"{PACKERS_PROD_REF} /* ASCPackers.app */,",
        f"{PACKERS_PROD_REF} /* ASCPackers.app */,\n\t\t\t\t{fr_prod} /* HHIO.app */,",
        1,
    )

    files_list = "\n".join(f"\t\t\t\t{nb} /* {name} in Sources */," for nb, _, name in hhio_pairs)
    hhio_sources = f"""\t\t{ph_src} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{files_list}
\t\t\t\t{bf_hhio_main} /* HHIOApp.swift in Sources */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
"""
    hhio_fw = f"""\t\t{ph_fw} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{bf_core} /* MalfunctionDZCore in Frameworks */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
"""
    hhio_res = f"""\t\t{ph_res} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\tFB28B0C92F78DAEC004C95A0 /* Preview Assets.xcassets in Resources */,
\t\t\t\tFB28B0CA2F78DAEC004C95A0 /* Assets.xcassets in Resources */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
"""

    text = text.replace("/* End PBXFrameworksBuildPhase section */", hhio_fw + "\n/* End PBXFrameworksBuildPhase section */")
    text = text.replace("/* End PBXSourcesBuildPhase section */", hhio_sources + "\n/* End PBXSourcesBuildPhase section */")
    text = text.replace("/* End PBXResourcesBuildPhase section */", hhio_res + "\n/* End PBXResourcesBuildPhase section */")

    native = f"""\t\t{target_id} /* HHIO */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {cfg_list} /* Build configuration list for PBXNativeTarget "HHIO" */;
\t\t\tbuildPhases = (
\t\t\t\t{ph_src} /* Sources */,
\t\t\t\t{ph_fw} /* Frameworks */,
\t\t\t\t{ph_res} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = HHIO;
\t\t\tpackageProductDependencies = (
\t\t\t\tFB063FAB2F60000100022763 /* MalfunctionDZCore */,
\t\t\t);
\t\t\tproductName = HHIO;
\t\t\tproductReference = {fr_prod} /* HHIO.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
"""
    text = text.replace("/* End PBXNativeTarget section */", native + "\n/* End PBXNativeTarget section */")
    text = text.replace(
        f"{PACKERS_TARGET} /* ASCPackers */,\n\t\t\t);",
        f"{PACKERS_TARGET} /* ASCPackers */,\n\t\t\t\t{target_id} /* HHIO */,\n\t\t\t);",
    )
    text = text.replace(
        f"{PACKERS_TARGET} = {{\n\t\t\t\t\tCreatedOnToolsVersion = 15.4;\n\t\t\t\t}};",
        f"{PACKERS_TARGET} = {{\n\t\t\t\t\tCreatedOnToolsVersion = 15.4;\n\t\t\t\t}};\n\t\t\t\t\t{target_id} = {{\n\t\t\t\t\t\tCreatedOnToolsVersion = 15.4;\n\t\t\t\t\t}};",
    )

    m_team = re.search(r"DEVELOPMENT_TEAM = ([A-Z0-9]+);", text)
    team = m_team.group(1) if m_team else "8D9BFVLLPF"

    dbg = f"""\t\t{cfg_dbg} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = HHIO;
\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = MalfunctionDZ/HHIO.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_ASSET_PATHS = "\\"MalfunctionDZ/Preview Content\\"";
\t\t\t\tDEVELOPMENT_TEAM = {team};
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_FILE = MalfunctionDZ/Info.plist;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = "HHIO Loft";
\t\t\t\tINFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO;
\t\t\t\tINFOPLIST_KEY_NSAppTransportSecurity_NSAllowsArbitraryLoadsInWebContent = YES;
\t\t\t\tINFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
\t\t\t\tINFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
\t\t\t\tINFOPLIST_KEY_UILaunchScreen_Generation = YES;
\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.malfunctiondz.app.HHIO.Loft;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = "ASC_HHIO $(inherited)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
"""
    rel = dbg.replace('SWIFT_OPTIMIZATION_LEVEL = "-Onone";', "").replace("name = Debug;", "name = Release;")
    lst = f"""\t\t{cfg_list} /* Build configuration list for PBXNativeTarget "HHIO" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{cfg_dbg} /* Debug */,
\t\t\t\t{cfg_rel} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
"""
    text = text.replace("/* End XCBuildConfiguration section */", dbg + rel + lst + "\n/* End XCBuildConfiguration section */")

    open(PBX, "w", encoding="utf-8").write(text)
    print("Patched:", PBX, "— added HHIO target.")


if __name__ == "__main__":
    main()
