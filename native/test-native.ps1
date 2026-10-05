param([string]$SumatraPath, [string]$LiveConfig, [string]$Python = 'python')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (-not $SumatraPath) { $SumatraPath = Join-Path $root 'build\native\sumatrapdf-3.6.1rel\out\rel64\SumatraPDF.exe' }
Push-Location $root
try {
    New-Item -ItemType Directory -Path 'artifacts' -Force | Out-Null
    & $Python 'tests\make_smoke_pdf.py'
    if ($LASTEXITCODE) { throw 'Synthetic PDF generation failed; install requirements-build.txt' }
    $sources = @(Get-ChildItem src -Filter '*.cs' | ForEach-Object FullName)
    $sources += Join-Path $PSScriptRoot 'NativeIntegration.cs'
    & "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /nologo /target:exe /platform:x64 /utf8output /main:NativeIntegration /out:artifacts\NativeIntegration.exe /reference:System.Windows.Forms.dll /reference:System.Drawing.dll /reference:System.Net.Http.dll /reference:System.Web.Extensions.dll /reference:System.Security.dll $sources
    if ($LASTEXITCODE) { throw 'Native UI harness compile failed' }
    if ($LiveConfig) {
        & .\artifacts\NativeIntegration.exe $SumatraPath 'artifacts\语境 smoke.pdf' --live $LiveConfig
    } else { & .\artifacts\NativeIntegration.exe $SumatraPath 'artifacts\语境 smoke.pdf' }
    if ($LASTEXITCODE) { throw 'Native integration regression failed' }
    if (-not $LiveConfig) {
        & $Python 'tests\verify_native_annotations.py'
        if ($LASTEXITCODE) { throw 'Saved PDF annotation regression failed' }
    }
} finally { Pop-Location }
