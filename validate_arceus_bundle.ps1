param([string]$BundlePath)
$ErrorActionPreference = 'Stop'
if (-not $BundlePath) { $BundlePath=Join-Path $PSScriptRoot 'core.luau' }
$bundlePath=$BundlePath
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
    'local function loadModule(module)',
    'Native GuiButton activation is the reliable path on Arceus Android.',
    'BasicBatchTarget=10',
    'buy("Basic",1,"EggDispenser")',
    'assertAtlasPaused()',
    'Policy.startRollTask(p.target,p._cells,p)',
    'Policy.refillFor(slots,fallback)',
    'if item=="RoyalJelly" and not (jellyBatchReady(s) or refill()) then',
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
    'local StarState = (function()'
    'return Policy.snapshot(s,Types)'
    'function Progress.coverage(cells,types)'
    '"all-gifted-mythics-present"'
    'Basic continuation identity needs reconciliation'
)
if ([version]$version -ge [version]'1.8.2') {
    $required += @('local function setAssistEnabled(enabled)','Title="Assist enabled"','err==PAUSE_REQUESTED')
} else { $required += 'button.Activated:Connect(stopAssist)' }
foreach ($needle in $required) {
    if (-not $bundle.Contains($needle)) { throw "Compatibility marker missing: $needle" }
}
if ([version]$version -ge [version]'1.8.0') {
    foreach ($needle in @('local function loadFeatherWindUI(staging)','wind:CreateWindow','FeatherVisibilityButton','local m=createFeatherWindIcons()')) {
        if (-not $bundle.Contains($needle)) { throw "WindUI integration marker missing: $needle" }
    }
    if ($bundle.Contains('https://raw.githubusercontent.com/Footagesus/Icons/main/Main-v2.lua')) {
        throw 'WindUI icon loader must use the bundled catalogue'
    }
}
if ($bundle -match 'getgenv\(\)\.FullHive') { throw 'Raw getgenv hook remains in embedded Star Egg source' }
if ($bundle -match 'local env = getgenv\(\)') { throw 'Un guarded getgenv remains' }
if ($bundle.Contains('state[1]')) { throw 'Unguarded Atlas state indexing reintroduced' }
if ($bundle.Contains('waitForAtlasReady') -or $bundle.Contains('AtlasReadyStableSeconds')) { throw 'Atlas callback readiness wait was not removed' }
if ($bundle.Contains('Waiting for at least one bee and one Royal Jelly')) { throw 'Unrelated Royal Jelly startup gate was reintroduced' }
$gateOrder = @'
    if not waitForStartupDelay() then return end
    initializePlayer()
    makeUI()
    initializeModules()
    runWithCharacterRecovery()
'@ -replace "`r`n", "`n"
if ([version]$version -ge [version]'1.6.0') { $gateOrder=$gateOrder.Replace("    initializeModules()`n","    initializeModules()`n    initializeProgression()`n") }
if ([version]$version -ge [version]'1.8.16') {
    $gateOrder=$gateOrder.Replace("    if not waitForStartupDelay() then return end`n","")
    if ($bundle.Contains('waitForStartupDelay') -or $bundle.Contains('StartupDelaySeconds=60')) { throw 'Fixed startup delay was reintroduced' }
} elseif ([version]$version -ge [version]'1.8.15') {
    $gateOrder=$gateOrder.Replace("    if not waitForStartupDelay() then return end`n","").Replace("    makeUI()`n","    makeUI()`n    if not waitForStartupDelay() then return end`n")
}
if (-not ($bundle.Replace("`r`n", "`n")).Contains($gateOrder)) { throw 'Startup UI and gameplay order is incorrect' }
[pscustomobject]@{ Path = $bundlePath; Version = $version; Characters = $bundle.Length; UTF8 = $true; CompatibilityMarkers = $required.Count }
