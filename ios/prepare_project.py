#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Generate the independent iOS Xcode project and icon. No account mutations or uploads."""
from pathlib import Path
import json
import plistlib
import subprocess
ROOT = Path(__file__).resolve().parent

def main():
    assets = ROOT / '.build/Assets.xcassets/AppIcon.appiconset'
    assets.mkdir(parents=True, exist_ok=True)
    subprocess.run(['sips', '-s', 'format', 'png', '-z', '1024', '1024', str(ROOT.parent / 'assets/DeepReader-green.png'), '--out', str(assets / 'AppIcon.png')], check=True, stdout=subprocess.DEVNULL)
    subprocess.run(['swift', str(ROOT / 'prepare_icon.swift'), str(assets / 'AppIcon.png')], check=True)
    (assets / 'Contents.json').write_text(json.dumps({'images': [{'filename': 'AppIcon.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'}], 'info': {'author': 'xcode', 'version': 1}}))
    (assets.parent / 'Contents.json').write_text('{"info":{"author":"xcode","version":1}}')
    info = dict(CFBundleDisplayName='DeepReader', CFBundleExecutable='$(EXECUTABLE_NAME)', CFBundleIdentifier='$(PRODUCT_BUNDLE_IDENTIFIER)', CFBundleName='DeepReader', CFBundlePackageType='APPL', CFBundleShortVersionString='1.0.0', CFBundleVersion='1', LSRequiresIPhoneOS=True, LSSupportsOpeningDocumentsInPlace=False, DeepReaderAppStoreBuild=True, ITSAppUsesNonExemptEncryption=False, UILaunchScreen={}, UISupportedInterfaceOrientations=['UIInterfaceOrientationPortrait','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'], **{'UISupportedInterfaceOrientations~ipad':['UIInterfaceOrientationPortrait','UIInterfaceOrientationPortraitUpsideDown','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight']})
    info['CFBundleDocumentTypes'] = [dict(CFBundleTypeName='Reading documents', LSHandlerRank='Alternate', CFBundleTypeRole='Viewer', LSItemContentTypes=['com.adobe.pdf','org.idpf.epub-container','public.plain-text','net.daringfireball.markdown'])]
    with (ROOT / 'Info.plist').open('wb') as f: plistlib.dump(info, f)
    def uid(n): return f'{n:024X}'
    objects = []
    def obj(n, body): objects.append(f'{uid(n)} = {{ {body} }};')
    def arr(values): return '(' + ', '.join(uid(v) for v in values) + ')'
    app_sources = [str(p.relative_to(ROOT)) for p in sorted((ROOT / 'Sources').glob('*.swift'))] + [f'../macos/Sources/DeepReaderCore/{name}.swift' for name in ['Models','Credentials','AIClient']]
    resources = ['.build/Assets.xcassets', 'Resources/Reading-Garden.txt', 'Resources/ZIPFoundation-LICENSE.txt', '../LICENSE-AGPL-3.0.txt', '../THIRD-PARTY-NOTICES.md', '../macos/AppStore/PrivacyInfo.xcprivacy']
    references, sources, res = [], [], []
    for i, path in enumerate(app_sources + resources):
        n = 100 + i; references.append(n)
        kind = 'sourcecode.swift' if path.endswith('.swift') else ('folder.assetcatalog' if path.endswith('xcassets') else 'text')
        obj(n, f'isa = PBXFileReference; lastKnownFileType = {kind}; path = "{path}"; sourceTree = "<group>";')
        obj(n+100, f'isa = PBXBuildFile; fileRef = {uid(n)};')
        (sources if path.endswith('.swift') else res).append(n+100)
    obj(1, f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 2630; }}; buildConfigurationList = {uid(10)}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; knownRegions = (en, "zh-Hans", Base); mainGroup = {uid(2)}; productRefGroup = {uid(3)}; projectDirPath = ""; projectRoot = ""; packageReferences = {arr([30])}; targets = {arr([4,40])};')
    obj(2, f'isa = PBXGroup; children = {arr(references+[50,3])}; sourceTree = "<group>";')
    obj(3, f'isa = PBXGroup; children = {arr([6,46])}; name = Products; sourceTree = "<group>";')
    obj(4, f'isa = PBXNativeTarget; buildConfigurationList = {uid(11)}; buildPhases = {arr([7,8,9])}; buildRules = (); dependencies = (); name = DeepReaderiOS; packageProductDependencies = {arr([31])}; productName = DeepReader; productReference = {uid(6)}; productType = "com.apple.product-type.application";')
    obj(6, 'isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = DeepReader.app; sourceTree = BUILT_PRODUCTS_DIR;')
    for n, kind, files in [(7,'Sources',sources),(8,'Frameworks',[32]),(9,'Resources',res),(47,'Sources',[51]),(48,'Frameworks',[])]:
        obj(n, f'isa = PBX{kind}BuildPhase; buildActionMask = 2147483647; files = {arr(files)}; runOnlyForDeploymentPostprocessing = 0;')
    for n, configs in [(10,[12,13]),(11,[14,15]),(41,[42,43])]:
        obj(n, f'isa = XCConfigurationList; buildConfigurations = {arr(configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
    common = 'CLANG_ENABLE_MODULES = YES; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SDKROOT = iphoneos; SWIFT_VERSION = 5.0; TARGETED_DEVICE_FAMILY = "1,2"; ENABLE_USER_SCRIPT_SANDBOXING = YES;'
    for n, name in [(12,'Debug'),(13,'Release')]:
        flags = 'SWIFT_OPTIMIZATION_LEVEL = "-Onone"; ENABLE_TESTABILITY = YES; ONLY_ACTIVE_ARCH = YES;' if name == 'Debug' else 'SWIFT_OPTIMIZATION_LEVEL = "-O"; SWIFT_COMPILATION_MODE = wholemodule;'
        obj(n, f'isa = XCBuildConfiguration; buildSettings = {{ {common} {flags} }}; name = {name};')
    app = 'DEVELOPMENT_TEAM = YA66T3UWKU; CODE_SIGN_STYLE = Automatic; GENERATE_INFOPLIST_FILE = NO; INFOPLIST_FILE = Info.plist; PRODUCT_BUNDLE_IDENTIFIER = org.deepreader.ios; PRODUCT_NAME = DeepReader; PRODUCT_MODULE_NAME = DeepReaderMobile; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"; SUPPORTS_MACCATALYST = NO; ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon; LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks";'
    for n, name in [(14,'Debug'),(15,'Release')]:
        platform_app = app.replace('org.deepreader.ios;', 'org.deepreader.macos;') if name == 'Release' else app
        obj(n, f'isa = XCBuildConfiguration; buildSettings = {{ {platform_app} }}; name = {name};')
    obj(30, 'isa = XCRemoteSwiftPackageReference; repositoryURL = "https://github.com/weichsel/ZIPFoundation.git"; requirement = { kind = exactVersion; version = 0.9.20; };')
    obj(31, f'isa = XCSwiftPackageProductDependency; package = {uid(30)}; productName = ZIPFoundation;')
    obj(32, f'isa = PBXBuildFile; productRef = {uid(31)};')
    obj(40, f'isa = PBXNativeTarget; buildConfigurationList = {uid(41)}; buildPhases = {arr([47,48])}; buildRules = (); dependencies = {arr([44])}; name = DeepReaderMobileTests; productName = DeepReaderMobileTests; productReference = {uid(46)}; productType = "com.apple.product-type.bundle.unit-test";')
    obj(44, f'isa = PBXTargetDependency; target = {uid(4)}; targetProxy = {uid(45)};')
    obj(45, f'isa = PBXContainerItemProxy; containerPortal = {uid(1)}; proxyType = 1; remoteGlobalIDString = {uid(4)}; remoteInfo = DeepReaderiOS;')
    obj(46, 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = DeepReaderMobileTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
    obj(50, 'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Tests/MobileTests.swift; sourceTree = "<group>";')
    obj(51, f'isa = PBXBuildFile; fileRef = {uid(50)};')
    for n, name in [(42,'Debug'),(43,'Release')]: obj(n, f'isa = XCBuildConfiguration; buildSettings = {{ CODE_SIGN_STYLE = Automatic; GENERATE_INFOPLIST_FILE = YES; PRODUCT_BUNDLE_IDENTIFIER = org.deepreader.ios.tests; PRODUCT_NAME = DeepReaderMobileTests; TEST_HOST = "$(BUILT_PRODUCTS_DIR)/DeepReader.app/DeepReader"; BUNDLE_LOADER = "$(TEST_HOST)"; }}; name = {name};')
    project = ROOT / 'DeepReader.xcodeproj'; project.mkdir(exist_ok=True)
    (project / 'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(objects)+f'\n}}; rootObject = {uid(1)}; }}\n')
    scheme = project / 'xcshareddata/xcschemes/DeepReaderiOS.xcscheme'; scheme.parent.mkdir(parents=True, exist_ok=True)
    ref = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid(4)}" BuildableName="DeepReader.app" BlueprintName="DeepReaderiOS" ReferencedContainer="container:DeepReader.xcodeproj"/>'
    testref = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid(40)}" BuildableName="DeepReaderMobileTests.xctest" BlueprintName="DeepReaderMobileTests" ReferencedContainer="container:DeepReader.xcodeproj"/>'
    scheme.write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2630" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref}</BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{testref}</TestableReference></Testables></TestAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
    print('Prepared iOS project. Signing and upload were not performed.')
if __name__ == '__main__': main()
