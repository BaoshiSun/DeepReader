param([string]$Project = 'SumatraPDF', [switch]$Prepare, [switch]$SkipReferences, [string]$Python = 'python')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$nativeRoot = Join-Path $root 'build\native'
$source = Join-Path $nativeRoot 'sumatrapdf-3.6.1rel'
$tc = Join-Path $nativeRoot 'toolchain'
if ($Prepare) {
    & $Python (Join-Path $PSScriptRoot 'prepare-source.py')
    if ($LASTEXITCODE) { throw 'Source preparation failed' }
    & $Python (Join-Path $PSScriptRoot 'bootstrap-toolchain.py')
    if ($LASTEXITCODE) { throw 'Toolchain download failed' }
    & $Python (Join-Path $PSScriptRoot 'prepare-msbuild.py')
    if ($LASTEXITCODE) { throw 'MSBuild preparation failed' }
}
& $Python (Join-Path $PSScriptRoot 'apply-native.py')
if ($LASTEXITCODE) { throw 'Native source patch failed' }
$vc = Join-Path $tc 'vs\VC\Tools\MSVC\14.44.35207'
$sdk = Join-Path $tc 'sdk\c'
$inc = Join-Path $sdk 'Include\10.0.26100.0'
$compiler = Join-Path $vc 'bin\Hostx64\x64'
$sdkBin = Join-Path $sdk 'bin\10.0.26100.0\x64'
$env:PATH = "$compiler;$sdkBin;$env:PATH"
$properties = @{
    Configuration = 'Release'; Platform = 'x64'; PreferredToolArchitecture = 'x64'
    VCTargetsPath = (Join-Path $tc 'vs\MSBuild\Microsoft\VC\v170\')
    VCToolsInstallDir = "$vc\"; VCToolsVersion = '14.44.35207'
    VCInstallDir = (Join-Path $tc 'vs\VC\'); VSInstallDir = (Join-Path $tc 'vs\')
    WindowsSdkDir_10 = "$sdk\"; WindowsSdkDir = "$sdk\"
    UniversalCRTSdkDir_10 = "$sdk\"; UniversalCRTSdkDir = "$sdk\"
    WindowsTargetPlatformVersion = '10.0.26100.0'; UCRTVersion = '10.0.26100.0'
    WindowsSDKInstalled = 'true'; WindowsSDK_Desktop_Support = 'true'
    IncludePath = "$vc\include;$vc\atlmfc\include;$inc\ucrt;$inc\shared;$inc\um;$inc\winrt"
    LibraryPath = "$vc\lib\x64;$vc\atlmfc\lib\x64;$sdk\ucrt\x64;$sdk\um\x64"
    ExecutablePath = "$compiler;$sdkBin;$env:PATH"
    TrackFileAccess = 'false'; CL_MPCount = '4'; WholeProgramOptimization = 'false'
    TreatWarningAsError = 'false'; BuildProjectReferences = $(if ($SkipReferences) { 'false' } else { 'true' })
}
# Premake and NASM use ANSI paths. A temporary DOS drive maps only this source
# checkout, keeping their argv ASCII without moving files or changing the system.
$drive = @('R:', 'S:', 'T:', 'U:') | Where-Object { -not (Test-Path "$_\") } | Select-Object -First 1
if (-not $drive) { throw 'No free temporary build drive' }
& subst $drive $source
if ($LASTEXITCODE) { throw 'Unable to map the temporary source drive' }
try {
    Push-Location "$drive\"
    try {
        & .\bin\premake5.exe vs2022
        if ($LASTEXITCODE) { throw 'Premake generation failed' }
        $arguments = @("$drive\vs2022\$Project.vcxproj", '/nologo', '/m:3', '/v:minimal', '/nr:false')
        foreach ($entry in $properties.GetEnumerator()) {
            $value = $entry.Value.Replace(';', '%3B')
            $arguments += "/p:$($entry.Key)=$value"
        }
        & (Join-Path $tc 'msbuild-bin\MSBuild.exe') @arguments
        if ($LASTEXITCODE) { throw "Native build failed: $LASTEXITCODE" }
    } finally { Pop-Location }
} finally { & subst $drive /d }
