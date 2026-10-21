param([Parameter(Mandatory=$true)][string]$ClientId,[string]$BundlePath,[switch]$CheckFinalBabyQuota)
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
$checkFinalBaby=$CheckFinalBabyQuota -or ([version]$versionMatch.Groups[1].Value -ge [version]'1.5.2')
$hasFunds=([version]$versionMatch.Groups[1].Value -ge [version]'1.6.1')
$hasHatchReceipt=([version]$versionMatch.Groups[1].Value -ge [version]'1.6.5')
$hasProgression=([version]$versionMatch.Groups[1].Value -ge [version]'1.6.0')
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
$finalBabyTests = Get-Content -LiteralPath (Join-Path $project 'tests/test_final_baby_quota.luau') -Raw
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
$code += 'local finalBabyTests=[======['+$finalBabyTests+']======];local checkFinalBaby='+$checkFinalBaby.ToString().ToLowerInvariant()+'; '
if ($hasProgression) {
    $progressionPolicy=[regex]::Match($bundle,'local ProgressionPolicy = \(function\(\)\n(.*?)\nend\)\(\)\nlocal createProgressionFacts',[Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value
    $progressionFacts=[regex]::Match($bundle,'local createProgressionFacts = \(function\(\)\n(.*?)\nend\)\(\)\nlocal createProgression =',[Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value
    if (-not $progressionPolicy -or -not $progressionFacts) { throw 'Cannot locate bundled progression modules' }
    $progressionTests=Get-Content -LiteralPath (Join-Path $project 'tests/test_auto_progression.luau') -Raw
    $progressionFactsTests=Get-Content -LiteralPath (Join-Path $project 'tests/test_progression_facts.luau') -Raw
    $code += 'local progressionPolicy=[======['+$progressionPolicy+']======];local progressionFacts=[======['+$progressionFacts+']======];'
    $code += 'local progressionTests=[======['+$progressionTests+']======];local progressionFactsTests=[======['+$progressionFactsTests+']======];'
}
if ($hasFunds) {
    $funds=[regex]::Match($bundle,'local ProgressionFunds = \(function\(\)\n(.*?)\nend\)\(\)\nlocal createAtlasProgressionControl',[Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value
    if (-not $funds) { throw 'Cannot locate bundled purchase funds guard' }
    $fundsTests=Get-Content -LiteralPath (Join-Path $project 'tests/test_progression_funds.luau') -Raw
    $code+='local funds=[======['+$funds+']======];local fundsTests=[======['+$fundsTests+']======];'
}
$code+='local hasFunds='+$hasFunds.ToString().ToLowerInvariant()+'; '
if ($hasHatchReceipt) {
    $hatchReceipt=[regex]::Match($bundle,'local ProgressionHatchReceipt = \(function\(\)\n(.*?)\nend\)\(\)\nlocal ProgressionFunds',[Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value
    if (-not $hatchReceipt) { throw 'Cannot locate bundled hatch receipt validator' }
    $hatchReceiptTests=Get-Content -LiteralPath (Join-Path $project 'tests/test_progression_hatch_receipt.luau') -Raw
    $code+='local hatchReceipt=[======['+$hatchReceipt+']======];local hatchReceiptTests=[======['+$hatchReceiptTests+']======];'
}
$code+='local hasHatchReceipt='+$hasHatchReceipt.ToString().ToLowerInvariant()+'; '
$code += 'local hasProgression='+$hasProgression.ToString().ToLowerInvariant()+'; '
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
local finalBabyOK,finalBabyResult=true,{notApplicable=true}
if checkFinalBaby then finalBabyOK,finalBabyResult=pcall(assert(loadstring(finalBabyTests))(),p,types) end
local progressionOK,progressionResult,progressionFactsOK,progressionFactsResult=true,{notApplicable=true},true,{notApplicable=true}
if hasProgression then
    local pp=assert(loadstring(progressionPolicy))()
    progressionOK,progressionResult=pcall(assert(loadstring(progressionTests))(),pp)
    progressionFactsOK,progressionFactsResult=pcall(assert(loadstring(progressionFactsTests))(),assert(loadstring(progressionFacts))(),pp)
end
local fundsOK,fundsResult=true,{notApplicable=true}
if hasFunds then fundsOK,fundsResult=pcall(assert(loadstring(fundsTests))(),assert(loadstring(funds))()) end
local hatchReceiptOK,hatchReceiptResult=true,{notApplicable=true}
if hasHatchReceipt then hatchReceiptOK,hatchReceiptResult=pcall(assert(loadstring(hatchReceiptTests))(),assert(loadstring(hatchReceipt))()) end
return {allPassed=main~=nil and star~=nil and policyOK and recoveryOK and collectorOK and batchOK and starJellyOK
    and starPreflightOK and starProgressOK and finalOccupancyOK and connectedReviewOK and failsafeOnlyOK and finalBabyOK and progressionOK and progressionFactsOK and fundsOK and hatchReceiptOK,
    main=main~=nil,mainError=mainError,embeddedStar=star~=nil,starError=starError,
    policy={ok=policyOK,result=policyResult},recovery={ok=recoveryOK,result=recoveryResult},collector={ok=collectorOK,result=collectorResult},batch={ok=batchOK,result=batchResult},starJelly={ok=starJellyOK,result=starJellyResult},
    starPreflight={ok=starPreflightOK,result=starPreflightResult},starProgress={ok=starProgressOK,result=starProgressResult},
    finalOccupancy={ok=finalOccupancyOK,result=finalOccupancyResult},connectedReview={ok=connectedReviewOK,result=connectedReviewResult},failsafeOnly={ok=failsafeOnlyOK,result=failsafeOnlyResult},finalBaby={ok=finalBabyOK,result=finalBabyResult},
    progression={ok=progressionOK,result=progressionResult},progressionFacts={ok=progressionFactsOK,result=progressionFactsResult},funds={ok=fundsOK,result=fundsResult},hatchReceipt={ok=hatchReceiptOK,result=hatchReceiptResult}}
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
