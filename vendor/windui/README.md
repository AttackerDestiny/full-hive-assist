# Vendored WindUI

- `main.lua`: [Footagesus/WindUI 1.6.66 release asset](https://github.com/Footagesus/WindUI/releases/tag/1.6.66), MIT. Upstream asset SHA-256: `125b5dc3e5f02baf8008504879eef517ca29405c21255497e84da696fac51fc7`.
- `icons.luau`: [Footagesus/Icons at 46d30c1](https://github.com/Footagesus/Icons/tree/46d30c19ba7bc601d6ec794a48dc3a89568b1eec), MIT. Adapted to include only the Lucide entries referenced by this build, with no icon-pack downloads.

`build_feather_windui.ps1` binds WindUI to the local icon catalogue, removes the upstream remote-based icon fallback, and registers global input handlers for cleanup. Feather does not enable WindUI's key, executor config file, or remote background features. The MIT notices are included in the standalone bundle.
