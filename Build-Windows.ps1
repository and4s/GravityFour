$ErrorActionPreference = 'Stop'
$projectPath = $PSScriptRoot
$releasePath = Join-Path $projectPath 'dist\v3.9'
$engine = Join-Path $projectPath 'tools\Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $engine)) { throw 'Missing Godot in tools. Download Godot 4.7.2 Windows x64 and extract it into tools.' }
New-Item -ItemType Directory -Force -Path $releasePath | Out-Null
& $engine --headless --path $projectPath --editor --import
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed' }
& $engine --headless --path $projectPath --export-release 'Windows Desktop' (Join-Path $releasePath 'GravityFour.exe')
if ($LASTEXITCODE -ne 0) { throw 'Windows export failed' }
Copy-Item -LiteralPath (Join-Path $projectPath 'README.md') -Destination (Join-Path $releasePath '使用说明.md') -Force
Copy-Item -LiteralPath (Join-Path $projectPath 'LICENSE') -Destination (Join-Path $releasePath 'LICENSE') -Force
foreach ($license in @('GODOT-LICENSE.txt', 'GODOT-COPYRIGHT.txt')) {
    Copy-Item -LiteralPath (Join-Path $projectPath ('assets\' + $license)) -Destination (Join-Path $releasePath $license) -Force
}
Copy-Item -LiteralPath (Join-Path $projectPath 'fonts/OFL.txt') -Destination (Join-Path $releasePath 'NOTO-LICENSE.txt') -Force
Write-Host ('Built: ' + (Join-Path $releasePath 'GravityFour.exe'))
