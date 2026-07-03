# Runs the luma sync server locally from the compiled native exe.
#
# Why the exe and not "dart run"? A compiled exe reads nothing from the Dart
# pub cache at runtime, so it is immune to the intermittent Windows
# "cannot find path" build errors caused by antivirus scanning / the IDE's
# analysis server touching the cache at the same time.
#
# Usage:
#   .\run_local.ps1                  # first run compiles the exe, then starts it
#   .\run_local.ps1 -Rebuild         # force a fresh compile
#
# Configure by editing the values below (or set the env vars before running).

param([switch]$Rebuild)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $here

# ---- Configuration (edit these) --------------------------------------------
if (-not $env:LUMA_PORT)     { $env:LUMA_PORT = "8080" }
if (-not $env:LUMA_DATA_DIR) { $env:LUMA_DATA_DIR = Join-Path $here "data" }
# Registration is open by default. To close it once your accounts exist:
#   $env:LUMA_ALLOW_REGISTRATION = "false"
# ---------------------------------------------------------------------------

$exe = Join-Path $here "luma_server.exe"

# Stop any luma_server.exe that is still running — otherwise it holds the port
# AND locks the .exe file, so a rebuild silently keeps the old version (which
# is exactly what makes a stale "Route not found" survive restarts).
$running = Get-CimInstance Win32_Process -Filter "Name='luma_server.exe'" -ErrorAction SilentlyContinue
foreach ($proc in $running) {
    Write-Host "Stopping previous server (PID $($proc.ProcessId)) ..." -ForegroundColor Yellow
    Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
}
if ($running) { Start-Sleep -Milliseconds 500 }

if ($Rebuild -or -not (Test-Path $exe)) {
    Write-Host "Compiling luma_server.exe ..." -ForegroundColor Cyan
    # If this step fails with a "cannot find path" pub-cache error, just run
    # it again — compilation is a one-shot and the failure is transient.
    dart compile exe bin/luma_server.dart -o $exe
}

Write-Host "Starting luma sync server on port $($env:LUMA_PORT)" -ForegroundColor Green
Write-Host "  data dir : $($env:LUMA_DATA_DIR)"
Write-Host "In the app, use  http://localhost:$($env:LUMA_PORT)  as the server address."
Write-Host "Press Ctrl+C to stop.`n"

& $exe
