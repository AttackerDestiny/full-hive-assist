# Amulets and quest assistance

The primary agent implemented this expansion from the user's attached requirements, then verified the game interfaces on both Arceus X accounts. No subagents were used after the human prohibited them. The latest release is1.7.9, adding bounded recovery from a resolved player-stats read timeout. Fire retirement, Star slot-pressure relief and fixed-pack ticket funding remain. Current live testing is limited to Luneri; Riley is unavailable.

Gear work has first priority, Star Amulet funding second, optional hive rolls third. Existing hive tasks/admission remain intact during waits. Passive quest consumables require no honey/movement and run before savings waits; active quest, remaining objective, owned items, cooldown and field position are rechecked before every request. Generated offers are processed before another generator action. No result or purchase is repeated after an uncertain outcome.

| Amulet | Decision and stop condition |
|---|---|
| King Beetle | Take the first. A first global+1BeeAttack overrides conversion; otherwise replace only for higher Convert Rate. Colored attack does not stand in for global attack. |
| Ant | Take the first. Qualified higher tiers win. Same-tier comparisons use Blue Pollen, Critical Chance, Critical Power, then Convert Rate. An incomplete higher tier uses the user's sum of percentage improvements shared by both offers as a temporary fallback. |
| Star | Use the highest unlocked discovered-gifted tier. Bronze/Silver/Gold/Diamond need capacity, Blue Pollen and global Pollen. Gold/Diamond additionally need at least40% combined Blue Pollen + global Pollen. Supreme needs capacity, Blue Pollen and Pop Star. Keep the current amulet unless the new offer qualifies; stop rerolling a satisfied highest unlocked tier until a higher tier unlocks. |
| Moon | Spend100MoonCharms per generated offer while the goal is incomplete, reserving active quest food first. Accept increasing capacity, then accept250000capacity with Honey per Pollen. Bond from Treats is a useful optional second stat. Stop generation as soon as that goal is present. |

The Ant correction was explicitly confirmed by the human: Silver/Gold require conversion, Blue Pollen and **either** crit stat. The inspected game defines a one-choice pool containing Movement Speed/Critical Chance/Critical Power for these tiers. Diamond can select both crit stats; Supreme's requested five stats remain possible. No requirement is inferred from RNG or time spent.

Star thresholds/prices are5/25M,10/50M,20/250M,30/1B,40/10B. Every action rechecks the actual generator's cost and gifted requirement. The Supreme server effect offers an additional500B choice at high honey; the worker invokes only the verified No-button callback for that exact question. It never chooses the500B option. Completion waits for both the new offer and toy-use receipt so an early counter update cannot permit another generation while a prompt is pending.

The40% minimum is a user preference from the revised prompt, not a game-defined requirement. One percentage point of Blue Pollen counts the same as one percentage point of global Pollen:30%+10%=40%. Capacity, Red/White Pollen, Bee Gather, crit and conversion do not contribute. Exactly40% qualifies; a40% Diamond may replace a40% Gold. An existing Gold/Diamond below40% no longer finishes the Star objective, so Star funding resumes behind gear priority. Bronze/Silver and the Supreme Pop Star requirement are unchanged. The status reports the current combined total and40% target during savings.

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

Before the relevant token objective completes, Ninja<=4, Lion<=2 and Fuzzy<=1 count normal plus gifted together. In ordinary planning, surplus Fuzzy is a Mythic-protection exception; a gifted copy is kept before normals. Over-cap Fuzzy outcomes cannot finish a repair while a normal surplus remains, except retaining the sole needed gifted copy before normal cleanup. The separately authorized pre-Star slot-pressure exception is described below; other ordinary Event/Mythic protection is unchanged.

After Star Journey1's2500Haste objective, every normal Ninja and all extra gifted Ninja become safe replacement slots. After Star Journey2's5000RedBoost objective, the same applies to Shy. The human clarified that this removes ordinary force reservations rather than allowing unlimited copies. Keep exactly one gifted Ninja and one gifted Shy if obtained, including explicit Star Egg preparation. Do not add an ordinary gifted acquisition minimum beyond existing stage/Star rules. These surplus slots precede optional flexible conversions and qualify as wrong slots for100-jelly recovery; stale normal goals or collector classification cannot accept them as completed roll results.

Retirement uses either an exact completed-quest entry or actual progress on the named currently active `Collect Tokens` task with the verified Tag and goal. It begins when the token objective completes even if other quest objectives remain. Quest absence, lifetime token counts, another token type, or unknown progress cannot release a force. The two species change independently. `FullHiveReport.QuestHiveRetirements` records the flags and their evidence; no quest completion or token remote is fired by this read.

Star Jelly eligibility is now **only** missing gifted Bomber/Cool/Bumble/Looker/Bubble/Commander/Bucko/Frosty. Gifted Basic, legendaries, and optional Bubble/Frosty upgrades do not extend it. Existing Royal Jelly admission, task coordinates, exact top-ups, repair completion and saved leftovers remain.

## Evidence and limits

### v1.7.7 additions

When a funded Star Egg workflow cannot fit all gifted non-Event/non-Mythic prerequisites plus one extra egg slot, the human authorizes a narrow Mythic exception. Existing safe slots are used first. Other Mythics and excess Fuzzy provide space before Tadpole/Buoyant; one Fuzzy is retained, preferring gifted. Tadpole/Buoyant remain unrestricted while there is room, then are reduced only as needed to two each, and toward one each only if two do not suffice. Their last copy, the reserved Fuzzy and all Events remain protected. If that still cannot fit, the workflow stops rather than rerolling forever. The exact selected Mythic coordinate is revalidated before spending; other permanent baselines remain checked. Ordinary and post-egg policies do not inherit this pre-Star exception.

The Diamond Egg route first uses owned tickets. If insufficient for one missing next-gear egg, it saves the rising-price honey cost of the remaining ticket deficit. Requests use only observed TicketDispenser options1/10/100/500, without custom quantities or overbuying the deficit. Each verified pack triggers a new quote and counter check; once funded, the Ticket Tent's Diamond1 option is used. When enough eggs exist, ticket acquisition stops and gear honey saving resumes. All shop travel requires Atlas paused, AlignPosition/noclip and nearby revalidation. No arbitrary manual purchase is issued for testing.

The latest human override retires the entire three-slot Shy/Fire placeholder group once the named Star Journey2 Red Boost objective completes. In ordinary planning only one gifted Shy remains reserved; all normal Shy and normal/gifted Fire become safe cleanup slots, including when a stale active roll goal still names Fire. Before completion, the prior placeholder rule remains. Explicit Star Egg preparation still needs one gifted Fire, and that prerequisite is preserved. Cleanup eligibility does not bypass gear/ticket/Star funding priorities. A read-only preview against Luneri's actual hive identified both Fire cells(3,2)/(4,3) as safe and its gifted Shy(2,7) as kept.

Live definitions inspected: `ReplicatedStorage.Amulets.GetTypeDef`, `Gui.RewardsPopUp`, `Gui.QuestionBox`, `Quests`, the named quest/task definitions, `PlayerActives`, `Activatables.Toys`, and each generator's cost/requirements/platform. The supplied community Ant wiki returned403; actual connected game definitions provided the ranges and feasible stat pools.

Current validation is4076 isolated checks locally and on Luneri's connected executor, main/embedded compilation and41compatibility markers. The54new scheduler assertions cover resolved/late/stuck/repeated stats reads and blocks for uncertain or changed requests, Star workflows, stops and failed Atlas release. The actual transport wrapper was not exercised by these scheduler fixtures; historical rejected transport fixtures remain excluded. Prior hive, Star pressure, ticket funding and quest checks remain. Riley is unavailable and was not tested or upgraded in this release.

Earlier natural live evidence includes Luneri accepting a Gold Star with1.75xcapacity,34%BluePollen and9%globalPollen; Moon250000capacity/6%HoneyPerPollen/6%BondFromTreats, followed by no further Moon generation; Fuzzy cleanup2→1; and Riley consuming exactly one MagicBean while in Pine Tree Forest, inventory68→67 and Nature's Lessons0/1→1/1. Before v1.7.4, fresh reads showed Riley's Diamond at38%Blue+9%global=47%, while Luneri's later Diamond had24%Blue+10%global=34%. Only the latter needs renewed saving under the new rule. Ant/King Beetle offers, Supreme's optional500B prompt and every future quest path have isolated/source coverage, not claims of naturally occurring live execution. See FULL_HIVE_TEST_LOG.md/full_hive_deployment.json for current deployment identities and limits.
