param(
    [string]$LuauPath = $env:LUAU_PATH,
    [ValidateSet('test_full_hive_policy.luau','test_character_recovery.luau','test_collector_recovery.luau','test_jelly_batch.luau','test_star_jelly.luau','tests/test_star_preflight_offline.luau','tests/test_final_occupancy_offline.luau','tests/test_star_progress_offline.luau','tests/test_connected_review_offline.luau','tests/test_failsafe_only_recovery.luau','tests/test_final_baby_quota.luau','tests/test_auto_progression.luau','tests/test_progression_facts.luau','tests/test_progression_funds.luau','tests/test_progression_hatch_receipt.luau','tests/test_progression_blender_receipt.luau','tests/test_amulet_policy.luau','tests/test_quest_assist_policy.luau')]
    [string[]]$Suites = @('test_full_hive_policy.luau','test_character_recovery.luau','test_collector_recovery.luau','test_jelly_batch.luau','test_star_jelly.luau','tests/test_star_preflight_offline.luau','tests/test_final_occupancy_offline.luau','tests/test_star_progress_offline.luau','tests/test_connected_review_offline.luau','tests/test_failsafe_only_recovery.luau','tests/test_final_baby_quota.luau','tests/test_auto_progression.luau','tests/test_progression_facts.luau','tests/test_progression_funds.luau','tests/test_progression_hatch_receipt.luau','tests/test_progression_blender_receipt.luau','tests/test_amulet_policy.luau','tests/test_quest_assist_policy.luau')
)
$ErrorActionPreference='Stop'
if (-not $LuauPath) {
    $candidate=Get-Command luau -ErrorAction SilentlyContinue
    if ($candidate) { $LuauPath=$candidate.Source }
}
if (-not $LuauPath) { throw 'Pass -LuauPath pointing to the official local Luau CLI. This runner never connects to Roblox.' }
$project=Split-Path $PSScriptRoot -Parent
$taskScript=Join-Path ([IO.Path]::GetTempPath()) ('hive-offline-'+[guid]::NewGuid()+'.luau')
function Literal([string]$Path) {
    $source=[IO.File]::ReadAllText((Join-Path $project $Path)).Replace("`r`n","`n")
    if ($source.Contains(']========]')) { throw 'Source conflicts with fixture delimiter' }
    return '[========['+$source+']========]'
}
try {
    $code='local env=assert(loadstring('+(Literal 'tests/offline_runtime_shims.luau')+'))()'+"`n"
    $code+='local function compile(s) return assert(env.loadstring(s)) end'+"`n"
    $code+='local P=compile('+(Literal 'full_hive_policy.luau')+')()'+"`n"
    $code+='local T=compile('+(Literal 'tests/offline_bee_types.luau')+')()'+"`n"
    $code+='local runtime='+(Literal 'full_hive_runtime.luau')+"`n"
    $bundle=Literal 'core.luau'
    $code+='local bundle='+$bundle+"`n"
    $code+='local starSource=assert(bundle:match("local StarEggSource = %[%=%=%=%=%[(.-)%]%=%=%=%=%]")); compile(bundle); compile(starSource)'+"`n"
    $code+='local total=0'+"`n"
    $code+='local Progression=compile('+(Literal 'progression_policy.luau')+')();local Facts=compile('+(Literal 'progression_facts.luau')+')()'+"`n"
    $code+='local Funds=compile('+(Literal 'progression_funds.luau')+')()'+"`n"
    $code+='local HatchReceipt=compile('+(Literal 'progression_hatch_receipt.luau')+')()'+"`n"
    $code+='local BlenderReceipt=compile('+(Literal 'progression_blender_receipt.luau')+')()'+"`n"
    $code+='local Amulets=compile('+(Literal 'amulet_policy.luau')+')();local QuestAssist=compile('+(Literal 'quest_assist_policy.luau')+')()'+"`n"
    foreach ($suite in $Suites) {
        $args=if ($suite -eq 'test_character_recovery.luau') {'runtime'} elseif ($suite -eq 'test_jelly_batch.luau') {'runtime,P,T'} elseif ($suite -eq 'tests/test_star_preflight_offline.luau') {'starSource,T'} elseif ($suite -eq 'tests/test_star_progress_offline.luau') {'starSource'} elseif ($suite -eq 'tests/test_connected_review_offline.luau') {'P,T,starSource'} elseif ($suite -eq 'tests/test_auto_progression.luau') {'Progression,'+(Literal 'progression_runtime.luau')} elseif ($suite -eq 'tests/test_progression_facts.luau') {'Facts,Progression'} elseif ($suite -eq 'tests/test_progression_funds.luau') {'Funds'} elseif ($suite -eq 'tests/test_progression_hatch_receipt.luau') {'HatchReceipt'} elseif ($suite -eq 'tests/test_progression_blender_receipt.luau') {'BlenderReceipt'} elseif ($suite -eq 'tests/test_amulet_policy.luau') {'Amulets'} elseif ($suite -eq 'tests/test_quest_assist_policy.luau') {'QuestAssist'} else {'P,T,runtime'}
        $code+='do local test=compile('+(Literal $suite)+')();local result=test('+$args+'); total+=result.passed;print("'+$suite+'",result.passed) end'+"`n"
    }
    if ($bundle -match 'local function loadFeatherWindUI\(staging\)') {
        $code+='do local test=compile('+(Literal 'tests/test_feather_wind_ui.luau')+')();local result=test('+(Literal 'feather_wind_ui.luau')+'); total+=result.passed;print("tests/test_feather_wind_ui.luau",result.passed) end'+"`n"
    }
    $code+='do local test=compile('+(Literal 'tests/test_event_purchase.luau')+')();local result=test(P,runtime); total+=result.passed;print("tests/test_event_purchase.luau",result.passed) end'+"`n"
    if ($bundle -match 'local MythicDiscovery =') {
        $code+='do local m=compile('+(Literal 'mythic_discovery.luau')+')();local t=compile('+(Literal 'tests/test_mythic_discovery.luau')+')();local r=t(m);total+=r.passed;print("tests/test_mythic_discovery.luau",r.passed)end'+"`n"
        $code+='do local m=compile('+(Literal 'mythic_discovery.luau')+')();local t=compile('+(Literal 'tests/test_mythic_runtime.luau')+')();local r=t(runtime,m);total+=r.passed;print("tests/test_mythic_runtime.luau",r.passed)end'+"`n"
    }
    $code+='do local t=compile('+(Literal 'tests/test_roll_atlas_lease.luau')+')();local r=t('+(Literal 'background_runtime.luau')+',runtime);total+=r.passed;print("tests/test_roll_atlas_lease.luau",r.passed)end'+"`n"
    $code+='do local m=compile('+(Literal 'feather_restart.luau')+')();local t=compile('+(Literal 'tests/test_feather_restart.luau')+')();local r=t(m,'+(Literal 'start.luau')+');total+=r.passed;print("tests/test_feather_restart.luau",r.passed)end'+"`n"
    $code+='do local m=compile('+(Literal 'route_dashboard.luau')+')();local t=compile('+(Literal 'tests/test_route_dashboard.luau')+')();local r=t(m,Progression);total+=r.passed;print("tests/test_route_dashboard.luau",r.passed)end'+"`n"
    $code+='print("OFFLINE PASS",total)'+"`n"
    [IO.File]::WriteAllText($taskScript,$code,[Text.UTF8Encoding]::new($false))
    & $LuauPath $taskScript
    if ($LASTEXITCODE -ne 0) { throw 'Isolated offline regression failed; no client was accessed' }
} finally { Remove-Item -LiteralPath $taskScript -Force -ErrorAction SilentlyContinue }
