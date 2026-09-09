[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)] [ValidateSet('prepare','grade')] [string] $Mode,
  [string] $ScenarioId = 'random-survival-peaceful-001',
  [string] $Model = '',
  [ValidateSet('none','minimal','low','medium','high','xhigh','max','ultra','not_applicable','unknown')] [string] $ReasoningEffort = 'unknown',
  [string] $AgentLabel = 'Codex desktop',
  [string] $AgentRuntimeVersion = 'unknown',
  [string] $ComputerUseRuntime = 'codex-native-windows',
  [string] $RuntimeRoot = 'C:\MinemarkRuntime\.minecraft',
  [string] $RunsRoot = "$PSScriptRoot\..\runs",
  [string] $RunDir = '',
  [switch] $FreshTaskAttested,
  [switch] $PriorContextExcludedAttested,
  [switch] $NoHumanInterventionAttested,
  [Nullable[int]] $ActionCount,
  [string] $RecordingPath = '',
  [string] $ActionLogPath = '',
  [string] $TerminationReason = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'runtime.ps1')

if ($Mode -eq 'prepare') {
  if (-not $Model) { throw 'Prepare mode requires -Model.' }
  if (-not $FreshTaskAttested -or -not $PriorContextExcludedAttested) {
    throw 'Prepare mode requires -FreshTaskAttested and -PriorContextExcludedAttested. Use them only when you will start a brand-new agent task with no earlier benchmark context.'
  }

  & (Join-Path $PSScriptRoot 'reset-benchmark-runtime.ps1') -RuntimeRoot $RuntimeRoot
  $created = & (Join-Path $PSScriptRoot 'start-run.ps1') -ScenarioId $ScenarioId -Model $Model -ReasoningEffort $ReasoningEffort -AgentLabel $AgentLabel -AgentRuntimeVersion $AgentRuntimeVersion -ComputerUseRuntime $ComputerUseRuntime -RunsRoot $RunsRoot -PassThru
  $runtime = Get-MinemarkRuntimeConfig -RuntimeRoot $RuntimeRoot
  $worldName = "Minemark-$($created.RunId)"
  & (Join-Path $PSScriptRoot 'restore-scenario.ps1') -RunDir $created.RunDir -RuntimeRoot $Runtime.Root -DestinationWorldName $worldName
  $worldPath = Join-Path (Join-Path $runtime.Root 'saves') $worldName
  $prompt = (Get-Content -LiteralPath $created.PromptPath -Raw).TrimEnd() + " Open only the single-player world named '$worldName'."
  Set-Content -LiteralPath $created.PromptPath -Value $prompt -Encoding UTF8
  $metadataPath = Join-Path $created.RunDir 'metadata.json'
  $metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
  $metadata.executionEnvironment.promptSha256 = (Get-FileHash -LiteralPath $created.PromptPath -Algorithm SHA256).Hash.ToLowerInvariant()
  $metadata | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $metadataPath -Encoding UTF8
  & (Join-Path $PSScriptRoot 'preflight-run.ps1') -RunDir $created.RunDir -WorldPath $worldPath -RuntimeRoot $runtime.Root

  $metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
  $metadata.isolation.newCodexTask = $true
  $metadata.isolation.priorContextExcluded = $true
  $metadata | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $metadataPath -Encoding UTF8
  & (Join-Path $PSScriptRoot 'assert-isolated.ps1') -RunDir $created.RunDir

  [pscustomobject]@{
    status = 'ready_for_agent'
    runId = $created.RunId
    runDirectory = $created.RunDir
    worldName = $worldName
    worldPath = $worldPath
    promptPath = $created.PromptPath
    nextStep = 'Start a brand-new agent task, provide only prompt.txt, then open the named world in the Minemark Benchmark Launcher installation.'
  } | ConvertTo-Json -Depth 5
  exit 0
}

if (-not $RunDir) { throw 'Grade mode requires -RunDir.' }
if (-not $NoHumanInterventionAttested) { throw 'Grade mode requires -NoHumanInterventionAttested.' }
$resolvedRunDir = (Resolve-Path -LiteralPath $RunDir).Path
$metadata = Get-Content -LiteralPath (Join-Path $resolvedRunDir 'metadata.json') -Raw | ConvertFrom-Json
$runtime = Get-MinemarkRuntimeConfig -RuntimeRoot $RuntimeRoot
$worldPath = $metadata.worldState.activeWorldPath
if (-not $worldPath) { throw 'The run has no preflight world path. It cannot be graded.' }
& (Join-Path $PSScriptRoot 'grade-run.ps1') -RunDir $resolvedRunDir -WorldPath $worldPath -RuntimeRoot $runtime.Root -NoHumanInterventionAttested -ActionCount $ActionCount -RecordingPath $RecordingPath -ActionLogPath $ActionLogPath -TerminationReason $TerminationReason
Get-Content -LiteralPath (Join-Path $resolvedRunDir 'result.json') -Raw
