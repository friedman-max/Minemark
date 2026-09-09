[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)] [string] $RunDir,
  [Parameter(Mandatory = $true)] [ValidateSet('success','failure','timeout','death','aborted','invalid')] [string] $Outcome,
  [Nullable[int]] $ElapsedSeconds,
  [Nullable[int]] $Deaths,
  [Nullable[int]] $ActionCount,
  [string] $TerminationReason = '',
  [string] $RecordingPath = '',
  [string] $ActionLogPath = '',
  [string] $WorldSavePath = '',
  [switch] $ExtractionVerified,
  [switch] $TargetVerified,
  [string] $Notes = ''
)

$ErrorActionPreference = 'Stop'
$resolvedRunDir = (Resolve-Path $RunDir).Path
$metadataPath = Join-Path $resolvedRunDir 'metadata.json'
if (-not (Test-Path $metadataPath)) { throw "No metadata.json found in '$resolvedRunDir'. Start the run with start-run.ps1 first." }
$metadata = Get-Content -Raw $metadataPath | ConvertFrom-Json
if ($Outcome -eq 'success') {
  throw "Manual success recording is retired. Save and quit Minecraft, then use grade-run.ps1 so player inventory and integrity are evaluated from world files."
}
$endedAt = (Get-Date).ToUniversalTime().ToString('o')
$result = [ordered]@{
  runId = $metadata.runId
  benchmark = $metadata.benchmark
  scenarioId = $metadata.scenarioId
  agent = if ($metadata.agentConfiguration) { $metadata.agentConfiguration } else { $metadata.agent }
  executionEnvironment = if ($metadata.executionEnvironment) { $metadata.executionEnvironment } else { $null }
  startedAt = $metadata.startedAt
  endedAt = $endedAt
  outcome = $Outcome
  primarySuccess = ($Outcome -eq 'success')
  metrics = [ordered]@{
    elapsedSeconds = $ElapsedSeconds
    deaths = $Deaths
    actionCount = $ActionCount
    terminationReason = if ($TerminationReason) { $TerminationReason } else { $null }
  }
  evaluator = 'manual-v0-unscored'
  artifacts = [ordered]@{
    recordingPath = if ($RecordingPath) { $RecordingPath } else { $null }
    actionLogPath = if ($ActionLogPath) { $ActionLogPath } else { $null }
    worldSavePath = if ($WorldSavePath) { $WorldSavePath } else { $null }
  }
  notes = if ($Notes) { $Notes } else { $null }
}
$result | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 (Join-Path $resolvedRunDir 'result.json')
$metadata.status = 'finished'
if ($metadata.PSObject.Properties.Name -contains 'endedAt') {
  $metadata.endedAt = $endedAt
} else {
  $metadata | Add-Member -NotePropertyName endedAt -NotePropertyValue $endedAt
}
$metadata | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 $metadataPath
Write-Output "Recorded $($metadata.runId): $Outcome"
Write-Output "Result: $(Join-Path $resolvedRunDir 'result.json')"
