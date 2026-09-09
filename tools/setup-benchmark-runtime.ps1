[CmdletBinding()]
param(
  [string] $RuntimeRoot = 'C:\MinemarkRuntime\.minecraft',
  [string] $SourceMinecraftRoot = "$env:APPDATA\.minecraft",
  [string] $VersionId = '26.2',
  [switch] $SkipLauncherProfile
)

$ErrorActionPreference = 'Stop'
if (Get-Process MinecraftLauncher, javaw, java -ErrorAction SilentlyContinue) {
  throw 'Close Minecraft and the Minecraft Launcher before creating or updating the benchmark runtime.'
}
if (-not (Test-Path -LiteralPath $SourceMinecraftRoot)) { throw "Minecraft installation not found: $SourceMinecraftRoot" }
$sourceOptions = Join-Path $SourceMinecraftRoot 'options.txt'
if (-not (Test-Path -LiteralPath $sourceOptions)) { throw "Minecraft options.txt not found: $sourceOptions" }

New-Item -ItemType Directory -Force -Path $RuntimeRoot | Out-Null
$runtimeRootResolved = (Resolve-Path -LiteralPath $RuntimeRoot).Path
$baselineRoot = Join-Path $runtimeRootResolved 'minemark-baseline'
New-Item -ItemType Directory -Force -Path $baselineRoot, (Join-Path $runtimeRootResolved 'saves'), (Join-Path $runtimeRootResolved 'logs') | Out-Null

$baselineFiles = @('options.txt', 'optionsLC.txt') | Where-Object { Test-Path -LiteralPath (Join-Path $SourceMinecraftRoot $_) }
if ($baselineFiles.Count -eq 0) { throw 'No client settings files were found to baseline.' }
foreach ($file in $baselineFiles) {
  Copy-Item -LiteralPath (Join-Path $SourceMinecraftRoot $file) -Destination (Join-Path $baselineRoot $file) -Force
  Copy-Item -LiteralPath (Join-Path $baselineRoot $file) -Destination (Join-Path $runtimeRootResolved $file) -Force
}

$clientFiles = @($baselineFiles | ForEach-Object {
  $baselineFile = Join-Path $baselineRoot $_
  [ordered]@{ path = $_; sha256 = (Get-FileHash -LiteralPath $baselineFile -Algorithm SHA256).Hash.ToLowerInvariant() }
})
$config = [ordered]@{
  schemaVersion = 'minemark-runtime-v1'
  createdAt = (Get-Date).ToUniversalTime().ToString('o')
  runtimeRoot = $runtimeRootResolved
  minecraftVersion = $VersionId
  clientBaseline = [ordered]@{ directory = 'minemark-baseline'; files = $clientFiles }
  launcherProfileName = 'Minemark Benchmark'
}
$config | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $runtimeRootResolved 'minemark-runtime.json') -Encoding UTF8

if (-not $SkipLauncherProfile) {
  $profilesPath = Join-Path $SourceMinecraftRoot 'launcher_profiles.json'
  if (-not (Test-Path -LiteralPath $profilesPath)) { throw "Minecraft Launcher profiles file not found: $profilesPath" }
  $profilesData = Get-Content -LiteralPath $profilesPath -Raw | ConvertFrom-Json
  if ($null -eq $profilesData.profiles) { $profilesData | Add-Member -NotePropertyName profiles -NotePropertyValue ([pscustomobject]@{}) }
  $profileId = 'minemark-benchmark'
  $profile = [ordered]@{
    created = (Get-Date).ToUniversalTime().ToString('o')
    icon = 'Grass'
    lastUsed = (Get-Date).ToUniversalTime().ToString('o')
    lastVersionId = $VersionId
    name = 'Minemark Benchmark'
    type = 'custom'
    gameDir = $runtimeRootResolved
  }
  if ($profilesData.profiles.PSObject.Properties.Name -contains $profileId) { $profilesData.profiles.$profileId = $profile } else { $profilesData.profiles | Add-Member -NotePropertyName $profileId -NotePropertyValue $profile }
  $profilesData | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $profilesPath -Encoding UTF8
  $config.launcherProfileId = $profileId
  $config | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $runtimeRootResolved 'minemark-runtime.json') -Encoding UTF8
}

Write-Output "Created Minemark runtime: $runtimeRootResolved"
Write-Output 'A Launcher installation named Minemark Benchmark now uses this isolated game directory.'
Write-Output 'Run reset-benchmark-runtime.ps1 before every attempt.'
