$ErrorActionPreference = 'Stop'
$bundlePath = Join-Path $PSScriptRoot 'auto_full_hive_assist.luau'
$bundle = Get-Content -LiteralPath $bundlePath -Raw
if ($bundle.Length -lt 50000) { throw "Bundle is truncated: $($bundle.Length) characters" }
if (-not $bundle.StartsWith('-- Full Hive Assist for Atlas / Arceus X Android')) { throw 'Bundle header is missing' }
$required = @(
    'type(getgenv) == "function" and getgenv()) or _G',
    'local compile = loadstring or load',
    'local function descendants(root, className)',
    'local function findText(root, text)',
    'button.Activated:Connect(stopAssist)',
    'local function loadModule(module)',
    'Native GuiButton activation is the reliable path on Arceus Android.',
    'BasicBatchTarget=10',
    'buy("Basic",1,"EggDispenser")',
    'assertAtlasPaused()',
    'local function waitForStartupDelay()',
    'StartupDelaySeconds=60',
    'Policy.startRollTask(p.target,p._cells,p)',
    'Policy.refillFor(slots,fallback)',
    'local fallbackReady=p.collectorFallback and slots==43'
)
foreach ($needle in $required) {
    if (-not $bundle.Contains($needle)) { throw "Compatibility marker missing: $needle" }
}
if ($bundle -match 'getgenv\(\)\.FullHive') { throw 'Raw getgenv hook remains in embedded Star Egg source' }
if ($bundle -match 'local env = getgenv\(\)') { throw 'Un guarded getgenv remains' }
if ($bundle.Contains('state[1]')) { throw 'Unguarded Atlas state indexing reintroduced' }
if ($bundle.Contains('waitForAtlasReady') -or $bundle.Contains('AtlasReadyStableSeconds')) { throw 'Atlas callback readiness wait was not removed' }
$gateOrder = @'
    if not waitForStartupDelay() then return end
    initializePlayer()
    makeUI()
    initializeModules()
    run()
'@ -replace "`r`n", "`n"
if (-not ($bundle.Replace("`r`n", "`n")).Contains($gateOrder)) { throw 'Atlas gate must precede game-module loading and run()' }
[pscustomobject]@{ Path = $bundlePath; Characters = $bundle.Length; UTF8 = $true; CompatibilityMarkers = $required.Count }
