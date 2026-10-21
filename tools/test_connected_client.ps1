param([Parameter(Mandatory=$true)][string]$ClientId,[string]$BundlePath)
$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
if (-not $BundlePath) { $BundlePath=Join-Path $project 'auto_full_hive_assist.luau' }
$bundle = (Get-Content -LiteralPath $BundlePath -Raw).Replace("`r`n","`n")
$policyMatch=[regex]::Match($bundle,'local Policy = \(function\(\)\n(.*?)\nend\)\(\)\nlocal StarState',[Text.RegularExpressions.RegexOptions]::Singleline)
if (-not $policyMatch.Success) { throw 'Cannot locate bundled policy' }
$policy=$policyMatch.Groups[1].Value
$runtimeAt=$bundle.IndexOf('-- Bundled by build_full_hive.ps1 after Policy and StarEggSource.')
if ($runtimeAt -lt 0) { throw 'Cannot locate bundled runtime' }
$runtime=$bundle.Substring($runtimeAt)
$versionMatch=[regex]::Match($runtime,'local SCRIPT_VERSION = "(\d+\.\d+\.\d+)"')
if (-not $versionMatch.Success) { throw 'Cannot locate bundle version' }
$hasFailsafeCorrection=([version]$versionMatch.Groups[1].Value -ge [version]'1.5.1')
$policyTests = Get-Content -LiteralPath (Join-Path $project 'test_full_hive_policy.luau') -Raw
$recoveryTests = Get-Content -LiteralPath (Join-Path $project 'test_character_recovery.luau') -Raw
$collectorTests = Get-Content -LiteralPath (Join-Path $project 'test_collector_recovery.luau') -Raw
$batchTests = Get-Content -LiteralPath (Join-Path $project 'test_jelly_batch.luau') -Raw
$starJellyTests = Get-Content -LiteralPath (Join-Path $project 'test_star_jelly.luau') -Raw
$starPreflightTests = Get-Content -LiteralPath (Join-Path $project 'tests/test_star_preflight_offline.luau') -Raw
$starProgressTests = Get-Content -LiteralPath (Join-Path $project 'tests/test_star_progress_offline.luau') -Raw
$finalOccupancyTests = Get-Content -LiteralPath (Join-Path $project 'tests/test_final_occupancy_offline.luau') -Raw
$connectedReviewTests = Get-Content -LiteralPath (Join-Path $project 'tests/test_connected_review_offline.luau') -Raw
$failsafeOnlyTests = Get-Content -LiteralPath (Join-Path $project 'tests/test_failsafe_only_recovery.luau') -Raw
$code = 'local bundle=[======['+$bundle+']======]; local runtime=[======['+$runtime+']======]; local policy=[======['+$policy+']======]; local tests=[======['+$policyTests+']======]; local recoveryTests=[======['+$recoveryTests+']======]; '
$code += 'local collectorTests=[======['+$collectorTests+']======]; '
$code += 'local batchTests=[======['+$batchTests+']======]; '
$code += 'local starJellyTests=[======['+$starJellyTests+']======]; '
$code += 'local starPreflightTests=[======['+$starPreflightTests+']======]; '
$code += 'local starProgressTests=[======['+$starProgressTests+']======]; '
$code += 'local finalOccupancyTests=[======['+$finalOccupancyTests+']======]; '
$code += 'local connectedReviewTests=[======['+$connectedReviewTests+']======]; '
$code += 'local failsafeOnlyTests=[======['+$failsafeOnlyTests+']======]; '
$code += 'local hasFailsafeCorrection='+$hasFailsafeCorrection.ToString().ToLowerInvariant()+'; '
$code += @'
local main,mainError=loadstring(bundle)
local embedded=assert(bundle:match("local StarEggSource = %[%=%=%=%=%[(.-)%]%=%=%=%=%]"))
local star,starError=loadstring(embedded)
local p=assert(loadstring(policy))()
local test=assert(loadstring(tests))()
local testRecovery=assert(loadstring(recoveryTests))()
local policyOK,policyResult=pcall(test,p,require(game.ReplicatedStorage.BeeTypes):GetTypes())
local recoveryOK,recoveryResult=pcall(testRecovery,runtime)
local collectorOK,collectorResult=pcall(assert(loadstring(collectorTests))(),p,require(game.ReplicatedStorage.BeeTypes):GetTypes(),runtime)
local batchOK,batchResult=pcall(assert(loadstring(batchTests))(),runtime,p,require(game.ReplicatedStorage.BeeTypes):GetTypes())
local starJellyOK,starJellyResult=pcall(assert(loadstring(starJellyTests))(),p,require(game.ReplicatedStorage.BeeTypes):GetTypes(),runtime)
local types=require(game.ReplicatedStorage.BeeTypes):GetTypes()
local starPreflightOK,starPreflightResult=pcall(assert(loadstring(starPreflightTests))(),embedded,types)
local starProgressOK,starProgressResult=pcall(assert(loadstring(starProgressTests))(),embedded)
local finalOccupancyOK,finalOccupancyResult=pcall(assert(loadstring(finalOccupancyTests))(),p,types)
local connectedReviewOK,connectedReviewResult=pcall(assert(loadstring(connectedReviewTests))(),p,types,embedded)
local failsafeOnlyOK,failsafeOnlyResult=true,{notApplicable=true}
if hasFailsafeCorrection then failsafeOnlyOK,failsafeOnlyResult=pcall(assert(loadstring(failsafeOnlyTests))(),p,types,runtime) end
return {allPassed=main~=nil and star~=nil and policyOK and recoveryOK and collectorOK and batchOK and starJellyOK
    and starPreflightOK and starProgressOK and finalOccupancyOK and connectedReviewOK and failsafeOnlyOK,
    main=main~=nil,mainError=mainError,embeddedStar=star~=nil,starError=starError,
    policy={ok=policyOK,result=policyResult},recovery={ok=recoveryOK,result=recoveryResult},collector={ok=collectorOK,result=collectorResult},batch={ok=batchOK,result=batchResult},starJelly={ok=starJellyOK,result=starJellyResult},
    starPreflight={ok=starPreflightOK,result=starPreflightResult},starProgress={ok=starProgressOK,result=starProgressResult},
    finalOccupancy={ok=finalOccupancyOK,result=finalOccupancyResult},connectedReview={ok=connectedReviewOK,result=connectedReviewResult},failsafeOnly={ok=failsafeOnlyOK,result=failsafeOnlyResult}}
'@
$argsPath = Join-Path ([IO.Path]::GetTempPath()) ('bss-tests-'+[guid]::NewGuid().ToString()+'.json')
try {
    [IO.File]::WriteAllText($argsPath,(@{clientId=$ClientId;code=$code;timeout=60000;maxOutputChars=6500} | ConvertTo-Json -Depth 4))
    $output = & node (Join-Path $PSScriptRoot 'call_roblox_mcp.mjs') get-data-by-code $argsPath
    $output
    if ($LASTEXITCODE -ne 0) { throw 'Roblox MCP test call failed' }
    $result = $output | ConvertFrom-Json
    if (($result.content.text -join "`n") -notmatch '\ballPassed=true\b') { throw 'Connected client regression checks failed' }
} finally {
    Remove-Item -LiteralPath $argsPath -Force -ErrorAction SilentlyContinue
}
