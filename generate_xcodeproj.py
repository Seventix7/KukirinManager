#!/usr/bin/env python3
"""Generate KukirinManager.xcodeproj/project.pbxproj with correct file paths."""

import os
import uuid

ROOT = os.path.dirname(os.path.abspath(__file__))
PROJECT_NAME = "KukirinManager"
BUNDLE_ID = "com.kukirin.manager"


def uid():
    return uuid.uuid4().hex[:24].upper()


swift_files = []
for dirpath, _, filenames in os.walk(os.path.join(ROOT, PROJECT_NAME)):
    for f in filenames:
        if f.endswith(".swift"):
            rel = os.path.relpath(os.path.join(dirpath, f), os.path.join(ROOT, PROJECT_NAME)).replace("\\", "/")
            swift_files.append(rel)
swift_files.sort()

project_id = uid()
target_id = uid()
sources_phase_id = uid()
resources_phase_id = uid()
frameworks_phase_id = uid()
product_ref_id = uid()
main_group_id = uid()
products_group_id = uid()
app_group_id = uid()
project_config_list_id = uid()
target_config_list_id = uid()
debug_config_id = uid()
release_config_id = uid()
debug_project_config_id = uid()
release_project_config_id = uid()

file_refs = {sf: uid() for sf in swift_files}
build_files = {sf: uid() for sf in swift_files}

info_plist_ref = uid()
assets_ref = uid()
privacy_ref = uid()
assets_build = uid()
privacy_build = uid()

lines = []
lines.append("// !$*UTF8*$!")
lines.append("{")
lines.append("\tarchiveVersion = 1;")
lines.append("\tclasses = {};")
lines.append("\tobjectVersion = 56;")
lines.append("\tobjects = {")
lines.append("")
lines.append("/* Begin PBXBuildFile section */")
for sf in swift_files:
    base = os.path.basename(sf)
    lines.append(f"\t\t{build_files[sf]} /* {base} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_refs[sf]} /* {base} */; }};")
lines.append(f"\t\t{assets_build} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {assets_ref} /* Assets.xcassets */; }};")
lines.append(f"\t\t{privacy_build} /* PrivacyInfo.xcprivacy in Resources */ = {{isa = PBXBuildFile; fileRef = {privacy_ref} /* PrivacyInfo.xcprivacy */; }};")
lines.append("/* End PBXBuildFile section */")
lines.append("")
lines.append("/* Begin PBXFileReference section */")
lines.append(f"\t\t{product_ref_id} /* {PROJECT_NAME}.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {PROJECT_NAME}.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
for sf in swift_files:
    base = os.path.basename(sf)
    lines.append(f"\t\t{file_refs[sf]} /* {base} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {base}; sourceTree = \"<group>\"; }};")
lines.append(f"\t\t{info_plist_ref} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};")
lines.append(f"\t\t{assets_ref} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = \"<group>\"; }};")
lines.append(f"\t\t{privacy_ref} /* PrivacyInfo.xcprivacy */ = {{isa = PBXFileReference; lastKnownFileType = text.xml; path = PrivacyInfo.xcprivacy; sourceTree = \"<group>\"; }};")
lines.append("/* End PBXFileReference section */")
lines.append("")
lines.append("/* Begin PBXFrameworksBuildPhase section */")
lines.append(f"\t\t{frameworks_phase_id} /* Frameworks */ = {{")
lines.append("\t\t\tisa = PBXFrameworksBuildPhase;")
lines.append("\t\t\tbuildActionMask = 2147483647;")
lines.append("\t\t\tfiles = (")
lines.append("\t\t\t);")
lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
lines.append("\t\t};")
lines.append("/* End PBXFrameworksBuildPhase section */")
lines.append("")
lines.append("/* Begin PBXGroup section */")
lines.append(f"\t\t{main_group_id} = {{")
lines.append("\t\t\tisa = PBXGroup;")
lines.append("\t\t\tchildren = (")
lines.append(f"\t\t\t\t{app_group_id} /* {PROJECT_NAME} */,")
lines.append(f"\t\t\t\t{products_group_id} /* Products */,")
lines.append("\t\t\t);")
lines.append('\t\t\tsourceTree = "<group>";')
lines.append("\t\t};")
lines.append(f"\t\t{products_group_id} /* Products */ = {{")
lines.append("\t\t\tisa = PBXGroup;")
lines.append("\t\t\tchildren = (")
lines.append(f"\t\t\t\t{product_ref_id} /* {PROJECT_NAME}.app */,")
lines.append("\t\t\t);")
lines.append("\t\t\tname = Products;")
lines.append('\t\t\tsourceTree = "<group>";')
lines.append("\t\t};")

# Build nested groups from swift file paths
def ensure_groups():
    groups = {}
    root_children = []

    def get_group(path_parts):
        if not path_parts:
            return app_group_id, root_children
        key = "/".join(path_parts)
        if key in groups:
            return groups[key], groups[f"{key}__children"]
        parent_key = "/".join(path_parts[:-1])
        gid = uid()
        groups[key] = gid
        children = []
        groups[f"{key}__children"] = children
        if parent_key:
            _, parent_children = get_group(path_parts[:-1])
            parent_children.append(gid)
        else:
            root_children.append(gid)
        return gid, children

    for sf in swift_files:
        parts = sf.split("/")
        if len(parts) == 1:
            root_children.append(file_refs[sf])
        else:
            _, children = get_group(parts[:-1])
            children.append(file_refs[sf])

    resources_group_id = uid()
    root_children.append(resources_group_id)

    group_defs = []
    group_defs.append(f"\t\t{app_group_id} /* {PROJECT_NAME} */ = {{")
    group_defs.append("\t\t\tisa = PBXGroup;")
    group_defs.append("\t\t\tchildren = (")
    for c in root_children:
        group_defs.append(f"\t\t\t\t{c},")
    group_defs.append("\t\t\t);")
    group_defs.append(f"\t\t\tpath = {PROJECT_NAME};")
    group_defs.append('\t\t\tsourceTree = "<group>";')
    group_defs.append("\t\t};")

    for key, gid in groups.items():
        if key.endswith("__children"):
            continue
        children = groups[f"{key}__children"]
        name = key.split("/")[-1]
        group_defs.append(f"\t\t{gid} /* {name} */ = {{")
        group_defs.append("\t\t\tisa = PBXGroup;")
        group_defs.append("\t\t\tchildren = (")
        for c in children:
            group_defs.append(f"\t\t\t\t{c},")
        group_defs.append("\t\t\t);")
        group_defs.append(f"\t\t\tpath = {name};")
        group_defs.append('\t\t\tsourceTree = "<group>";')
        group_defs.append("\t\t};")

    group_defs.append(f"\t\t{resources_group_id} /* Resources */ = {{")
    group_defs.append("\t\t\tisa = PBXGroup;")
    group_defs.append("\t\t\tchildren = (")
    group_defs.append(f"\t\t\t\t{info_plist_ref} /* Info.plist */,")
    group_defs.append(f"\t\t\t\t{assets_ref} /* Assets.xcassets */,")
    group_defs.append(f"\t\t\t\t{privacy_ref} /* PrivacyInfo.xcprivacy */,")
    group_defs.append("\t\t\t);")
    group_defs.append("\t\t\tpath = Resources;")
    group_defs.append('\t\t\tsourceTree = "<group>";')
    group_defs.append("\t\t};")
    return group_defs

lines.extend(ensure_groups())
lines.append("/* End PBXGroup section */")
lines.append("")
lines.append("/* Begin PBXNativeTarget section */")
lines.append(f"\t\t{target_id} /* {PROJECT_NAME} */ = {{")
lines.append("\t\t\tisa = PBXNativeTarget;")
lines.append(f"\t\t\tbuildConfigurationList = {target_config_list_id};")
lines.append("\t\t\tbuildPhases = (")
lines.append(f"\t\t\t\t{sources_phase_id} /* Sources */,")
lines.append(f"\t\t\t\t{frameworks_phase_id} /* Frameworks */,")
lines.append(f"\t\t\t\t{resources_phase_id} /* Resources */,")
lines.append("\t\t\t);")
lines.append("\t\t\tbuildRules = ();")
lines.append("\t\t\tdependencies = ();")
lines.append(f"\t\t\tname = {PROJECT_NAME};")
lines.append(f"\t\t\tproductName = {PROJECT_NAME};")
lines.append(f"\t\t\tproductReference = {product_ref_id};")
lines.append('\t\t\tproductType = "com.apple.product-type.application";')
lines.append("\t\t};")
lines.append("/* End PBXNativeTarget section */")
lines.append("")
lines.append("/* Begin PBXProject section */")
lines.append(f"\t\t{project_id} /* Project object */ = {{")
lines.append("\t\t\tisa = PBXProject;")
lines.append("\t\t\tattributes = {")
lines.append("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
lines.append("\t\t\t\tLastSwiftUpdateCheck = 1500;")
lines.append("\t\t\t\tLastUpgradeCheck = 1500;")
lines.append("\t\t\t};")
lines.append(f"\t\t\tbuildConfigurationList = {project_config_list_id};")
lines.append('\t\t\tcompatibilityVersion = "Xcode 14.0";')
lines.append("\t\t\tdevelopmentRegion = en;")
lines.append("\t\t\thasScannedForEncodings = 0;")
lines.append("\t\t\tknownRegions = (en, Base);")
lines.append(f"\t\t\tmainGroup = {main_group_id};")
lines.append(f"\t\t\tproductRefGroup = {products_group_id};")
lines.append('\t\t\tprojectDirPath = "";')
lines.append('\t\t\tprojectRoot = "";')
lines.append(f"\t\t\ttargets = ({target_id});")
lines.append("\t\t};")
lines.append("/* End PBXProject section */")
lines.append("")
lines.append("/* Begin PBXResourcesBuildPhase section */")
lines.append(f"\t\t{resources_phase_id} /* Resources */ = {{")
lines.append("\t\t\tisa = PBXResourcesBuildPhase;")
lines.append("\t\t\tbuildActionMask = 2147483647;")
lines.append("\t\t\tfiles = (")
lines.append(f"\t\t\t\t{assets_build},")
lines.append(f"\t\t\t\t{privacy_build},")
lines.append("\t\t\t);")
lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
lines.append("\t\t};")
lines.append("/* End PBXResourcesBuildPhase section */")
lines.append("")
lines.append("/* Begin PBXSourcesBuildPhase section */")
lines.append(f"\t\t{sources_phase_id} /* Sources */ = {{")
lines.append("\t\t\tisa = PBXSourcesBuildPhase;")
lines.append("\t\t\tbuildActionMask = 2147483647;")
lines.append("\t\t\tfiles = (")
for sf in swift_files:
    lines.append(f"\t\t\t\t{build_files[sf]},")
lines.append("\t\t\t);")
lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
lines.append("\t\t};")
lines.append("/* End PBXSourcesBuildPhase section */")
lines.append("")
lines.append("/* Begin XCBuildConfiguration section */")
for cfg_id, name, is_target in [
    (debug_project_config_id, "Debug", False),
    (release_project_config_id, "Release", False),
    (debug_config_id, "Debug", True),
    (release_config_id, "Release", True),
]:
    lines.append(f"\t\t{cfg_id} /* {name} */ = {{")
    lines.append("\t\t\tisa = XCBuildConfiguration;")
    lines.append("\t\t\tbuildSettings = {")
    if is_target:
        lines.append('\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;')
        lines.append('\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;')
        lines.append('\t\t\t\tCODE_SIGN_STYLE = Automatic;')
        lines.append('\t\t\t\tCURRENT_PROJECT_VERSION = 1;')
        lines.append('\t\t\t\tDEVELOPMENT_TEAM = "";')
        lines.append('\t\t\t\tENABLE_PREVIEWS = YES;')
        lines.append('\t\t\t\tGENERATE_INFOPLIST_FILE = NO;')
        lines.append(f'\t\t\t\tINFOPLIST_FILE = {PROJECT_NAME}/Resources/Info.plist;')
        lines.append('\t\t\t\tLD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/Frameworks");')
        lines.append('\t\t\t\tMARKETING_VERSION = 1.0.0;')
        lines.append(f'\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID};')
        lines.append('\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";')
        lines.append('\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;')
        lines.append('\t\t\t\tSWIFT_VERSION = 5.0;')
        lines.append('\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";')
        if name == "Debug":
            lines.append('\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;')
    else:
        lines.append('\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;')
        lines.append('\t\t\t\tCLANG_ENABLE_MODULES = YES;')
        lines.append('\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;')
        lines.append('\t\t\t\tSDKROOT = iphoneos;')
        if name == "Debug":
            lines.append('\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;')
            lines.append('\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";')
        else:
            lines.append('\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;')
            lines.append('\t\t\t\tVALIDATE_PRODUCT = YES;')
    lines.append("\t\t\t};")
    lines.append(f"\t\t\tname = {name};")
    lines.append("\t\t};")
lines.append("/* End XCBuildConfiguration section */")
lines.append("")
lines.append("/* Begin XCConfigurationList section */")
lines.append(f"\t\t{project_config_list_id} = {{")
lines.append("\t\t\tisa = XCConfigurationList;")
lines.append(f"\t\t\tbuildConfigurations = ({debug_project_config_id}, {release_project_config_id});")
lines.append("\t\t\tdefaultConfigurationIsVisible = 0;")
lines.append("\t\t\tdefaultConfigurationName = Release;")
lines.append("\t\t};")
lines.append(f"\t\t{target_config_list_id} = {{")
lines.append("\t\t\tisa = XCConfigurationList;")
lines.append(f"\t\t\tbuildConfigurations = ({debug_config_id}, {release_config_id});")
lines.append("\t\t\tdefaultConfigurationIsVisible = 0;")
lines.append("\t\t\tdefaultConfigurationName = Release;")
lines.append("\t\t};")
lines.append("/* End XCConfigurationList section */")
lines.append("\t};")
lines.append(f"\trootObject = {project_id};")
lines.append("}")

out = os.path.join(ROOT, f"{PROJECT_NAME}.xcodeproj", "project.pbxproj")
with open(out, "w", encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n")
print(f"Generated {out} ({len(swift_files)} Swift files)")
