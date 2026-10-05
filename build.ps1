param([switch]$SkipDependencies)
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
$python = (Get-Command python -ErrorAction Stop).Source
if (-not $SkipDependencies) {
    & $python bootstrap-build.py
    if ($LASTEXITCODE -ne 0) { throw 'Build runtime download failed.' }
}
$env:PYTHONPATH = Join-Path $PSScriptRoot 'build\packages'
& $python -m unittest discover -s tests -v
if ($LASTEXITCODE -ne 0) { throw 'Context tests failed.' }
$bundle = Join-Path $PSScriptRoot 'dist\SumatraDeepSeek'
New-Item -ItemType Directory -Path $bundle -Force | Out-Null
# One-folder packaging avoids unpacking the PDF runtime on every shortcut press.
$env:PYINSTALLER_CONFIG_DIR = Join-Path $PSScriptRoot 'build\pyinstaller-cache'
& $python -m PyInstaller --noconfirm --clean --onedir --console --name ContextWorker --copy-metadata pymupdf --exclude-module PIL --exclude-module numpy --exclude-module pandas --exclude-module matplotlib --exclude-module tkinter --exclude-module scipy --exclude-module cv2 --exclude-module pytesseract --distpath (Join-Path $bundle 'context-worker-build') --workpath build\worker --specpath build src\context_worker.py
if ($LASTEXITCODE -ne 0) { throw 'Worker build failed.' }
$builtWorker = Join-Path $bundle 'context-worker-build\ContextWorker'
$finalWorker = Join-Path $bundle 'context-worker'
if (Test-Path -LiteralPath $finalWorker) {
    # Validate before a recursive delete; use only PowerShell for filesystem operations.
    $resolved = [IO.Path]::GetFullPath($finalWorker)
    $allowed = [IO.Path]::GetFullPath($bundle) + [IO.Path]::DirectorySeparatorChar
    if (-not $resolved.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe build path.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
Move-Item -LiteralPath $builtWorker -Destination $finalWorker
Remove-Item -LiteralPath (Join-Path $bundle 'context-worker-build')
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $csc)) { throw 'Windows .NET Framework compiler not found.' }
$source = Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'src') -Filter '*.cs' | ForEach-Object { $_.FullName }
& $csc /nologo /target:winexe /platform:x64 /optimize+ /utf8output "/out:$bundle\DeepSeekReader.exe" /reference:System.Windows.Forms.dll /reference:System.Drawing.dll /reference:System.Net.Http.dll /reference:System.Web.Extensions.dll /reference:System.Security.dll $source
if ($LASTEXITCODE -ne 0) { throw 'Reader build failed.' }
Copy-Item -LiteralPath 'DeepSeekReader.exe.config' -Destination $bundle
Copy-Item -LiteralPath 'docs\legacy-helper.md' -Destination (Join-Path $bundle '使用说明.md')
Copy-Item -LiteralPath 'LICENSE' -Destination $bundle
Copy-Item -LiteralPath 'LICENSE-AGPL-3.0.txt' -Destination $bundle
Copy-Item -LiteralPath 'THIRD-PARTY-NOTICES.md' -Destination $bundle
$pythonLicense = Join-Path (Split-Path -Parent $python) 'LICENSE.txt'
if (Test-Path -LiteralPath $pythonLicense) { Copy-Item -LiteralPath $pythonLicense -Destination (Join-Path $bundle 'PYTHON-LICENSE.txt') }
New-Item -ItemType Directory -Path artifacts -Force | Out-Null
& $python tests\make_smoke_pdf.py
if ($LASTEXITCODE -ne 0) { throw 'Fixture creation failed.' }
$fixture = Join-Path $PSScriptRoot 'artifacts\语境 smoke.pdf'
$test = Start-Process -FilePath (Join-Path $bundle 'DeepSeekReader.exe') -ArgumentList @('--self-test',('"' + $fixture + '"')) -WindowStyle Hidden -Wait -PassThru
Get-Content -LiteralPath (Join-Path $bundle 'self-test-result.txt')
if ($test.ExitCode -ne 0) { throw 'Reader self tests failed.' }
Remove-Item -LiteralPath (Join-Path $bundle 'self-test-result.txt')
$env:CONTEXT_WORKER_EXE = Join-Path $finalWorker 'ContextWorker.exe'
& $python -m unittest discover -s tests -p test_packaged.py -v
if ($LASTEXITCODE -ne 0) { throw 'Packaged worker tests failed.' }
$sourceBundle = Join-Path $bundle 'source'
New-Item -ItemType Directory -Path $sourceBundle -Force | Out-Null
# Reuse the audited manifest so new test/build dependencies remain reconstructible.
$publicNames = & $python -c "import sys; sys.path.insert(0, 'tools'); from public_release import source_files; print('\n'.join(name for name, data in source_files()))"
if ($LASTEXITCODE -ne 0) { throw 'Public source audit failed.' }
foreach ($name in $publicNames) {
    $destination = Join-Path $sourceBundle $name
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $destination -Force
}
Write-Output "Built: $bundle\DeepSeekReader.exe"
