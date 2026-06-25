#!/usr/bin/env python3
"""Add ASCPilots target to MalfunctionDZ.xcodeproj/project.pbxproj (mirrors AlaskaSkydiveCenter)."""
from __future__ import annotations

import os
import re
import secrets

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PBX = os.path.join(ROOT, "MalfunctionDZ.xcodeproj", "project.pbxproj")

ASC_SOURCES_PHASE = "4735E0D943F8F72014237355"
ASC_APP_BUILD = "9253A8FD2FC80F2839C69227"
ASC_APP_REF = "636ACA25B0FB6724F62901C9"
ASC_ENT_REF = None  # resolved below


def nid() -> str:
    return secrets.token_hex(12).upper()


def main() -> None:
    text = open(PBX, encoding="utf-8").read()
    if "ASCPilots.app */" in text:
        print("Already contains ASCPilots target; skipping.")
        return

    m_ent = re.search(r"([A-F0-9]{24}) /\* ASC\.entitlements \*/", text)
    if not m_ent:
        raise SystemExit("ASC.entitlements file ref not found")
    asc_ent_ref = m_ent.group(1)

    src_phase = re.search(
        rf"{ASC_SOURCES_PHASE} /\* Sources \*/ = \{{[^}}]+files = \(([^)]+)\)",
        text,
        re.DOTALL,
    )
    if not src_phase:
        raise SystemExit("AlaskaSkydiveCenter Sources phase not found")

    asc_build_ids = re.findall(r"([A-F0-9]{24}) /\* [^*]+ \*/", src_phase.group(1))

    bf_to_fr: dict[str, str] = {}
    for m in re.finditer(
        r"^\t\t([A-F0-9]{24}) /\* ([^*]+\.swift) in Sources \*/ = \{isa = PBXBuildFile; fileRef = ([A-F0-9]{24})",
        text,
        re.MULTILINE,
    ):
        bf_to_fr[m.group(1)] = m.group(3)

    fr_pilots_app = nid()
    fr_pilots_ent = nid()
    fr_prod = nid()
    bf_pilots_main = nid()
    target_id = nid()
    ph_src = nid()
    ph_fw = nid()
    ph_res = nid()
    cfg_list = nid()
    cfg_dbg = nid()
    cfg_rel = nid()
    bf_core = nid()

    pilots_pairs: list[tuple[str, str, str]] = []
    pilots_build_lines: list[str] = []

    for bid in asc_build_ids:
        if bid == ASC_APP_BUILD:
            continue
        fr = bf_to_fr.get(bid)
        if not fr:
            continue
        m = re.search(rf"{fr} /\* ([^*]+) \*/ = \{{isa = PBXFileReference;", text)
        name = m.group(1) if m else "unknown.swift"
        nb = nid()
        pilots_pairs.append((nb, fr, name))
        pilots_build_lines.append(
            f"\t\t{nb} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fr} /* {name} */; }};"
        )

    new_build = (
        "\n".join(pilots_build_lines)
        + f"\n\t\t{bf_pilots_main} /* ASCPilotsApp.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {fr_pilots_app} /* ASCPilotsApp.swift */; }};"
        + f"\n\t\t{bf_core} /* MalfunctionDZCore in Frameworks */ = {{isa = PBXBuildFile; productRef = FB063FAB2F60000100022763 /* MalfunctionDZCore */; }};"
    )
    text = text.replace("/* End PBXBuildFile section */", new_build + "\n/* End PBXBuildFile section */")

    new_refs = (
        f"\t\t{fr_pilots_app} /* ASCPilotsApp.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ASCPilotsApp.swift; sourceTree = \"<group>\"; }};\n"
        f"\t\t{fr_pilots_ent} /* ASCPilots.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = ASCPilots.entitlements; sourceTree = \"<group>\"; }};\n"
        f"\t\t{fr_prod} /* ASCPilots.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = ASCPilots.app; sourceTree = BUILT_PRODUCTS_DIR; }};"
    )
    text = text.replace("/* End PBXFileReference section */", new_refs + "\n/* End PBXFileReference section */")

    text = text.replace(
        f"{ASC_APP_REF} /* ASCApp.swift */,",
        f"{ASC_APP_REF} /* ASCApp.swift */,\n\t\t\t\t{fr_pilots_app} /* ASCPilotsApp.swift */,",
    )
    text = text.replace(
        f"{asc_ent_ref} /* ASC.entitlements */,",
        f"{asc_ent_ref} /* ASC.entitlements */,\n\t\t\t\t{fr_pilots_ent} /* ASCPilots.entitlements */,",
    )
    text = text.replace(
        "0D708EA0597452135AF3B10A /* AlaskaSkydiveCenter.app */,",
        "0D708EA0597452135AF3B10A /* AlaskaSkydiveCenter.app */,\n\t\t\t\t"
        + fr_prod
        + " /* ASCPilots.app */,",
    )

    files_list = "\n".join(f"\t\t\t\t{nb} /* {name} in Sources */," for nb, _, name in pilots_pairs)
    pilots_sources = f"""\t\t{ph_src} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{files_list}
\t\t\t\t{bf_pilots_main} /* ASCPilotsApp.swift in Sources */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
"""
    pilots_fw = f"""\t\t{ph_fw} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{bf_core} /* MalfunctionDZCore in Frameworks */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
"""
    pilots_res = f"""\t\t{ph_res} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\tFB28B0C92F78DAEC004C95A0 /* Preview Assets.xcassets in Resources */,
\t\t\t\tFB28B0CA2F78DAEC004C95A0 /* Assets.xcassets in Resources */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
"""

    text = text.replace("/* End PBXFrameworksBuildPhase section */", pilots_fw + "\n/* End PBXFrameworksBuildPhase section */")
    text = text.replace("/* End PBXSourcesBuildPhase section */", pilots_sources + "\n/* End PBXSourcesBuildPhase section */")
    text = text.replace("/* End PBXResourcesBuildPhase section */", pilots_res + "\n/* End PBXResourcesBuildPhase section */")

    native = f"""\t\t{target_id} /* ASCPilots */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {cfg_list} /* Build configuration list for PBXNativeTarget "ASCPilots" */;
\t\t\tbuildPhases = (
\t\t\t\t{ph_src} /* Sources */,
\t\t\t\t{ph_fw} /* Frameworks */,
\t\t\t\t{ph_res} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = ASCPilots;
\t\t\tpackageProductDependencies = (
\t\t\t\tFB063FAB2F60000100022763 /* MalfunctionDZCore */,
\t\t\t);
\t\t\tproductName = ASCPilots;
\t\t\tproductReference = {fr_prod} /* ASCPilots.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
"""
    text = text.replace("/* End PBXNativeTarget section */", native + "\n/* End PBXNativeTarget section */")

    text = text.replace(
        "D2C4D853457DBF13A549ACBA /* AlaskaSkydiveCenter */,\n\t\t\t);",
        "D2C4D853457DBF13A549ACBA /* AlaskaSkydiveCenter */,\n\t\t\t\t"
        + target_id
        + " /* ASCPilots */,\n\t\t\t);",
    )

    text = text.replace(
        "D2C4D853457DBF13A549ACBA = {\n\t\t\t\t\tCreatedOnToolsVersion = 15.4;\n\t\t\t\t};",
        "D2C4D853457DBF13A549ACBA = {\n\t\t\t\t\tCreatedOnToolsVersion = 15.4;\n\t\t\t\t};\n\t\t\t\t\t"
        + target_id
        + " = {\n\t\t\t\t\t\tCreatedOnToolsVersion = 15.4;\n\t\t\t\t\t};",
    )

    dbg = f"""\t\t{cfg_dbg} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = "AppIcon-ASC";
\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = MalfunctionDZ/ASCPilots.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 30;
\t\t\t\tDEVELOPMENT_ASSET_PATHS = "\\"MalfunctionDZ/Preview Content\\"";
\t\t\t\tDEVELOPMENT_TEAM = 8D9BFVLLPF;
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_FILE = MalfunctionDZ/Info.plist;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = "ASC Pilots";
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
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.malfunctiondz.app.ASCPilots;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
"""
    rel = f"""\t\t{cfg_rel} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = "AppIcon-ASC";
\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = MalfunctionDZ/ASCPilots.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 30;
\t\t\t\tDEVELOPMENT_ASSET_PATHS = "\\"MalfunctionDZ/Preview Content\\"";
\t\t\t\tDEVELOPMENT_TEAM = 8D9BFVLLPF;
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_FILE = MalfunctionDZ/Info.plist;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = "ASC Pilots";
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
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.malfunctiondz.app.ASCPilots;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Release;
\t\t}};
"""
    lst = f"""\t\t{cfg_list} /* Build configuration list for PBXNativeTarget "ASCPilots" */ = {{
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
    print("Patched:", PBX, "— added ASCPilots target.")


if __name__ == "__main__":
    main()
