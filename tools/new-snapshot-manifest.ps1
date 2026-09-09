[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)] [string] $SnapshotPath,
  [Parameter(Mandatory = $true)] [string] $OutputPath
)

$ErrorActionPreference = 'Stop'
$resolvedSnapshot = (Resolve-Path $SnapshotPath).Path
$excluded = @('session.lock', 'session.lock.snapshot', 'level.dat_old')
$files = Get-ChildItem -LiteralPath $resolvedSnapshot -Recurse -File |
  Where-Object { $_.Name -notin $excluded } |
  Sort-Object FullName |
  ForEach-Object {
    $relative = $_.FullName.Substring($resolvedSnapshot.Length).TrimStart('\').Replace('\', '/')
    [ordered]@{
      path = $relative
      bytes = $_.Length
      sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
  }

$manifest = [ordered]@{
  schemaVersion = 'minemark-snapshot-manifest-v1'
  createdAt = (Get-Date).ToUniversalTime().ToString('o')
  snapshotPath = $resolvedSnapshot
  excludedVolatileFiles = $excluded
  files = @($files)
}

$parent = Split-Path -Parent $OutputPath
if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Output "Snapshot manifest: $OutputPath"
Write-Output "Hashed files: $($files.Count)"
