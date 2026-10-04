$ErrorActionPreference = 'Stop'
$projectPath = $PSScriptRoot
$engine = Join-Path $projectPath 'tools/Godot_v4.7.2-stable_win64_console.exe'
$releasePath = Join-Path $projectPath 'dist/android/GravityFour-v3.9.apk'
New-Item -ItemType Directory -Force -Path (Split-Path $releasePath) | Out-Null
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = Join-Path $projectPath 'tools/gravity-four-release.keystore'
$env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = 'gravityfour'
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = [IO.File]::ReadAllText((Join-Path $projectPath 'tools/release-key-password.txt')).Trim()
try {
    & $engine --headless --path $projectPath --editor --import
    if ($LASTEXITCODE -ne 0) { throw 'Godot import failed' }
    & $engine --headless --path $projectPath --export-release Android $releasePath
    if ($LASTEXITCODE -ne 0) { throw 'Android export failed' }
    $env:JAVA_HOME = 'C:/Program Files/Zulu/zulu-21'
    & (Join-Path $projectPath 'tools/android-sdk/build-tools/35.0.1/apksigner.bat') verify --verbose $releasePath
    if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed' }
} finally {
    Remove-Item Env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD -ErrorAction SilentlyContinue
}
Write-Host ('Built signed APK: ' + $releasePath)
Copy-Item -LiteralPath (Join-Path $projectPath 'README.md') -Destination (Join-Path (Split-Path $releasePath) '使用说明.md') -Force
