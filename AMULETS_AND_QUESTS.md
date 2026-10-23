# Amulets and quest assistance

The primary agent implemented this expansion from the user's attached requirements, then verified the game interfaces on both Arceus X accounts. No subagents were used after the human prohibited them. The latest release is1.7.2.

Gear work has first priority, Star Amulet funding second, optional hive rolls third. Existing hive tasks/admission remain intact during waits. Passive quest consumables require no honey/movement and run before savings waits; active quest, remaining objective, owned items, cooldown and field position are rechecked before every request. Generated offers are processed before another generator action. No result or purchase is repeated after an uncertain outcome.

| Amulet | Decision and stop condition |
|---|---|
| King Beetle | Take the first. A first global+1BeeAttack overrides conversion; otherwise replace only for higher Convert Rate. Colored attack does not stand in for global attack. |
| Ant | Take the first. Qualified higher tiers win. Same-tier comparisons use Blue Pollen, Critical Chance, Critical Power, then Convert Rate. An incomplete higher tier uses the user's sum of percentage improvements shared by both offers as a temporary fallback. |
| Star | Use the highest unlocked discovered-gifted tier. Bronze/Silver/Gold/Diamond need capacity, Blue Pollen and global Pollen. Supreme needs capacity, Blue Pollen and Pop Star. Keep the current amulet unless the new offer qualifies; stop rerolling a satisfied highest unlocked tier until a higher tier unlocks. |
| Moon | Spend100MoonCharms per generated offer while the goal is incomplete, reserving active quest food first. Accept increasing capacity, then accept250000capacity with Honey per Pollen. Bond from Treats is a useful optional second stat. Stop generation as soon as that goal is present. |

The Ant correction was explicitly confirmed by the human: Silver/Gold require conversion, Blue Pollen and **either** crit stat. The inspected game defines a one-choice pool containing Movement Speed/Critical Chance/Critical Power for these tiers. Diamond can select both crit stats; Supreme's requested five stats remain possible. No requirement is inferred from RNG or time spent.

Star thresholds/prices are5/25M,10/50M,20/250M,30/1B,40/10B. Every action rechecks the actual generator's cost and gifted requirement. The Supreme server effect offers an additional500B choice at high honey; the worker invokes only the verified No-button callback for that exact question. It never chooses the500B option. Completion waits for both the new offer and toy-use receipt so an early counter update cannot permit another generation while a prompt is pending.

King Beetle/Ant offer choices require no Atlas lease or movement. Star/Moon generation uses the shared Atlas Stop Everything lease, AlignPosition tween, noclip and a verified nearby platform. All background mutations use the same FullHivePending/AutoHivePendingRequest/FullHiveUncertain safeguards. Accept/reject requests bind the actual offer package and current equipped amulet; readback must show the correct equipped package and consumed offer.

## Active quest whitelist

| Quest | Assisted objectives only |
|---|---|
| Hive Minded Bias | Remaining44MoonCharm feeding,4Stingers,1Enzymes,1Oil. Feed near the hive under an Atlas lease; other uses do not acquire movement. |
| Nature's Lessons; Beans Becoming | Remaining1MagicBean, only while standing in a field. |
| Forcefully Friendly | Remaining10FieldDice. |
| Do You Bee-lieve In Magic? | Moon generator, Sprout Summoner and Honeystorm once each, near the actual toy under an Atlas lease and only if the active objective is incomplete. |
| The Ways Of The Winds / The Wind And Its Ways | Remaining3CloudVials in a field. Acquire one Gold Egg from the verified one-egg TicketTent option if missing; the worker does not donate it. This is the combined name in the actual game definition. |
| Beeternity | Remaining5RedExtracts; use owned Coconuts in a field while the actual20-caught objective is incomplete and the item cooldown permits. Atlas handles catching. |
| A Breath Of Blue | Remaining5BlueExtracts and10FieldDice. |

Definitions come from `Quests:Get`, `ResolveTasks` and `GetProgression`. The optional quest-name argument is omitted from GetProgression so the read cannot trigger CompleteQuest. StartValues are copied before calculation. Both quest name and objective Type/Item/Toy must match; generic inventory possession does not mark an objective complete. Uses are bounded by the amounts authorized in the document, and completed objectives never repeat.

## Hive corrections retained

Ninja<=4, Lion<=2 and Fuzzy<=1 count normal plus gifted together. Surplus Fuzzy is the only new Mythic-protection exception; a gifted copy is kept before normals. Over-cap Fuzzy outcomes cannot finish a repair while a normal surplus remains, except retaining the sole needed gifted copy before normal cleanup. Other Event/Mythic protection is unchanged.

Star Jelly eligibility is now **only** missing gifted Bomber/Cool/Bumble/Looker/Bubble/Commander/Bucko/Frosty. Gifted Basic, legendaries, and optional Bubble/Frosty upgrades do not extend it. Existing Royal Jelly admission, task coordinates, exact top-ups, repair completion and saved leftovers remain.

## Evidence and limits

Live definitions inspected: `ReplicatedStorage.Amulets.GetTypeDef`, `Gui.RewardsPopUp`, `Gui.QuestionBox`, `Quests`, the named quest/task definitions, `PlayerActives`, `Activatables.Toys`, and each generator's cost/requirements/platform. The supplied community Ant wiki returned403; actual connected game definitions provided the ranges and feasible stat pools.

Final validation is3490 isolated checks locally and on each connected executor, main/embedded compilation and41compatibility markers. These include45amulet and47quest policy checks. Historical rejected transport fixtures remain excluded.

Natural live evidence includes Luneri accepting a Gold Star with1.75xcapacity,34%BluePollen and9%globalPollen; Moon250000capacity/6%HoneyPerPollen/6%BondFromTreats, followed by no further Moon generation; Fuzzy cleanup2→1; and Riley consuming exactly one MagicBean while in Pine Tree Forest, inventory68→67 and Nature's Lessons0/1→1/1. Both reports/UI are1.7.2. Ant/King Beetle offers, Supreme's optional500B prompt and every future quest path have isolated/source coverage, not claims of naturally occurring live execution. See FULL_HIVE_TEST_LOG.md/full_hive_deployment.json for deployment identities and limits.
