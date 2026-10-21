# v1.5.2 candidate: final Baby quota

This candidate is **not deployed**. Authorized runtimes remain Riley v1.5.0 and Luneri v1.5.1; the default loader target and both pinned bundles are unchanged.

The existing final rule releases one Baby per gifted Tadpole, reaching zero Babies at four gifted Tadpoles. The task-completion code still used a fixed four-gifted-Baby limit and a fixed four-normal-Baby fallback. A new Baby could therefore finish a final cleanup task even though the fresh plan did not keep it, close its batch, and leave the same surplus Baby waiting for a new 500,000-jelly qualification.

The new regression reproduces that failure on the current v1.5.1 policy using a valid 50-bee final fixture. This is an isolated policy result, not a naturally observed failure on either connected account, which remain at 41 and 43 bees.

The candidate applies the fresh final `babyGoal` consistently in gifted limits, normal-outcome completion and reroll safety. It checks the current quota before stored task goals, accepts useful gifted upgrades replacing normal Babies, and preserves four-Baby behavior outside the final stage and all Music rules. Runtime changes only the version marker.

Connected isolated validation passed **3,036 checks per executor**, including 60 new cases for final Baby goals 0–4, excess normal/gifted outcomes, stale goals, valid upgrades and unchanged mid-stage behavior. The main and embedded code compile; the main workflow was never invoked. No live 50-slot hive or item requests were used.

Rebuild this candidate explicitly:

```powershell
./build_full_hive.ps1 -PolicyPath candidates/v1.5.2/full_hive_policy.luau -RuntimePath candidates/v1.5.2/full_hive_runtime.luau -OutputPath candidates/v1.5.2/auto_full_hive_assist.luau
```

The builder requires an explicit output path with source overrides to avoid replacing the default bundle accidentally. Validate with `tools/test_connected_client.ps1 -ClientId <fresh-verified-id> -BundlePath candidates/v1.5.2/auto_full_hive_assist.luau`; this compiles the bundle and runs isolated fixtures, without executing the assist. The current-version reproduction is available with `-CheckFinalBabyQuota` and is expected to fail its new quota assertion.

No deployment of this candidate is authorized by the current task. Remaining known receipt and acquisition limitations are unchanged.
