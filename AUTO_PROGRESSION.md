# Feather auto progression v1.6.0

The coordinator owns gear purchasing, material preparation and hive spending. Atlas supplies farming. The user's October 21 expansion and standing instruction authorize tested updates on both accounts; older account-specific version pins are historical.

## Ordered route

| Required occupied bees **and** unlocked cells | Buy missing upgrades in this order |
| --- | --- |
| Starter | Clippers → Jar → Canister → Vacuum → Basic Boots → Belt Pocket → Helmet → Super-Scooper → Compressor → Electro-Magnet → Port-O-Hive → Honey Dipper → Propeller Hat → Hiking Boots → Brave Guard → Looker Guard → Bubble Wand |
| 25 | Basic Sprinkler → Candy Planter → Blue Clay Planter → Red Clay Planter → Beekeeper's Mask → Beekeeper's Boots → Mondo Belt Bag |
| 34 | Porcelain Dipper |
| 35 | Porcelain Port-O-Hive → Bubble Mask |
| 36 | Silver Soakers → Cobalt Guard |
| Following that group | Golden Gushers → Tacky Planter → Crimson Guard → Diamond Drenchers → Diamond Mask → Petal Belt → Coconut Canister → The Supreme Saturator |

Previously acquired stronger equipment satisfies earlier upgrades in the same verified slot. For example Cobalt Guard satisfies Brave Guard, while Crimson Guard satisfies Looker Guard. These are different shoulders. One-time planter ownership comes from the purchase ledger even while the planter inventory is zero.

The eight requested codes are checked case-insensitively against the server's redeemed-code array before any redemption. All eight were already redeemed on both observed accounts.

## Coordination with auto hive

An unlocked gear goal enters a material phase first. It reserves only the configured safety reserve while it buys the Royal Jelly and other inputs needed by the exact craft deficits, starts Blender orders, and lets the normal hive roller continue using the remaining honey. A completed Blender queue is collected before the next material order. When every material is present, the coordinator reserves the full gear price plus the safety reserve, pauses optional hive spending, and saves honey until it can buy and equip the gear. The coordinator preserves unfinished roll coordinates, Basic purchase ledgers and qualified batch identity. Crafting consumes actual Royal Jelly inventory; admission clears at zero and never seeds saved leftovers.

An unmet explicit bee gate permits the required hive growth before reserving the future gear price. Growth buys one slot and one Basic Egg at a time, using the live slot price. It hatches only a physically unlocked empty cell verified against fresh server stats, on row one or beside an active hex neighbor. Existing bees must remain unchanged. After the route is complete, existing hive goals run and growth can continue toward fifty when there is no active roll/Basic task.

All existing hive caps, failsafes, Event/Mythic protection, normal/recovery keep rules, Star Egg conditions, Royal Jelly threshold admission and save-leftovers behavior remain. Ninja ≤4 and Lion ≤2 count normal and gifted together. Ordinary first gifted Hasty/Rad/Riley/Stubborn copies receive no blanket protection. The previously tested final Baby quota correction is included.

## Materials and movement

The planner subtracts inventory before calculating exact craft deficits and accounts for shared ingredients across nested recipes. It uses current game recipe definitions, badge requirements and package prices. It never replaces an existing Blender order. The `UseBlenderTickets` setting and Feather toggle are off by default; when enabled, the planner uses only the exact remaining ticket count for the active order, while still requiring a fresh queue/output receipt. Normal collection waits for the recipe timer and reconciled output.

Gumdrops, Moon Charms and Star Jellies are never crafted. Gumdrops use only 3/30/300 packs costing 1/10/100 tickets. Royal Jelly uses actual fixed dispenser packs. Magic Beans, Moon Charms and Star Jellies wait for farming. Diamond Eggs use verified one-egg Ticket Tent purchases at the live price (400 tickets when inspected). Comforting/Refreshing vials require the verified condenser, at least twelve hours of the matching nectar, 35 bees, the vial cap and cooldown.

Every action uses the shared AlignPosition tween and nearby destination check. Noclip starts before tween playback, includes newly added parts and restores original collisions and listeners on arrival, stop, death or error. There are no distant purchases, CFrame teleports or firetouch calls in the new coordinator.

Verified Atlas progression/material-consumption and honey-spending Memory Match switches are disabled through their existing UI callbacks. Farming, reward collection and planter farming remain available. “Show Blender Messages” is logging and is left alone. An internal `nectarcondenser` setting has no exposed switch in this Atlas build; its independent behavior is unverified and is not represented as disabled.

## Evidence and limits

Read-only definitions and interfaces are recorded in [research/auto_progression/interface_contract.json](research/auto_progression/interface_contract.json). Both live clients were identified independently through connected Roblox MCP. No Diamond Egg token was discoverable in either client's collectible folders, so no token position, identifier or claim remote was invented. The script uses the verified purchase path when a required egg is missing.

The supported runner passed 3,230 isolated checks per connected executor and locally: 753 policy, 82 character/movement, 896 recovery, 325 batch, 589 Star Jelly, 220 Star preflight, 17 Star progress, 10 final occupancy, 82 connected review, 38 failsafe-only recovery, 60 final Baby quota, 129 progression and 29 fact-adapter checks. Main and embedded sources compile. Historical rejected transport fixtures remain excluded. These isolated results do not establish natural execution of every purchase, craft, condenser or hatch path; live observations are recorded separately in FULL_HIVE_TEST_LOG.md.
