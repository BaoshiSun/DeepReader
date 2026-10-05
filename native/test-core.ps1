param([string]$ProbeConfig)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$tc = Join-Path $root 'build\native\toolchain'
$vc = Join-Path $tc 'vs\VC\Tools\MSVC\14.44.35207'
$sdk = Join-Path $tc 'sdk\c'
$inc = Join-Path $sdk 'Include\10.0.26100.0'
$source = Join-Path $root 'build\native\sumatrapdf-3.6.1rel'
$out = Join-Path $root 'artifacts\native-tests'
New-Item -ItemType Directory -Path $out -Force | Out-Null
$env:INCLUDE = "$vc\include;$inc\ucrt;$inc\shared;$inc\um;$inc\winrt"
$env:LIB = "$vc\lib\x64;$sdk\ucrt\x64;$sdk\um\x64"
Push-Location $out
try {
    & "$vc\bin\Hostx64\x64\cl.exe" /nologo /MT /std:c++20 /utf-8 /EHsc /DNDEBUG /DWIN32 /D_UNICODE /DUNICODE "/I$source\src" "/I$PSScriptRoot" "$PSScriptRoot\NativeCoreTests.cpp" "$PSScriptRoot\DeepSeekCore.cpp" "$PSScriptRoot\ReadingLibrary.cpp" "$source\out\rel64\utils.lib" /Fe:NativeCoreTests.exe /link kernel32.lib user32.lib gdi32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib comdlg32.lib gdiplus.lib comctl32.lib shlwapi.lib Version.lib wininet.lib shcore.lib wintrust.lib crypt32.lib
    if ($LASTEXITCODE) { throw 'Native core test compile failed' }
    if ($ProbeConfig) { & .\NativeCoreTests.exe (Join-Path $out 'synthetic-key.json') $ProbeConfig }
    else { & .\NativeCoreTests.exe (Join-Path $out 'synthetic-key.json') }
    if ($LASTEXITCODE) { throw 'Native core regression failed' }
} finally { Pop-Location }
