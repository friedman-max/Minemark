[CmdletBinding()]
param([string] $RuntimeRoot = 'C:\MinemarkRuntime\.minecraft')

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'runtime.ps1')
$runtime = Get-MinemarkRuntimeConfig -RuntimeRoot $RuntimeRoot
foreach ($entry in $runtime.Config.clientBaseline.files) {
  $source = Join-Path (Join-Path $runtime.Root $runtime.Config.clientBaseline.directory) $entry.path
  if (-not (Test-Path -LiteralPath $source)) { throw "Baseline setting is missing: $source" }
  Copy-Item -LiteralPath $source -Destination (Join-Path $runtime.Root $entry.path) -Force
}
$checks = Assert-MinemarkClientBaseline -Runtime $runtime
Write-Output "Restored benchmark client settings: $((@($checks.Keys)) -join ', ')"
