$ErrorActionPreference = 'Stop'
$bundlePath = Join-Path $PSScriptRoot 'auto_full_hive_assist.luau'
$bundle = Get-Content -LiteralPath $bundlePath -Raw
if ($bundle.Length -lt 50000) { throw "Bundle is truncated: $($bundle.Length) characters" }
if (-not $bundle.StartsWith('-- Full Hive Assist for Atlas / Arceus X Android')) { throw 'Bundle header is missing' }
$versionMatch = [regex]::Match($bundle, 'local SCRIPT_VERSION = "(\d+\.\d+\.\d+)"')
if (-not $versionMatch.Success) { throw 'Runtime version is missing' }
$version = $versionMatch.Groups[1].Value
if (-not $bundle.Contains("-- Version: $version")) { throw 'Bundle header version differs from runtime' }
$required = @(
    'type(getgenv) == "function" and getgenv()) or _G',
    'local compile = loadstring or load',
    'env.FullHiveVersion = SCRIPT_VERSION',
    'Version=SCRIPT_VERSION',
    'FeatherTheme.brand(frame',
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
    'local fallbackReady=p.collectorFallback',
    'local CHARACTER_UNAVAILABLE = {}',
    'local function runWithCharacterRecovery()',
    'if characterRoot()~=r then error(CHARACTER_UNAVAILABLE,0) end'
    'Policy.collectorRecovery(slots,1,usable',
    'local base=P.refill(slots)',
    'Report.NormalRefillAmount=Policy.refill(slots)',
    'local createHiveView = (function()',
    'viewButton.Name="ViewHiveButton"',
    '"CloseHiveButton"',
    'local level=bee.Lvl or bee.Level or "?"'
    'function Theme.draggable(panel,headerHeight,z)'
    'if inventory>=target and inventory>0 then'
    'if not jellyBatchReady(s) then return false end'
    'env.FullHiveJellyReady(stats)'
    'env.FullHiveJellySpent(remaining)'
    'function P.starJellyMissing(cells)'
    'local item=Policy.rollItem(cells,s.Eggs,p,rollTask)'
    'Roll settings changed before Star Jelly spending'
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
    runWithCharacterRecovery()
'@ -replace "`r`n", "`n"
if (-not ($bundle.Replace("`r`n", "`n")).Contains($gateOrder)) { throw 'Atlas gate must precede game-module loading and run()' }
[pscustomobject]@{ Path = $bundlePath; Version = $version; Characters = $bundle.Length; UTF8 = $true; CompatibilityMarkers = $required.Count }
