#!/usr/bin/env python3
"""Add ASCPackers target to MalfunctionDZ.xcodeproj (mirrors ASCPilots sources)."""
from __future__ import annotations

import os
import re
import secrets

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PBX = os.path.join(ROOT, "MalfunctionDZ.xcodeproj", "project.pbxproj")

PILOTS_SOURCES_PHASE = "8CBE50444F21929A2171976C"
PILOTS_APP_BUILD = "4603925FBF6FA491DBC3999D"
ASC_STAFF_TARGET = "42247FA7975C756EE372F226"
PILOTS_ENT_REF = "778B38E747A173E34FDA6D1D"
STAFF_APP_REF = "791AC4A30F02E343582C9539"
STAFF_ENT_REF = "02B54E918A707B49D210D4D8"
STAFF_PROD_REF = "9DDF778B7F3CE90083F398FC"


def nid() -> str:
    return secrets.token_hex(12).upper()


def main() -> None:
    text = open(PBX, encoding="utf-8").read()
    if "ASCPackers.app */" in text:
        print("Already contains ASCPackers target; skipping.")
        return

    src_phase = re.search(
        rf"{PILOTS_SOURCES_PHASE} /\* Sources \*/ = \{{[^}}]+files = \(([^)]+)\)",
        text,
        re.DOTALL,
    )
    if not src_phase:
        raise SystemExit("ASCPilots Sources phase not found")

    pilots_build_ids = re.findall(r"([A-F0-9]{24}) /\* [^*]+ \*/", src_phase.group(1))

    bf_to_fr: dict[str, str] = {}
    for m in re.finditer(
        r"^\t\t([A-F0-9]{24}) /\* ([^*]+\.swift) in Sources \*/ = \{isa = PBXBuildFile; fileRef = ([A-F0-9]{24})",
        text,
        re.MULTILINE,
    ):
        bf_to_fr[m.group(1)] = m.group(3)

    fr_packers_app = nid()
    fr_packers_ent = nid()
    fr_prod = nid()
    bf_packers_main = nid()
    target_id = nid()
    ph_src = nid()
    ph_fw = nid()
    ph_res = nid()
    cfg_list = nid()
    cfg_dbg = nid()
    cfg_rel = nid()
    bf_core = nid()

    packers_pairs: list[tuple[str, str, str]] = []
    packers_build_lines: list[str] = []

    for bid in pilots_build_ids:
        if bid == PILOTS_APP_BUILD:
            continue
        fr = bf_to_fr.get(bid)
        if not fr:
            continue
        m = re.search(rf"{fr} /\* ([^*]+) \*/ = \{{isa = PBXFileReference;", text)
        name = m.group(1) if m else "unknown.swift"
        nb = nid()
        packers_pairs.append((nb, fr, name))
        packers_build_lines.append(
            f"\t\t{nb} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fr} /* {name} */; }};"
        )

    new_build = (
        "\n".join(packers_build_lines)
        + f"\n\t\t{bf_packers_main} /* ASCPackersApp.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {fr_packers_app} /* ASCPackersApp.swift */; }};"
        + f"\n\t\t{bf_core} /* MalfunctionDZCore in Frameworks */ = {{isa = PBXBuildFile; productRef = FB063FAB2F60000100022763 /* MalfunctionDZCore */; }};"
    )
    text = text.replace("/* End PBXBuildFile section */", new_build + "\n/* End PBXBuildFile section */")

    new_refs = (
        f"\t\t{fr_packers_app} /* ASCPackersApp.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ASCPackersApp.swift; sourceTree = \"<group>\"; }};\n"
        f"\t\t{fr_packers_ent} /* ASCPackers.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = ASCPackers.entitlements; sourceTree = \"<group>\"; }};\n"
        f"\t\t{fr_prod} /* ASCPackers.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = ASCPackers.app; sourceTree = BUILT_PRODUCTS_DIR; }};"
    )
    text = text.replace("/* End PBXFileReference section */", new_refs + "\n/* End PBXFileReference section */")

    text = text.replace(
        f"{STAFF_APP_REF} /* ASCStaffApp.swift */,",
        f"{STAFF_APP_REF} /* ASCStaffApp.swift */,\n\t\t\t\t{fr_packers_app} /* ASCPackersApp.swift */,",
    )
    text = text.replace(
        f"{STAFF_ENT_REF} /* ASCStaff.entitlements */,",
        f"{STAFF_ENT_REF} /* ASCStaff.entitlements */,\n\t\t\t\t{fr_packers_ent} /* ASCPackers.entitlements */,",
    )
    text = text.replace(
        f"{STAFF_PROD_REF} /* ASCStaff.app */,",
        f"{STAFF_PROD_REF} /* ASCStaff.app */,\n\t\t\t\t{fr_prod} /* ASCPackers.app */,",
    )

    files_list = "\n".join(f"\t\t\t\t{nb} /* {name} in Sources */," for nb, _, name in packers_pairs)
    packers_sources = f"""\t\t{ph_src} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{files_list}
\t\t\t\t{bf_packers_main} /* ASCPackersApp.swift in Sources */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
"""
    packers_fw = f"""\t\t{ph_fw} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{bf_core} /* MalfunctionDZCore in Frameworks */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
"""
    packers_res = f"""\t\t{ph_res} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\tFB28B0C92F78DAEC004C95A0 /* Preview Assets.xcassets in Resources */,
\t\t\t\tFB28B0CA2F78DAEC004C95A0 /* Assets.xcassets in Resources */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
"""

    text = text.replace("/* End PBXFrameworksBuildPhase section */", packers_fw + "\n/* End PBXFrameworksBuildPhase section */")
    text = text.replace("/* End PBXSourcesBuildPhase section */", packers_sources + "\n/* End PBXSourcesBuildPhase section */")
    text = text.replace("/* End PBXResourcesBuildPhase section */", packers_res + "\n/* End PBXResourcesBuildPhase section */")

    native = f"""\t\t{target_id} /* ASCPackers */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {cfg_list} /* Build configuration list for PBXNativeTarget "ASCPackers" */;
\t\t\tbuildPhases = (
\t\t\t\t{ph_src} /* Sources */,
\t\t\t\t{ph_fw} /* Frameworks */,
\t\t\t\t{ph_res} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = ASCPackers;
\t\t\tpackageProductDependencies = (
\t\t\t\tFB063FAB2F60000100022763 /* MalfunctionDZCore */,
\t\t\t);
\t\t\tproductName = ASCPackers;
\t\t\tproductReference = {fr_prod} /* ASCPackers.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
"""
    text = text.replace("/* End PBXNativeTarget section */", native + "\n/* End PBXNativeTarget section */")

    text = text.replace(
        f"{ASC_STAFF_TARGET} /* ASCStaff */,\n\t\t\t);",
        f"{ASC_STAFF_TARGET} /* ASCStaff */,\n\t\t\t\t{target_id} /* ASCPackers */,\n\t\t\t);",
    )

    text = text.replace(
        f"{ASC_STAFF_TARGET} = {{\n\t\t\t\t\tCreatedOnToolsVersion = 15.4;\n\t\t\t\t}};",
        f"{ASC_STAFF_TARGET} = {{\n\t\t\t\t\tCreatedOnToolsVersion = 15.4;\n\t\t\t\t}};\n\t\t\t\t\t{target_id} = {{\n\t\t\t\t\t\tCreatedOnToolsVersion = 15.4;\n\t\t\t\t\t}};",
    )

    m_team = re.search(r"DEVELOPMENT_TEAM = ([A-Z0-9]+);", text)
    team = m_team.group(1) if m_team else "8D9BFVLLPF"

    dbg = f"""\t\t{cfg_dbg} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = MalfunctionDZ/ASCPackers.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 46;
\t\t\t\tDEVELOPMENT_ASSET_PATHS = "\\"MalfunctionDZ/Preview Content\\"";
\t\t\t\tDEVELOPMENT_TEAM = {team};
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_FILE = MalfunctionDZ/Info.plist;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = "ASC Packers";
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
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.malfunctiondz.app.ASC.Packers;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = "ASC_PACKERS $(inherited)";
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
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = MalfunctionDZ/ASCPackers.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 46;
\t\t\t\tDEVELOPMENT_ASSET_PATHS = "\\"MalfunctionDZ/Preview Content\\"";
\t\t\t\tDEVELOPMENT_TEAM = {team};
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_FILE = MalfunctionDZ/Info.plist;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = "ASC Packers";
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
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.malfunctiondz.app.ASC.Packers;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = "ASC_PACKERS $(inherited)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Release;
\t\t}};
"""
    lst = f"""\t\t{cfg_list} /* Build configuration list for PBXNativeTarget "ASCPackers" */ = {{
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
    print("Patched:", PBX, "— added ASCPackers target.")
    print("TARGET_ID", target_id)


if __name__ == "__main__":
    main()
