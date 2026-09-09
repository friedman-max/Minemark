[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)] [string] $WorldPath,
  [Parameter(Mandatory = $true)] [string] $OutputDirectory,
  [Parameter(Mandatory = $true)] [ValidateSet('preflight','postrun','validation')] [string] $Stage,
  [string] $PlayerUuid = '',
  [string] $MinecraftLogsPath = "$env:APPDATA\.minecraft\logs"
)

$ErrorActionPreference = 'Stop'
$node = Get-Command node -ErrorAction Stop
$script = Join-Path $PSScriptRoot 'capture-world-state.js'
$arguments = @($script, '--world', (Resolve-Path $WorldPath).Path, '--out', $OutputDirectory, '--stage', $Stage, '--logs', $MinecraftLogsPath)
if ($PlayerUuid) { $arguments += @('--player-uuid', $PlayerUuid) }
& $node.Source @arguments
if ($LASTEXITCODE -ne 0) { throw "World-state capture failed with exit code $LASTEXITCODE." }
