param([Parameter(Mandatory=$true)][string]$ClientId,[string]$BundlePath,[switch]$CheckFinalBabyQuota,[string]$TestFilePath)
$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
if (-not $BundlePath) { $BundlePath=Join-Path $project 'core.luau' }
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
$hasBlenderReceipt=([version]$versionMatch.Groups[1].Value -ge [version]'1.6.6')
$hasBackground=([version]$versionMatch.Groups[1].Value -ge [version]'1.7.0')
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
if ($hasBlenderReceipt) {
    $blenderReceipt=[regex]::Match($bundle,'local ProgressionBlenderReceipt = \(function\(\)\n(.*?)\nend\)\(\)\nlocal ProgressionHatchReceipt',[Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value
    if (-not $blenderReceipt) { throw 'Cannot locate bundled Blender receipt validator' }
    $blenderReceiptTests=Get-Content -LiteralPath (Join-Path $project 'tests/test_progression_blender_receipt.luau') -Raw
    $code+='local blenderReceipt=[======['+$blenderReceipt+']======];local blenderReceiptTests=[======['+$blenderReceiptTests+']======];'
}
$code+='local hasBlenderReceipt='+$hasBlenderReceipt.ToString().ToLowerInvariant()+'; '
$code += 'local hasProgression='+$hasProgression.ToString().ToLowerInvariant()+'; '
if ($hasBackground) {
    $amulets=[regex]::Match($bundle,'local AmuletPolicy = \(function\(\)\n(.*?)\nend\)\(\)\nlocal QuestAssistPolicy',[Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value
    $quests=[regex]::Match($bundle,'local QuestAssistPolicy = \(function\(\)\n(.*?)\nend\)\(\)\nlocal createBackground',[Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value
    if (-not $amulets -or -not $quests) { throw 'Cannot locate bundled background policies' }
    $amuletTests=Get-Content -LiteralPath (Join-Path $project 'tests/test_amulet_policy.luau') -Raw
    $questTests=Get-Content -LiteralPath (Join-Path $project 'tests/test_quest_assist_policy.luau') -Raw
    $code+='local amulets=[======['+$amulets+']======];local quests=[======['+$quests+']======];local amuletTests=[======['+$amuletTests+']======];local questTests=[======['+$questTests+']======];'
}
$code+='local hasBackground='+$hasBackground.ToString().ToLowerInvariant()+'; '
$materialSource=[regex]::Match($bundle,'local MaterialFarm = \(function\(\)\n(.*?)\nend\)\(\)\n',[Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value
if ($materialSource) {
    $materialTests=Get-Content -LiteralPath (Join-Path $project 'tests/test_material_farm.luau') -Raw
    $code+='local materialFarmOK,materialFarmResult=pcall(assert(loadstring([======['+$materialTests+']======]))(),assert(loadstring([======['+$materialSource+']======]))(),runtime);'
} else { $code+='local materialFarmOK,materialFarmResult=true,{notApplicable=true};' }
$mythicSource=[regex]::Match($bundle,'local MythicDiscovery = \(function\(\)\n(.*?)\nend\)\(\)\n',[Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value
if ($mythicSource) {
    $mythicTests=Get-Content -LiteralPath (Join-Path $project 'tests/test_mythic_discovery.luau') -Raw
    $code+='local mythicOK,mythicResult=pcall(assert(loadstring([======['+$mythicTests+']======]))(),assert(loadstring([======['+$mythicSource+']======]))());'
    $mythicRuntimeTests=Get-Content -LiteralPath (Join-Path $project 'tests/test_mythic_runtime.luau') -Raw
    $code+='local mythicRuntimeOK,mythicRuntimeResult=pcall(assert(loadstring([======['+$mythicRuntimeTests+']======]))(),runtime,assert(loadstring([======['+$mythicSource+']======]))());'
} else { $code+='local mythicOK,mythicResult,mythicRuntimeOK,mythicRuntimeResult=true,{notApplicable=true},true,{notApplicable=true};' }
$settingsSource=[regex]::Match($bundle,'local FeatherSettings = \(function\(\)\n(.*?)\nend\)\(\)\n',[Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value
if ($settingsSource) {
    $settingsTests=Get-Content -LiteralPath (Join-Path $project 'tests/test_feather_settings.luau') -Raw
    $code+='local settingsOK,settingsResult=pcall(assert(loadstring([======['+$settingsTests+']======]))(),assert(loadstring([======['+$settingsSource+']======]))());'
} else { $code+='local settingsOK,settingsResult=true,{notApplicable=true};' }
$atlasValuesSource=[regex]::Match($bundle,'local atlasCallbackValues = \(function\(\)\n(.*?)\nend\)\(\)\n',[Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value
if ($atlasValuesSource) {
    $atlasValuesTests=Get-Content -LiteralPath (Join-Path $project 'tests/test_atlas_callback_values.luau') -Raw
    $code+='local atlasValuesOK,atlasValuesResult=pcall(assert(loadstring([======['+$atlasValuesTests+']======]))(),assert(loadstring([======['+$atlasValuesSource+']======]))());'
} else { $code+='local atlasValuesOK,atlasValuesResult=true,{notApplicable=true};' }
if ([version]$versionMatch.Groups[1].Value -ge [version]'1.8.91') {
    $backgroundSource=[regex]::Match($bundle,'local createBackground = \(function\(\)\n(.*?)\nend\)\(\)\n',[Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value
    if (-not $backgroundSource) { throw 'Cannot locate bundled background runtime' }
    $leaseTests=Get-Content -LiteralPath (Join-Path $project 'tests/test_roll_atlas_lease.luau') -Raw
    $code+='local rollLeaseOK,rollLeaseResult=pcall(assert(loadstring([======['+$leaseTests+']======]))(),[======['+$backgroundSource+']======],runtime);'
} else { $code+='local rollLeaseOK,rollLeaseResult=true,{notApplicable=true};' }
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
local blenderReceiptOK,blenderReceiptResult=true,{notApplicable=true}
if hasBlenderReceipt then blenderReceiptOK,blenderReceiptResult=pcall(assert(loadstring(blenderReceiptTests))(),assert(loadstring(blenderReceipt))()) end
local amuletOK,amuletResult,questOK,questResult=true,{notApplicable=true},true,{notApplicable=true}
if hasBackground then amuletOK,amuletResult=pcall(assert(loadstring(amuletTests))(),assert(loadstring(amulets))());questOK,questResult=pcall(assert(loadstring(questTests))(),assert(loadstring(quests))()) end
return {allPassed=rollLeaseOK and mythicRuntimeOK and mythicOK and settingsOK and atlasValuesOK and materialFarmOK and main~=nil and star~=nil and policyOK and recoveryOK and collectorOK and batchOK and starJellyOK
    and starPreflightOK and starProgressOK and finalOccupancyOK and connectedReviewOK and failsafeOnlyOK and finalBabyOK and progressionOK and progressionFactsOK and fundsOK and hatchReceiptOK and blenderReceiptOK and amuletOK and questOK,
    rollLease={ok=rollLeaseOK,result=rollLeaseResult},mythicRuntime={ok=mythicRuntimeOK,result=mythicRuntimeResult},mythic={ok=mythicOK,result=mythicResult},settings={ok=settingsOK,result=settingsResult},atlasValues={ok=atlasValuesOK,result=atlasValuesResult},materialFarm={ok=materialFarmOK,result=materialFarmResult},main=main~=nil,mainError=mainError,embeddedStar=star~=nil,starError=starError,
    policy={ok=policyOK,result=policyResult},recovery={ok=recoveryOK,result=recoveryResult},collector={ok=collectorOK,result=collectorResult},batch={ok=batchOK,result=batchResult},starJelly={ok=starJellyOK,result=starJellyResult},
    starPreflight={ok=starPreflightOK,result=starPreflightResult},starProgress={ok=starProgressOK,result=starProgressResult},
    finalOccupancy={ok=finalOccupancyOK,result=finalOccupancyResult},connectedReview={ok=connectedReviewOK,result=connectedReviewResult},failsafeOnly={ok=failsafeOnlyOK,result=failsafeOnlyResult},finalBaby={ok=finalBabyOK,result=finalBabyResult},
    progression={ok=progressionOK,result=progressionResult},progressionFacts={ok=progressionFactsOK,result=progressionFactsResult},funds={ok=fundsOK,result=fundsResult},hatchReceipt={ok=hatchReceiptOK,result=hatchReceiptResult},blenderReceipt={ok=blenderReceiptOK,result=blenderReceiptResult},amulets={ok=amuletOK,result=amuletResult},questAssist={ok=questOK,result=questResult}}
'@
if ($TestFilePath) {
    [IO.File]::WriteAllText($TestFilePath,('getgenv().FullHiveRegressionResult=(function() '+$code+' end)()'))
    Write-Output "Generated isolated test file; execution and allPassed verification are still required: $TestFilePath"
    return
}
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
