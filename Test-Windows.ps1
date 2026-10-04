$ErrorActionPreference = 'Stop'
$projectPath = $PSScriptRoot
$engine = Join-Path $projectPath 'tools\Godot_v4.7.2-stable_win64_console.exe'
$logPath = Join-Path $projectPath '.artifacts/logs'
New-Item -ItemType Directory -Force -Path $logPath | Out-Null
& $engine --headless --path $projectPath --editor --import
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed' }
& $engine --headless --path $projectPath --script res://tests/test_board.gd
if ($LASTEXITCODE -ne 0) { throw 'Board tests failed' }
& $engine --headless --path $projectPath --script res://tests/test_features.gd -- --isolated-test
if ($LASTEXITCODE -ne 0) { throw 'Feature tests failed' }
& $engine --headless --path $projectPath --script res://tests/test_performance.gd -- --isolated-test
if ($LASTEXITCODE -ne 0) { throw 'Performance tests failed' }
& $engine --headless --path $projectPath --script res://tests/test_release_features.gd -- --isolated-test
if ($LASTEXITCODE -ne 0) { throw 'Release feature tests failed' }
& $engine --headless --path $projectPath --script res://tests/test_gameplay.gd -- --isolated-test
if ($LASTEXITCODE -ne 0) { throw 'Gameplay tests failed' }
& $engine --headless --path $projectPath --script res://tests/test_clocks_frames.gd -- --isolated-test
if ($LASTEXITCODE -ne 0) { throw 'Clock and frame tests failed' }
& $engine --headless --path $projectPath --script res://tests/test_series_challenges.gd -- --isolated-test
if ($LASTEXITCODE -ne 0) { throw 'Series and challenge tests failed' }
$port = Get-Random -Minimum 30000 -Maximum 50000
function Start-Probe([string]$role, [string]$script = "res://tests/network_probe.gd") {
    $stdoutPath = Join-Path $logPath ($role + '.log')
    $stderrPath = Join-Path $logPath ($role + '-errors.log')
    # Quote the project argument so this also works after moving into a path with spaces.
    $arguments = '--headless --path "{0}" --script {3} -- {1} {2} --isolated-test' -f $projectPath, $role, $port, $script
    return Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
}
function Wait-Probe($process, [int]$milliseconds) {
    if (-not $process.WaitForExit($milliseconds)) {
        $process.Kill()
        throw 'Network test process timed out'
    }
    $process.Refresh()
    if ($process.ExitCode -ne 0) { throw ('Network test failed: exit ' + $process.ExitCode) }
}
$hostProbe = $null
$clientProbe = $null
$badProbe = $null
$duplicateProbe = $null
try {
    $hostProbe = Start-Probe 'host'
    Start-Sleep -Seconds 1
    $badProbe = Start-Probe 'bad-password'
    Wait-Probe $badProbe 15000
    $duplicateProbe = Start-Probe 'duplicate-name'
    Wait-Probe $duplicateProbe 15000
    $clientProbe = Start-Probe 'client'
    Wait-Probe $clientProbe 30000
    Wait-Probe $hostProbe 5000
    foreach ($role in @('host', 'bad-password', 'duplicate-name', 'client')) {
        Get-Content -LiteralPath (Join-Path $logPath ($role + '.log'))
        $errors = Get-Content -LiteralPath (Join-Path $logPath ($role + '-errors.log')) -Raw
        if ($errors -match 'SCRIPT ERROR|ERROR:|FAIL') { throw $errors }
    }
    $port = Get-Random -Minimum 30000 -Maximum 50000
    $hostProbe = Start-Probe 'host' 'res://tests/network_undo.gd'
    Start-Sleep -Seconds 1
    $clientProbe = Start-Probe 'client' 'res://tests/network_undo.gd'
    Wait-Probe $clientProbe 30000
    Wait-Probe $hostProbe 5000
    foreach ($role in @('host', 'client')) {
        Get-Content -LiteralPath (Join-Path $logPath ($role + '.log'))
        $errors = Get-Content -LiteralPath (Join-Path $logPath ($role + '-errors.log')) -Raw
        if ($errors -match 'SCRIPT ERROR|ERROR:|FAIL') { throw $errors }
    }
    $port = Get-Random -Minimum 30000 -Maximum 50000
    $hostProbe = Start-Probe 'host' 'res://tests/network_lifecycle.gd'
    Start-Sleep -Seconds 1
    $clientProbe = Start-Probe 'client' 'res://tests/network_lifecycle.gd'
    Wait-Probe $clientProbe 20000
    Wait-Probe $hostProbe 5000
    foreach ($role in @('host', 'client')) {
        Get-Content -LiteralPath (Join-Path $logPath ($role + '.log'))
        $errors = Get-Content -LiteralPath (Join-Path $logPath ($role + '-errors.log')) -Raw
        if ($errors -match 'SCRIPT ERROR|ERROR:|FAIL') { throw $errors }
    }
    & $engine --headless --path $projectPath --script res://tests/test_touch.gd -- --mobile-preview --isolated-test
    if ($LASTEXITCODE -ne 0) { throw 'Touch input tests failed' }
    Write-Host 'All board, feature, touch and real ENet consent tests passed.'
} finally {
    foreach ($process in @($hostProbe, $clientProbe, $badProbe, $duplicateProbe)) {
        if ($null -ne $process -and -not $process.HasExited) { $process.Kill() }
    }
}
