param([string]$SumatraPath = (Join-Path $env:LOCALAPPDATA 'SumatraPDF\SumatraPDF.exe'))
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot
$previousPythonPath = $env:PYTHONPATH
try {
    if (-not (Test-Path -LiteralPath $SumatraPath)) { throw 'Pass -SumatraPath with the installed SumatraPDF executable.' }
    New-Item -ItemType Directory -Path artifacts -Force | Out-Null
    $env:PYTHONPATH = Join-Path $projectRoot 'build\packages'
    python tests\make_smoke_pdf.py
    if ($LASTEXITCODE -ne 0) { throw 'Build the project first to prepare the PDF dependencies.' }
    $framework = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319'
    $source = @(Get-ChildItem -LiteralPath src -Filter '*.cs' | ForEach-Object { $_.FullName })
    $source += (Join-Path $PSScriptRoot 'SelectionIntegration.cs')
    & (Join-Path $framework 'csc.exe') /nologo /target:exe /platform:x64 /utf8output /main:SelectionIntegration /out:artifacts\SelectionIntegration.exe /reference:System.Windows.Forms.dll /reference:System.Drawing.dll /reference:System.Net.Http.dll /reference:System.Web.Extensions.dll /reference:System.Security.dll $source
    if ($LASTEXITCODE -ne 0) { throw 'Selection test compile failed.' }
    & .\artifacts\SelectionIntegration.exe $SumatraPath 'artifacts\语境 smoke.pdf'
    if ($LASTEXITCODE -ne 0) { throw 'Selection regression test failed.' }
} finally {
    $env:PYTHONPATH = $previousPythonPath
    Pop-Location
}
