# Feather

Load Atlas first, then run the public launcher:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/AttackerDestiny/full-hive-assist/main/start.luau"))()
```

The launcher downloads `core.luau` from `main`. It preserves your configuration and checks for a running instance or unresolved requests before starting.

Edit the Luau source modules and rebuild the bundle from PowerShell:

```powershell
./build_full_hive.ps1
./validate_arceus_bundle.ps1
```

See [configuration and workflow details](FULL_HIVE_README.md) and the [validation record](FULL_HIVE_TEST_LOG.md).
