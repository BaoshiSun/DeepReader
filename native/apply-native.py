"""Apply the small native feature patch to the pinned upstream source archive."""
from pathlib import Path
import shutil
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from public_release import VERSION
SOURCE = ROOT / 'build/native/sumatrapdf-3.6.1rel'
ARCHIVE = ROOT / 'build/native/sumatrapdf-3.6.1rel.zip'
changes = {}

def edit(name, old, new, count=1):
    if name not in changes:
        with zipfile.ZipFile(ARCHIVE) as z:
            changes[name] = z.read('sumatrapdf-3.6.1rel/' + name).decode('utf-8').replace('\r\n', '\n')
    value = changes[name]
    if value.count(old) < count:
        raise RuntimeError('Upstream source does not match: ' + name + ': ' + old)
    changes[name] = value.replace(old, new, count)

edit('src/SumatraPDF.cpp', '#include "Selection.h"', '#include "Selection.h"\n#include "DeepSeekPanel.h"')
edit('src/SumatraPDF.cpp', '    gWindows.Append(win);', '    gWindows.Append(win);\n    DeepSeekInitialize(win);')
edit('src/SumatraPDF.cpp', '    dh.MoveWindow(win->hwndCanvas, rc);', '    DeepSeekLayout(win, rc);\n    dh.MoveWindow(win->hwndCanvas, rc);')
edit('src/SumatraPDF.cpp', '        // make the black/white canvas cover the entire window',
     '        DeepSeekLayout(win, rc);\n        // make the black/white canvas cover the entire window')
edit('src/SumatraPDF.cpp', '        case CmdCopySelection:\n',
     '        case CmdDeepSeekExplain: DeepSeekExplain(win); break;\n'
     '        case CmdDeepSeekPanel: DeepSeekToggle(win); break;\n\n        case CmdCopySelection:\n')
edit('src/SumatraPDF.cpp', 'void DeleteMainWindow(MainWindow* win) {',
     'void DeleteMainWindow(MainWindow* win) {\n    DeepSeekDestroy(win);')
edit('src/SumatraPDF.cpp', '    MainWindow* win = tab->win;\n    if (gGlobalPrefs->lazyLoading',
     '    MainWindow* win = tab->win;\n    DeepSeekReset(win);\n    if (gGlobalPrefs->lazyLoading')
edit('src/SumatraPDF.cpp', '    ClearTocBox(win);\n    AbortFinding(win, true);',
     '    DeepSeekReset(win);\n    ClearTocBox(win);\n    AbortFinding(win, true);')
edit('src/SumatraPDF.cpp', '    WindowTab* tab = win->CurrentTab();\n    ReportIf(!tab);',
     '    DeepSeekReset(win);\n    WindowTab* tab = win->CurrentTab();\n    ReportIf(!tab);')
edit('src/SumatraPDF.cpp', 'kSumatraWindowTitle = "SumatraPDF"', 'kSumatraWindowTitle = "DeepReader"')
edit('src/SumatraPDF.cpp', 'kSumatraWindowTitleW = L"SumatraPDF"', 'kSumatraWindowTitleW = L"DeepReader"')
edit('src/Version.h', '#define kAppName        "SumatraPDF"', '#define kAppName        "DeepReader"')
edit('src/Version.h', '#define kPublisherStr      "Krzysztof Kowalczyk"', '#define kPublisherStr      "DeepReader contributors"')
edit('src/Version.h', '#define kCopyrightStr      "Copyright 2006-2025 all authors (GPLv3)"',
     '#define kCopyrightStr      "SumatraPDF: Copyright 2006-2025 all authors (GPLv3); DeepReader changes: Copyright 2026 DeepReader contributors (AGPLv3+)"')
# Keep upstream engine/version macros for compatibility; brand the delivered file and About page.
edit('src/SumatraPDF.rc', ' FILEVERSION VER_RESOURCE', ' FILEVERSION ' + VERSION.replace('.', ',') + ',0')
edit('src/SumatraPDF.rc', ' PRODUCTVERSION VER_RESOURCE', ' PRODUCTVERSION ' + VERSION.replace('.', ',') + ',0')
edit('src/SumatraPDF.rc', '..\\\\gfx\\\\SumatraPDF-smaller.ico', '..\\\\gfx\\\\DeepReader.ico')
for field in ['FileVersion', 'ProductVersion']:
    edit('src/SumatraPDF.rc', f'VALUE "{field}", VER_RESOURCE_STR', f'VALUE "{field}", "{VERSION}"')
edit('src/HomePage.cpp', 'char* s = str::DupTemp("v" CURR_VERSION_STRA);', f'char* s = str::DupTemp("v{VERSION}");')
edit('src/HomePage.cpp', 'TempWStr title = ToWStrTemp(_TRA("About SumatraPDF"));',
     'const WCHAR* title = str::Eq(trans::GetCurrentLangCode(), "cn") ? L"关于 DeepReader" : L"About DeepReader";')
edit('src/HomePage.cpp', 'static AboutLayoutInfoEl gAboutLayoutInfo[] = {',
     'static AboutLayoutInfoEl gAboutLayoutInfo[] = {\n'
     '    {"DeepReader", "Independent SumatraPDF 3.6.1 fork", nullptr},\n'
     '    {"modified", "2026-10-06: resizable and floating AI sidebar", nullptr},\n'
     '    {"copyright", "2006-2025 SumatraPDF authors", nullptr},\n'
     '    {"changes", "2026 DeepReader contributors", nullptr},\n'
     '    {"terms", "Redistribution permitted; NO WARRANTY", nullptr},\n'
     '    {"GNU GPLv3", "View upstream license", "https://www.gnu.org/licenses/gpl-3.0.html"},\n'
     '    {"GNU AGPLv3+", "View license for DeepReader changes", "https://www.gnu.org/licenses/agpl-3.0.html"},\n'
     '    {"source", "Included: source/ (see source/README.md)", nullptr},\n'
     '    {"notices", "Included: THIRD-PARTY-NOTICES.txt", nullptr},')
edit('src/SumatraStartup.cpp', '#include "utils/BaseUtil.h"', '#include "utils/BaseUtil.h"\n#include "DeepSeekPanel.h"')
edit('src/SumatraStartup.cpp', '        if (MaybeTranslateAccelerator(msg)) continue;',
     '        if (DeepSeekPreTranslate(msg)) continue;\n        if (MaybeTranslateAccelerator(msg)) continue;')
edit('src/Commands.h', '    CmdNone = 390,', '    CmdNone = 390,\n    CmdDeepSeekExplain = 391, CmdDeepSeekPanel = 392,')
edit('src/Commands.cpp', '    "CmdNone\\0" "\\0";', '    "CmdNone\\0" "CmdDeepSeekExplain\\0" "CmdDeepSeekPanel\\0" "\\0";')
edit('src/Commands.cpp', '    CmdNone,\n};', '    CmdNone, CmdDeepSeekExplain, CmdDeepSeekPanel,\n};')
edit('src/Commands.cpp', '    "Do nothing\\0" "\\0";', '    "Do nothing\\0" "AI explain selection\\0" "AI reading sidebar\\0" "\\0";')
edit('src/Accelerators.cpp', "    {FCONTROL | FVIRTKEY, 'C', CmdCopySelection},",
     "    {FCONTROL | FALT | FVIRTKEY, 'D', CmdDeepSeekExplain},\n    {FCONTROL | FVIRTKEY, 'C', CmdCopySelection},")
edit('src/Menu.cpp', 'static MenuDef menuDefView[] = {',
     'static MenuDef menuDefView[] = {\n    { "DeepSeek 侧栏", CmdDeepSeekPanel },')
for marker in ['static MenuDef menuDefSelection[] = {', 'static MenuDef menuDefMainSelection[] = {']:
    edit('src/Menu.cpp', marker, marker + '\n    { "DeepSeek 简释", CmdDeepSeekExplain },')
edit('src/Menu.cpp', '        case CmdCopySelection:', '        case CmdDeepSeekExplain:\n        case CmdCopySelection:')
edit('src/Menu.cpp', 'UINT_PTR disableIfNoSelection[] = {', 'UINT_PTR disableIfNoSelection[] = {\n    CmdDeepSeekExplain,')
edit('src/Menu.cpp', '            title = trans::GetTranslation(md.title);\n        }',
     '            title = trans::GetTranslation(md.title);\n        }\n'
     '        bool aiEnglish = !str::Eq(trans::GetCurrentLangCode(), "cn");\n'
     '        if (cmdId == CmdDeepSeekExplain) title = aiEnglish ? "AI explain selection" : "AI 解释选文";\n'
     '        if (cmdId == CmdDeepSeekPanel) title = aiEnglish ? "AI reading sidebar" : "AI 阅读侧栏";\n'
     '        if (cmdId == CmdHelpAbout) title = aiEnglish ? "About DeepReader" : "关于 DeepReader";')
edit('premake5.files.lua', 'function sumatrapdf_files()',
     'function sumatrapdf_files()\n  files { "src/DeepSeekCore.cpp", "src/DeepSeekCore.h", "src/DeepSeekPanel.cpp", "src/DeepSeekPanel.h", "src/ReadingLibrary.cpp", "src/ReadingLibrary.h", "src/ReaderHighlights.cpp", "src/ReaderHighlights.h" }')
# Apply UTF-8 consistently, including third-party comments on Chinese Windows.
edit('premake5.lua', '  staticruntime  "On"', '  buildoptions { "/utf-8" }\n  staticruntime  "On"')
edit('premake5.lua', '"version", "windowscodecs", "wininet",', '"winhttp", "version", "windowscodecs", "wininet",')
# UnRAR's field-of-use restriction is not GPL-compatible. Keep the LGPL
# unarr decoder, but remove the optional UnRAR fallback from this build.
edit('src/utils/Archive.cpp', '#include "../../ext/unrar/dll.hpp"',
     '// DeepReader does not compile or link the non-free UnRAR fallback.')
archive_source = changes['src/utils/Archive.cpp']
unrar_start = archive_source.index('struct Data {')
edit('src/utils/Archive.cpp', archive_source[unrar_start:],
     'ByteSlice MultiFormatArchive::GetFileDataByIdUnarrDll(size_t) {\n    return {};\n}\n\n'
     'bool MultiFormatArchive::OpenUnrarFallback(const char*) {\n    return false;\n}\n')
edit('premake5.lua', '"unrar", ', '', changes['premake5.lua'].count('"unrar", '))
for name, value in changes.items():
    target = SOURCE / name
    marker = '--' if name.endswith('.lua') else '//'
    value = f'{marker} Modified for DeepReader {VERSION} on 2026-10-06; see source/docs/MODIFICATIONS.md.\n' + value
    data = value.encode('utf-8')
    if not target.exists() or target.read_bytes() != data:
        target.write_bytes(data)
for name in ['DeepSeekCore.cpp', 'DeepSeekCore.h', 'DeepSeekPanel.cpp', 'DeepSeekPanel.h', 'ReadingLibrary.cpp', 'ReadingLibrary.h', 'ReaderHighlights.cpp', 'ReaderHighlights.h']:
    src, target = ROOT / 'native' / name, SOURCE / 'src' / name
    if not target.exists() or target.read_bytes() != src.read_bytes():
        shutil.copy2(src, target)
src, target = ROOT / 'assets/DeepReader.ico', SOURCE / 'gfx/DeepReader.ico'
if not target.exists() or target.read_bytes() != src.read_bytes():
    shutil.copy2(src, target)
print('Native feature applied to', len(changes), 'upstream files')
