function Get-MinemarkRuntimeConfig {
  param([string] $RuntimeRoot = 'C:\MinemarkRuntime\.minecraft')

  if (-not (Test-Path -LiteralPath $RuntimeRoot)) {
    throw "Minemark runtime is missing: $RuntimeRoot. Run setup-benchmark-runtime.ps1 first."
  }
  $resolvedRoot = (Resolve-Path -LiteralPath $RuntimeRoot).Path
  $configPath = Join-Path $resolvedRoot 'minemark-runtime.json'
  if (-not (Test-Path -LiteralPath $configPath)) {
    throw "Minemark runtime configuration is missing: $configPath. Run setup-benchmark-runtime.ps1 first."
  }
  $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
  if ($config.schemaVersion -ne 'minemark-runtime-v1') {
    throw "Unsupported Minemark runtime configuration: $configPath"
  }
  return [pscustomobject]@{ Root = $resolvedRoot; ConfigPath = $configPath; Config = $config }
}

function Get-MinemarkClientBaselineChecks {
  param([Parameter(Mandatory = $true)] $Runtime)

  $checks = [ordered]@{}
  foreach ($entry in $Runtime.Config.clientBaseline.files) {
    $currentPath = Join-Path $Runtime.Root $entry.path
    $checks[$entry.path] = (Test-Path -LiteralPath $currentPath) -and
      ((Get-FileHash -LiteralPath $currentPath -Algorithm SHA256).Hash.ToLowerInvariant() -eq $entry.sha256)
  }
  return $checks
}

function Assert-MinemarkClientBaseline {
  param([Parameter(Mandatory = $true)] $Runtime)

  $checks = Get-MinemarkClientBaselineChecks -Runtime $Runtime
  $failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object Key)
  if ($failed.Count -gt 0) {
    throw "Benchmark client settings do not match the baseline: $($failed -join ', '). Run reset-benchmark-runtime.ps1 before this run."
  }
  return $checks
}
