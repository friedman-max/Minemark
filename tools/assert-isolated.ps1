[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)] [string] $RunDir
)

$ErrorActionPreference = 'Stop'
$resolvedRunDir = (Resolve-Path $RunDir).Path
$metadataPath = Join-Path $resolvedRunDir 'metadata.json'
if (-not (Test-Path $metadataPath)) { throw "No metadata.json found in '$resolvedRunDir'." }
$metadata = Get-Content -Raw $metadataPath | ConvertFrom-Json
$required = @('newCodexTask','cleanMinecraftSnapshot','priorContextExcluded')
if ($metadata.worldMode -eq 'random_seed_survival') {
  $required += 'emptyPlayerInventory'
} else {
  $required += 'emptyExtractionChest'
}
$missing = @($required | Where-Object { -not [bool]$metadata.isolation.$_ })
if ($missing.Count -gt 0) {
  throw "Run $($metadata.runId) is not isolated. Confirm these gates in metadata.json: $($missing -join ', ')"
}
if ($metadata.status -notin @('prepared', 'preflight_captured')) { throw "Run $($metadata.runId) has status '$($metadata.status)' and cannot be started." }
$metadata.status = 'ready'
$metadata | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 $metadataPath
Write-Output "Isolation verified for $($metadata.runId). Status: ready."
