# Copies the phone APK into the Windows build, where the desktop app looks
# for it to install HK Cloner on phones plugged in over USB:
#   <Release folder>\data\hk-cloner.apk
#
# Usage: tool\bundle_apk.ps1 [path\to\app-release.apk]
# Build first: flutter build apk --release, then flutter build windows --release.
param([string]$Apk)
$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
if (-not $Apk) { $Apk = Join-Path $Root 'app\build\app\outputs\flutter-apk\app-release.apk' }
if (-not (Test-Path $Apk)) { throw "No APK at $Apk. Run 'flutter build apk --release' in app\ first." }

$Release = Get-ChildItem -Directory -Path (Join-Path $Root 'app\build\windows\*\runner\Release') -ErrorAction SilentlyContinue |
  Select-Object -First 1
if (-not $Release) { throw "No Windows build. Run 'flutter build windows --release' in app\ first." }

$Dest = Join-Path $Release.FullName 'data'
New-Item -ItemType Directory -Force -Path $Dest | Out-Null
Copy-Item $Apk (Join-Path $Dest 'hk-cloner.apk') -Force
Write-Host "Bundled APK -> $(Join-Path $Dest 'hk-cloner.apk')"
