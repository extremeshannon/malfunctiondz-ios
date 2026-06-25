#!/usr/bin/env python3
"""Add ASCStaff target to MalfunctionDZ.xcodeproj (mirrors MalfunctionDZ staff app)."""
from __future__ import annotations

import os
import re
import secrets

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PBX = os.path.join(ROOT, "MalfunctionDZ.xcodeproj", "project.pbxproj")

MDZ_SOURCES_PHASE = "FB367C482F510E6000FBAD05"
MDZ_APP_BUILD = "FB367DCC2F52007600FBAD05"
MDZ_RES_DBG = "FB367C5B2F510E6100FBAD05"
MDZ_ENT_REF = "FBFFF0E42F58BC1F009895AE"


def nid() -> str:
    return secrets.token_hex(12).upper()


def main() -> None:
    text = open(PBX, encoding="utf-8").read()
    if "ASCStaff.app */" in text:
        print("Already contains ASCStaff target; skipping.")
        return

    src_phase = re.search(
        rf"{MDZ_SOURCES_PHASE} /\* Sources \*/ = \{{[^}}]+files = \(([^)]+)\)",
        text,
        re.DOTALL,
    )
    if not src_phase:
        raise SystemExit("MalfunctionDZ Sources phase not found")

    mdz_build_ids = re.findall(r"([A-F0-9]{24}) /\* [^*]+ \*/", src_phase.group(1))

    bf_to_fr: dict[str, str] = {}
    for m in re.finditer(
        r"^\t\t([A-F0-9]{24}) /\* ([^*]+\.swift) in Sources \*/ = \{isa = PBXBuildFile; fileRef = ([A-F0-9]{24})",
        text,
        re.MULTILINE,
    ):
        bf_to_fr[m.group(1)] = m.group(3)

    fr_staff_app = nid()
    fr_staff_ent = nid()
    fr_prod = nid()
    bf_staff_main = nid()
    target_id = nid()
    ph_src = nid()
    ph_fw = nid()
    ph_res = nid()
    cfg_list = nid()
    cfg_dbg = nid()
    cfg_rel = nid()
    bf_core = nid()

    staff_pairs: list[tuple[str, str, str]] = []
    staff_build_lines: list[str] = []

    for bid in mdz_build_ids:
        if bid == MDZ_APP_BUILD:
            continue
        fr = bf_to_fr.get(bid)
        if not fr:
            continue
        m = re.search(rf"{fr} /\* ([^*]+) \*/ = \{{isa = PBXFileReference;", text)
        name = m.group(1) if m else "unknown.swift"
        nb = nid()
        staff_pairs.append((nb, fr, name))
        staff_build_lines.append(
            f"\t\t{nb} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fr} /* {name} */; }};"
        )

    new_build = (
        "\n".join(staff_build_lines)
        + f"\n\t\t{bf_staff_main} /* ASCStaffApp.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {fr_staff_app} /* ASCStaffApp.swift */; }};"
        + f"\n\t\t{bf_core} /* MalfunctionDZCore in Frameworks */ = {{isa = PBXBuildFile; productRef = FB063FAB2F60000100022763 /* MalfunctionDZCore */; }};"
    )
    text = text.replace("/* End PBXBuildFile section */", new_build + "\n/* End PBXBuildFile section */")

    new_refs = (
        f"\t\t{fr_staff_app} /* ASCStaffApp.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ASCStaffApp.swift; sourceTree = \"<group>\"; }};\n"
        f"\t\t{fr_staff_ent} /* ASCStaff.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = ASCStaff.entitlements; sourceTree = \"<group>\"; }};\n"
        f"\t\t{fr_prod} /* ASCStaff.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = ASCStaff.app; sourceTree = BUILT_PRODUCTS_DIR; }};"
    )
    text = text.replace("/* End PBXFileReference section */", new_refs + "\n/* End PBXFileReference section */")

    text = text.replace(
        "61CB6D321063D4BE7B7C506C /* ASCPilotsApp.swift */,",
        "61CB6D321063D4BE7B7C506C /* ASCPilotsApp.swift */,\n\t\t\t\t"
        + fr_staff_app
        + " /* ASCStaffApp.swift */,",
    )
    text = text.replace(
        f"{MDZ_ENT_REF} /* MalfunctionDZ.entitlements */,",
        f"{MDZ_ENT_REF} /* MalfunctionDZ.entitlements */,\n\t\t\t\t{fr_staff_ent} /* ASCStaff.entitlements */,",
    )
    text = text.replace(
        "2BB191F126E430FD39FEA389 /* ASCPilots.app */,",
        "2BB191F126E430FD39FEA389 /* ASCPilots.app */,\n\t\t\t\t"
        + fr_prod
        + " /* ASCStaff.app */,",
    )

    files_list = "\n".join(f"\t\t\t\t{nb} /* {name} in Sources */," for nb, _, name in staff_pairs)
    staff_sources = f"""\t\t{ph_src} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{files_list}
\t\t\t\t{bf_staff_main} /* ASCStaffApp.swift in Sources */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
"""
    staff_fw = f"""\t\t{ph_fw} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{bf_core} /* MalfunctionDZCore in Frameworks */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
"""
    staff_res = f"""\t\t{ph_res} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\tFB28B0C92F78DAEC004C95A0 /* Preview Assets.xcassets in Resources */,
\t\t\t\tFB28B0CA2F78DAEC004C95A0 /* Assets.xcassets in Resources */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
"""

    text = text.replace("/* End PBXFrameworksBuildPhase section */", staff_fw + "\n/* End PBXFrameworksBuildPhase section */")
    text = text.replace("/* End PBXSourcesBuildPhase section */", staff_sources + "\n/* End PBXSourcesBuildPhase section */")
    text = text.replace("/* End PBXResourcesBuildPhase section */", staff_res + "\n/* End PBXResourcesBuildPhase section */")

    native = f"""\t\t{target_id} /* ASCStaff */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {cfg_list} /* Build configuration list for PBXNativeTarget "ASCStaff" */;
\t\t\tbuildPhases = (
\t\t\t\t{ph_src} /* Sources */,
\t\t\t\t{ph_fw} /* Frameworks */,
\t\t\t\t{ph_res} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = ASCStaff;
\t\t\tpackageProductDependencies = (
\t\t\t\tFB063FAB2F60000100022763 /* MalfunctionDZCore */,
\t\t\t);
\t\t\tproductName = ASCStaff;
\t\t\tproductReference = {fr_prod} /* ASCStaff.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
"""
    text = text.replace("/* End PBXNativeTarget section */", native + "\n/* End PBXNativeTarget section */")

    text = text.replace(
        "58E1A3BBEA07CF5DB62EE6E3 /* ASCPilots */,\n\t\t\t);",
        "58E1A3BBEA07CF5DB62EE6E3 /* ASCPilots */,\n\t\t\t\t"
        + target_id
        + " /* ASCStaff */,\n\t\t\t);",
    )

    text = text.replace(
        "58E1A3BBEA07CF5DB62EE6E3 = {\n\t\t\t\t\tCreatedOnToolsVersion = 15.4;\n\t\t\t\t};",
        "58E1A3BBEA07CF5DB62EE6E3 = {\n\t\t\t\t\tCreatedOnToolsVersion = 15.4;\n\t\t\t\t};\n\t\t\t\t\t"
        + target_id
        + " = {\n\t\t\t\t\t\tCreatedOnToolsVersion = 15.4;\n\t\t\t\t\t};",
    )

    m_team = re.search(r"DEVELOPMENT_TEAM = ([A-Z0-9]+);", text)
    team = m_team.group(1) if m_team else "8D9BFVLLPF"

    dbg = f"""\t\t{cfg_dbg} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = MalfunctionDZ/ASCStaff.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 46;
\t\t\t\tDEVELOPMENT_ASSET_PATHS = "\\"MalfunctionDZ/Preview Content\\"";
\t\t\t\tDEVELOPMENT_TEAM = {team};
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_FILE = MalfunctionDZ/Info.plist;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = "ASC Staff";
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
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.malfunctiondz.app.ASC.Staff;
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
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = MalfunctionDZ/ASCStaff.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 46;
\t\t\t\tDEVELOPMENT_ASSET_PATHS = "\\"MalfunctionDZ/Preview Content\\"";
\t\t\t\tDEVELOPMENT_TEAM = {team};
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_FILE = MalfunctionDZ/Info.plist;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = "ASC Staff";
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
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.malfunctiondz.app.ASC.Staff;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Release;
\t\t}};
"""
    lst = f"""\t\t{cfg_list} /* Build configuration list for PBXNativeTarget "ASCStaff" */ = {{
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
    print("Patched:", PBX, "— added ASCStaff target.")
    print("TARGET_ID", target_id)


if __name__ == "__main__":
    main()
