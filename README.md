# Feather

Run the public launcher:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/AttackerDestiny/full-hive-assist/main/start.luau"))()
```

The launcher downloads `core.luau` from `main`. Feather opens as soon as the player UI is available. Gameplay starts after the startup delay and waits for Atlas controls if needed.

Edit the Luau source modules and rebuild the bundle from PowerShell:

```powershell
./build_full_hive.ps1
./validate_arceus_bundle.ps1
```

See [configuration and workflow details](FULL_HIVE_README.md) and the [validation record](FULL_HIVE_TEST_LOG.md).
