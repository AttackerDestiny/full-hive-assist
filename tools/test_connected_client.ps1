param([Parameter(Mandatory=$true)][string]$ClientId)
$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$bundle = Get-Content -LiteralPath (Join-Path $project 'auto_full_hive_assist.luau') -Raw
$runtime = Get-Content -LiteralPath (Join-Path $project 'full_hive_runtime.luau') -Raw
$policy = Get-Content -LiteralPath (Join-Path $project 'full_hive_policy.luau') -Raw
$policyTests = Get-Content -LiteralPath (Join-Path $project 'test_full_hive_policy.luau') -Raw
$recoveryTests = Get-Content -LiteralPath (Join-Path $project 'test_character_recovery.luau') -Raw
$collectorTests = Get-Content -LiteralPath (Join-Path $project 'test_collector_recovery.luau') -Raw
$batchTests = Get-Content -LiteralPath (Join-Path $project 'test_jelly_batch.luau') -Raw
$starJellyTests = Get-Content -LiteralPath (Join-Path $project 'test_star_jelly.luau') -Raw
$code = 'local bundle=[======['+$bundle+']======]; local runtime=[======['+$runtime+']======]; local policy=[======['+$policy+']======]; local tests=[======['+$policyTests+']======]; local recoveryTests=[======['+$recoveryTests+']======]; '
$code += 'local collectorTests=[======['+$collectorTests+']======]; '
$code += 'local batchTests=[======['+$batchTests+']======]; '
$code += 'local starJellyTests=[======['+$starJellyTests+']======]; '
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
return {allPassed=main~=nil and star~=nil and policyOK and recoveryOK and collectorOK and batchOK and starJellyOK,
    main=main~=nil,mainError=mainError,embeddedStar=star~=nil,starError=starError,
    policy={ok=policyOK,result=policyResult},recovery={ok=recoveryOK,result=recoveryResult},collector={ok=collectorOK,result=collectorResult},batch={ok=batchOK,result=batchResult},starJelly={ok=starJellyOK,result=starJellyResult}}
'@
$argsPath = Join-Path ([IO.Path]::GetTempPath()) ('bss-tests-'+[guid]::NewGuid().ToString()+'.json')
try {
    [IO.File]::WriteAllText($argsPath,(@{clientId=$ClientId;code=$code} | ConvertTo-Json -Depth 4))
    $output = & node (Join-Path $PSScriptRoot 'call_roblox_mcp.mjs') get-data-by-code $argsPath
    $output
    if ($LASTEXITCODE -ne 0) { throw 'Roblox MCP test call failed' }
    $result = $output | ConvertFrom-Json
    if (($result.content.text -join "`n") -notmatch '\ballPassed=true\b') { throw 'Connected client regression checks failed' }
} finally {
    Remove-Item -LiteralPath $argsPath -Force -ErrorAction SilentlyContinue
}
