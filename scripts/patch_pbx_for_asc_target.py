#!/usr/bin/env python3
"""Add AlaskaSkydiveCenter target to MalfunctionDZ.xcodeproj/project.pbxproj."""
from __future__ import annotations

import os
import re
import secrets

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PBX = os.path.join(ROOT, "MalfunctionDZ.xcodeproj", "project.pbxproj")


def nid() -> str:
    return secrets.token_hex(12).upper()


def main() -> None:
    text = open(PBX, encoding="utf-8").read()
    if "AlaskaSkydiveCenter.app */" in text:
        print("Already contains AlaskaSkydiveCenter target; skipping.")
        return

    mdz_app_build = "FB367DCC2F52007600FBAD05"

    # Map: PBXBuildFile id -> fileRef id (Swift sources only)
    bf_to_fr: dict[str, str] = {}
    for m in re.finditer(
        r"^\t\t([A-F0-9]{24}) /\* ([^*]+\.swift) in Sources \*/ = \{isa = PBXBuildFile; fileRef = ([A-F0-9]{24})",
        text,
        re.MULTILINE,
    ):
        bf_to_fr[m.group(1)] = m.group(3)

    # Order of MDZ Sources phase
    src_phase = re.search(
        r"FB367C482F510E6000FBAD05 /\* Sources \*/ = \{[^}]+files = \(([^)]+)\)",
        text,
        re.DOTALL,
    )
    if not src_phase:
        raise SystemExit("MDZ Sources phase not found")
    ids = re.findall(r"([A-F0-9]{24}) /\* [^*]+ \*/", src_phase.group(1))

    mdz_extra_build = []  # (build_id, fileRef, display_name)
    fr_app_shell = nid()
    fr_push = nid()
    fr_asc_app = nid()
    bf_mdz_appshell = nid()
    bf_mdz_push = nid()
    bf_asc_appshell = nid()
    bf_asc_push = nid()
    bf_asc_main = nid()
    fr_asc_ent = nid()
    fr_prod_asc = nid()
    target_id = nid()
    ph_src = nid()
    ph_fw = nid()
    ph_res = nid()
    cfg_list = nid()
    cfg_dbg = nid()
    cfg_rel = nid()
    bf_core_asc = nid()

    asc_source_build_lines: list[str] = []
    asc_pairs: list[tuple[str, str, str]] = []

    for bid in ids:
        if bid == mdz_app_build:
            continue
        fr = bf_to_fr.get(bid)
        if not fr:
            continue
        m = re.search(rf"{fr} /\* ([^*]+) \*/ = \{{isa = PBXFileReference;", text)
        name = m.group(1) if m else "unknown.swift"
        nb = nid()
        asc_pairs.append((nb, fr, name))
        asc_source_build_lines.append(f"\t\t{nb} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fr} /* {name} */; }};")

    new_build_files = (
        "\n".join(asc_source_build_lines)
        + "\n\t\t"
        + bf_mdz_appshell
        + " /* AppShellKind.swift in Sources */ = {isa = PBXBuildFile; fileRef = "
        + fr_app_shell
        + " /* AppShellKind.swift */; };\n\t\t"
        + bf_mdz_push
        + " /* PushNavigationSupport.swift in Sources */ = {isa = PBXBuildFile; fileRef = "
        + fr_push
        + " /* PushNavigationSupport.swift */; };\n\t\t"
        + bf_asc_appshell
        + " /* AppShellKind.swift in Sources */ = {isa = PBXBuildFile; fileRef = "
        + fr_app_shell
        + " /* AppShellKind.swift */; };\n\t\t"
        + bf_asc_push
        + " /* PushNavigationSupport.swift in Sources */ = {isa = PBXBuildFile; fileRef = "
        + fr_push
        + " /* PushNavigationSupport.swift */; };\n\t\t"
        + bf_asc_main
        + " /* ASCApp.swift in Sources */ = {isa = PBXBuildFile; fileRef = "
        + fr_asc_app
        + " /* ASCApp.swift */; };\n\t\t"
        + bf_core_asc
        + " /* MalfunctionDZCore in Frameworks */ = {isa = PBXBuildFile; productRef = FB063FAB2F60000100022763 /* MalfunctionDZCore */; };"
    )

    text = text.replace("/* End PBXBuildFile section */", new_build_files + "\n/* End PBXBuildFile section */")

    new_refs = (
        "\t\t"
        + fr_app_shell
        + " /* AppShellKind.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AppShellKind.swift; sourceTree = \"<group>\"; };\n\t\t"
        + fr_push
        + " /* PushNavigationSupport.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = PushNavigationSupport.swift; sourceTree = \"<group>\"; };\n\t\t"
        + fr_asc_app
        + " /* ASCApp.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ASCApp.swift; sourceTree = \"<group>\"; };\n\t\t"
        + fr_asc_ent
        + " /* ASC.entitlements */ = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = ASC.entitlements; sourceTree = \"<group>\"; };\n\t\t"
        + fr_prod_asc
        + " /* AlaskaSkydiveCenter.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = AlaskaSkydiveCenter.app; sourceTree = BUILT_PRODUCTS_DIR; };"
    )
    text = text.replace("/* End PBXFileReference section */", new_refs + "\n/* End PBXFileReference section */")

    text = text.replace(
        "FB367DCB2F52007600FBAD05 /* MalfunctionDZApp.swift */,",
        "FB367DCB2F52007600FBAD05 /* MalfunctionDZApp.swift */,\n\t\t\t\t"
        + fr_app_shell
        + " /* AppShellKind.swift */,\n\t\t\t\t"
        + fr_push
        + " /* PushNavigationSupport.swift */,\n\t\t\t\t"
        + fr_asc_app
        + " /* ASCApp.swift */,",
    )
    text = text.replace(
        "FBFFF0E42F58BC1F009895AE /* MalfunctionDZ.entitlements */,",
        "FBFFF0E42F58BC1F009895AE /* MalfunctionDZ.entitlements */,\n\t\t\t\t"
        + fr_asc_ent
        + " /* ASC.entitlements */,",
    )

    text = text.replace(
        "FB367DCC2F52007600FBAD05 /* MalfunctionDZApp.swift in Sources */,",
        "FB367DCC2F52007600FBAD05 /* MalfunctionDZApp.swift in Sources */,\n\t\t\t\t"
        + bf_mdz_appshell
        + " /* AppShellKind.swift in Sources */,\n\t\t\t\t"
        + bf_mdz_push
        + " /* PushNavigationSupport.swift in Sources */,",
    )

    text = text.replace(
        "FB367C4C2F510E6000FBAD05 /* MalfunctionDZ.app */,",
        "FB367C4C2F510E6000FBAD05 /* MalfunctionDZ.app */,\n\t\t\t\t"
        + fr_prod_asc
        + " /* AlaskaSkydiveCenter.app */,",
    )

    asc_files_list = "\n".join(f"\t\t\t\t{nb} /* {name} in Sources */," for nb, _, name in asc_pairs)
    asc_sources = f"""\t\t{ph_src} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{asc_files_list}
\t\t\t\t{bf_asc_appshell} /* AppShellKind.swift in Sources */,
\t\t\t\t{bf_asc_push} /* PushNavigationSupport.swift in Sources */,
\t\t\t\t{bf_asc_main} /* ASCApp.swift in Sources */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
"""
    asc_fw = f"""\t\t{ph_fw} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{bf_core_asc} /* MalfunctionDZCore in Frameworks */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
"""
    asc_res = f"""\t\t{ph_res} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\tFB367C572F510E6100FBAD05 /* Preview Assets.xcassets in Resources */,
\t\t\t\tFB367C542F510E6100FBAD05 /* Assets.xcassets in Resources */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
"""

    text = text.replace("/* End PBXFrameworksBuildPhase section */", asc_fw + "\n/* End PBXFrameworksBuildPhase section */")
    text = text.replace("/* End PBXSourcesBuildPhase section */", asc_sources + "\n/* End PBXSourcesBuildPhase section */")
    text = text.replace("/* End PBXResourcesBuildPhase section */", asc_res + "\n/* End PBXResourcesBuildPhase section */")

    native = f"""\t\t{target_id} /* AlaskaSkydiveCenter */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {cfg_list} /* Build configuration list for PBXNativeTarget "AlaskaSkydiveCenter" */;
\t\t\tbuildPhases = (
\t\t\t\t{ph_src} /* Sources */,
\t\t\t\t{ph_fw} /* Frameworks */,
\t\t\t\t{ph_res} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = AlaskaSkydiveCenter;
\t\t\tpackageProductDependencies = (
\t\t\t\tFB063FAB2F60000100022763 /* MalfunctionDZCore */,
\t\t\t);
\t\t\tproductName = AlaskaSkydiveCenter;
\t\t\tproductReference = {fr_prod_asc} /* AlaskaSkydiveCenter.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
"""
    text = text.replace("/* End PBXNativeTarget section */", native + "\n/* End PBXNativeTarget section */")

    text = text.replace(
        "\t\t\ttargets = (\n\t\t\t\tFB367C4B2F510E6000FBAD05 /* MalfunctionDZ */,\n\t\t\t);",
        "\t\t\ttargets = (\n\t\t\t\tFB367C4B2F510E6000FBAD05 /* MalfunctionDZ */,\n\t\t\t\t"
        + target_id
        + " /* AlaskaSkydiveCenter */,\n\t\t\t);",
    )

    text = text.replace(
        "TargetAttributes = {\n\t\t\t\t\tFB367C4B2F510E6000FBAD05 = {",
        "TargetAttributes = {\n\t\t\t\t\t"
        + target_id
        + " = {\n\t\t\t\t\t\tCreatedOnToolsVersion = 15.4;\n\t\t\t\t\t};\n\t\t\t\t\tFB367C4B2F510E6000FBAD05 = {",
    )

    dbg = f"""\t\t{cfg_dbg} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = "AppIcon-ASC";
\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = MalfunctionDZ/ASC.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 30;
\t\t\t\tDEVELOPMENT_ASSET_PATHS = "\\"MalfunctionDZ/Preview Content\\"";
\t\t\t\tDEVELOPMENT_TEAM = 8D9BFVLLPF;
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_FILE = MalfunctionDZ/Info.plist;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = "ASC";
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
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.malfunctiondz.app.AlaskaSkydiveCenter;
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
\t\t\t\tCODE_SIGN_ENTITLEMENTS = MalfunctionDZ/ASC.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 30;
\t\t\t\tDEVELOPMENT_ASSET_PATHS = "\\"MalfunctionDZ/Preview Content\\"";
\t\t\t\tDEVELOPMENT_TEAM = 8D9BFVLLPF;
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_FILE = MalfunctionDZ/Info.plist;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = "ASC";
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
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.malfunctiondz.app.AlaskaSkydiveCenter;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Release;
\t\t}};
"""
    lst = f"""\t\t{cfg_list} /* Build configuration list for PBXNativeTarget "AlaskaSkydiveCenter" */ = {{
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
    print("Patched:", PBX, "— added AlaskaSkydiveCenter target.")


if __name__ == "__main__":
    main()
