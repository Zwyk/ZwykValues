# ZwykValues 0.1.26

A standalone stat-weight addon written from scratch for WoW Forever. No Pawn code, Pawn dependency, third-party libraries, or online item database is required.

Version 0.1.26 includes passive stat-conversion talents in calculated weights, including Paladin Champion of the Light and Hunter Careful Aim. Their editable rank sliders default to the active spec, and the reverse Mana/MP5 calculations remove the same modeled contributions. Calculation tooltips retain the compact Modifiers section.

## Installation

1. Close WoW or return to the character selection screen.
2. Extract the `ZwykValues` folder into the Forever client's `Interface/AddOns` folder. The resulting path must be `Interface/AddOns/ZwykValues/ZwykValues.toc`.
3. Enable **ZwykValues** in the AddOns list. If the current beta lists it as out of date, enable **Load out of date AddOns**.
4. Log in and type `/zv`, click the small **ZV** button beneath the bottom trinket slot, or open **Options → AddOns → ZwykValues → Open ZwykValues**.

For a GitHub download, choose **Code → Download ZIP** in the repository, extract it, rename the unpacked repository folder (for example, `ZwykValues-main`) to `ZwykValues`, and copy that folder into `Interface/AddOns`.

The manifest targets interface `16001`, as reported by the Forever 1.60.1 client in the supplied diagnostics. The active interface number can be checked with `/dump select(4, GetBuildInfo())` if a later client lists the addon as out of date.

### Upgrading from ZwykPoints or ForeverWeights

Before removing the old addon folder, export each profile with **Export profile** from ZwykPoints (`/zwykpoints`) or ForeverWeights (`/fw`). Install ZwykValues, open `/zv`, and import those exports. Legacy `ZwykPoints` and `ForeverWeights` profile JSON and bare Sixty Upgrades weights remain accepted; new profile exports identify their format as `ZwykValues`.

WoW stores each addon's SavedVariables in a file named after that addon, so renaming the folder does not automatically load the old saved profiles. If `ZwykPointsDB` is already loaded when ZwykValues first initializes, ZwykValues copies its profiles, options, and compatible cache into an independent database. Otherwise it can copy a loaded `ForeverWeightsDB`. Existing `ZwykValuesDB` data always takes precedence. Export/import is the reliable migration path when the old folder is removed or disabled. After migration, keep only ZwykValues enabled to avoid duplicate tooltip scores. ZwykValues registers only `/zv` and `/zwykvalues`, leaving `/zp` available for ZwykPlus.

## Profiles

Create, copy, rename, or delete profiles in the left column. Set an individual tooltip color and toggle **Active** for every profile you want shown. Multiple profiles can be active together. Click the color square to open the native color picker; selecting a color saves it for that profile, and **Cancel** restores its original color. The hexadecimal field and **Set color** remain available.

An optional **Icon** beside the color controls opens a picker of the game's available macro icons. Choose an icon to show it before the profile name in the list and item tooltips, or choose **None** to remove it. Icon choices save immediately and remain part of copied profiles and full profile exports. Existing profiles start without an icon; icon changes keep your unsaved edits and cached item scores.

The picker groups icons into **Your class**, **Spells**, **Items** and **Other**. **All** puts your class first, using the spellbook and artwork explicitly labelled for that class. Search matches partial words in available spell/item names, ranks, descriptions, class/category names, texture filenames and IDs. Case and accents are ignored; multiple words narrow the results. Names come from the spellbook and available item data; unrelated icons remain searchable by their texture filenames and IDs. Hover an icon for its name and known details.

Edit weights in the grouped stat editor and apply them. Positive, zero, negative, and fractional weights are supported. The initial **My profile** is empty: it contains no invented class or specialization weights.

Each score is a linear sum:

`score = sum(item_stat_amount * profile_stat_weight)`

For example, 20 Strength at weight 2 and 1% Crit at weight 10 give 50 points in a percentage profile. Stamina is not converted to health, Strength is not converted to attack power, and Agility is not converted to crit: enter weights that already account for their value for your character.

Profiles are account-wide, including their active status, colors, icons and item filters. All changes and the score cache are stored by WoW in the addon's `SavedVariables` on logout or `/reload`.

Click **Item filters** in a profile to choose its weapon and armor types independently. The scrollable dialog provides a checkbox for each supported client subtype, including shields, class relics and miscellaneous armor/accessories. All types start checked for both new and existing profiles. Changes save immediately and apply to the profile's full/base tooltip values and its upgrade arrows.

Uncheck **Include items restricted to other classes** to exclude items whose explicit **Classes** restriction does not include your current character's class. An item allowing several classes remains included when yours is among them. This setting uses the current character, so a shared profile adapts when you log into another class. If required type or restriction metadata cannot be read, values wait for that data rather than assuming eligibility. Unchecked candidate items show no values for that profile; equipped comparison baselines still retain their complete score.

Copies and full profile exports preserve these choices. Bare weights JSON and older profiles without item filters start with every filter enabled.

## Stat units and JSON

The supplied Sixty Upgrades keys are preserved. **Import** accepts a bare JSON object of stat weights. Missing recognized keys become zero. Unknown keys and invalid numeric values are rejected with a message so typos cannot silently change a profile.

**Export weights** produces the bare stat object. **Export profile** also preserves the profile name, color, icon, item filters, upgrade activation, comparison target, calculator ratios and manual talent ranks. These metadata are lost when exporting only bare weights.

Secondary weights always use percentages; there is no rating mode:

| Key or group | Unit |
| --- | --- |
| `hit`, `crit`, `haste`, `expertise`, `dodge`, `parry`, `block` | Weight per percentage point; 1% means an amount of 1 |
| `defense` | Weight per defense skill point, when explicitly available |
| Primary stats, AP, spell/healing power, armor, resistances, health, mana | Weight per stat point |
| `hp5`, `mp5` | Weight per regeneration point per 5 seconds |
| `dps`, `rangedDps` | Weight per damage per second |
| `lowDamage`, `highDamage` | Weight per minimum/maximum weapon damage |
| `weaponDamage` | Weight per explicitly added flat weapon damage |
| `speed`, `rangedSpeed` | Weight per weapon swing second |

Merged melee/ranged/spell hit and crit aliases are counted once. The reader uses explicit tooltip percentages and keeps native API ratings separately for diagnostics. It does not apply an assumed rating conversion. If a needed percentage is unavailable, the item still shows the subtotal from known values, accompanied by a partial-data warning. Unavailable amounts contribute zero to that subtotal; an actually absent stat also contributes zero. Check the diagnostics before trusting a partial comparison.

The editor labels each secondary weight with **%**, or **skill** for defense. A crit weight of 10 means **10 points per 1%**: 0.5% contributes 5. For Manascale Treads, 157 armor at 0.05, 7 Strength at 0.2 and 7 Intellect at 0.3 contribute 11.35, giving **16.35** with its crit chance. Version 0.1.18 switches saved rating profiles and imported legacy profiles to percentages, keeping numeric weights and recalculating old totals. Full exports retain `secondaryUnit: "percent"` for compatibility.

Version 0.1.17 also fixes static wording such as `chance to critically hit with spells`: it counts as critical strike chance and does not add hit chance. Previously parsed item records refresh automatically.

`weaponDamage` is the explicit flat bonus (for example, `+1 Weapon Damage`), not the weapon's average base damage. To value average base damage, use half of the intended average-damage weight for both `lowDamage` and `highDamage`. JSON key compatibility is preserved, but all Sixty Upgrades field semantics have not been independently verified; check the units above when importing existing profiles.

Separate healing/damage effects and compound static enchant lines (for example, `Enchanted: Stamina +2 and Armor +16`) are recognized. Known enchant bonuses are included once; API base stats and the same tooltip stats are not added together.

English and French static tooltip text are supported, with localized Blizzard formats used where available. Other locales can still expose API stats, but unrecognized tooltip-only values need further validation.

Version 0.1.16 reads elemental wand damage ranges and the client's school-damage API aliases. `Your spells pierce N Magical Resistance` contributes to spell penetration. Separate signed Armor lines are bonus armor: Tortoise Armor's `208 Armor` and `+40 Armor` become 208 base armor and 40 bonus armor, counted once. Explicit damage-received reduction and profession skill bonuses are recorded as ignored diagnostics because they have no matching weight in the current stat schema; they do not create an offensive spell-damage value or a partial-data warning.

## Calculate weights from other weights

A small gear immediately left of a supported value box opens its calculation or fills its draft weight. Hover the gear to see a wider, structured tooltip with the formula, source weights, result and selected modifiers. The source stat fields referenced by that calculation are highlighted, including inputs whose current weight is zero. Highlights clear when the hover ends, another calculation is hovered, or the profile/editor changes; they do not edit values or move the scroll position. These buttons calculate **weights**; they do not add derived stats to items or run during item hover. Review the result and click **Apply weights** to save it. Recalculate after a level, form, talent or planned-buff change.

Supported relationships include Strength from attack power and shield block value, Agility from attack power/armor/critical strike/dodge, Stamina from Health, Intellect from Mana/spell critical strike/class conversion talents, Spirit from MP5 and class conversion talents, and the reverse Health/Mana/MP5 conversions. Mana is a separate resource weight, distinct from MP5. Old profiles start with a zero Mana weight. Native and English/French flat-Mana item stats and enchants are recognized; restoring Mana is not treated as a permanent flat-Mana bonus.

Mana and Intellect calculations use the next item-stat point and account for the first-20-Intellect breakpoint. The reverse Mana calculation subtracts Intellect's other modeled contributions before dividing by its Mana gain. The Mana tooltip shows an Intellect breakdown with positive shares labeled as deductions, including Crit and the outputs of the selected conversion talents. If those shares exceed a nonnegative Intellect weight, the result is unavailable: adjust the source weights or selected talent ranks before applying it. For example, an Intellect weight of 0.3 cannot include a Crit contribution worth 0.313 and still leave a nonnegative Mana value. Intentionally negative Intellect weights and manually entered negative Mana weights remain supported; tiny floating-point remainders are treated as zero.

Relevant calculation dialogs offer **Blessing of Kings (+10%)** and a **rank slider for each supported talent**. Sliders default to the current active spec and range from zero to that talent's maximum rank: Divine Strength and Divine Intellect use 0–5, each adding 2% per point. Moving a slider creates a manual override; untouched current ranks are never saved as fixed overrides. **Use current talents** removes the displayed overrides and restores automatic current-rank defaults. Manual ranks can also be chosen when the native talent rank is unreadable. Existing profiles that explicitly disabled talent bonuses retain zero-rank behavior until you choose a rank or restore current talents.

Kings and primary-stat talent bonuses multiply: Kings with a 10% primary-stat bonus gives a 1.21 multiplier. The same selected ranks apply in the reverse calculations, including Mana to Intellect and Health to Stamina. Choices and regeneration ratios remain drafts until Apply weights. The tooltip's **Modifiers** section contains only relevant stat bonuses and regeneration settings; data sources and general calculation assumptions are omitted from the tooltip.

The calculator also includes these passive conversions, applied once to the effective stat gain after Kings and primary-stat bonuses:

| Class / talent | Input | Output by selected rank |
| --- | --- | --- |
| Paladin — Champion of the Light | Intellect | Spell damage: 10/20/30%; no healing |
| Hunter — Careful Aim | Intellect | Melee and ranged attack power: 20/40/60/80/100% |
| Shaman — Mental Dexterity | Intellect | Melee attack power: 33/67/100% |
| Shaman — Mental Quickness | Intellect | Spell damage and healing: 15/30% |
| Druid — Natural Instinct | Intellect | Healing: 12/25% |
| Mage — Arcane Resilience | Intellect | Bonus armor: 25/50% |
| Priest — Spiritual Guidance | Spirit | Healing: 5/10/15/20/25%; spell damage: 1/3/5/6/8% |

Champion of the Light uses the October 1 baseline of 20/40/60%, replaced by 10/20/30% from client build 70425, following the [October 15 development notes](https://us.forums.blizzard.com/en/wow/t/2360696/6). The obsolete pre-October spell-damage-and-healing version is not modeled. Those notes also change Priest Mental Strength from 3% to 2% Intellect per rank; its primary-stat multiplier follows the same build boundary. If the build cannot be read, the earlier coefficients are retained. Conversion talent names, ranks and effects were checked against the [Talents Forever client-data export](https://talentsforever.com/data.json), used under CC BY 4.0, and the conversion references below. Spiritual Guidance uses the separate spell-damage and healing percentages printed for each rank; no unverified fractional coefficient is substituted. These are local passive-stat relationships; temporary procs and spell-specific scaling are outside this calculator.

For the modeled Hunter and Shaman Intellect-to-AP channels, the selected talent coefficient supplies the complete conversion. It replaces the native AP estimate for that channel, rather than adding to a native result that may already contain the current talent. Rank zero therefore removes that conversion even when the currently equipped spec has points in it. Other stat-to-AP paths retain their existing native or base class conversions.

Weapon DPS also calculates from attack power: the native autoattack conversion is normally 14 AP per DPS, so an AP weight of 0.1 produces a DPS weight of 1.4. The reverse AP calculation uses the same coefficient. Ranged equivalents apply to AP-scaled ranged weapons, excluding wands. These are autoattack equivalences, not rotation simulations.

Base Armor can calculate from the Dodge weight using the requested assumption that one percentage point of Dodge has the same value as one percentage point of physical damage reduction from Armor. It asks the native Forever mitigation API for the gain from the next effective Armor point at your current effective Armor against the chosen attacker level. The Armor calculation dialog offers **player level +0** and **player level +3**, defaulting to **+3**. The offset follows your effective player level, and the tooltip shows the resulting attacker level. Choosing a level updates the preview; the choice and weight save together with Apply weights. This is a local estimate: it assumes one base Armor point adds one effective Armor point, does not model form/talent Armor multipliers, and does not treat Dodge and Armor as equivalent against every attack. An unreadable native mitigation API makes this calculation unavailable instead of substituting an unverified Armor formula.

Native Forever conversion functions take priority and use the difference for the additional stat point. Where they are unavailable, supported calculations use their verified base coefficient or class/level Vanilla fallback. The fallback crit tables cover levels 1–60; an unavailable weighted conversion prevents applying the result. The compact gear tooltip shows the selected modifiers; the calculation limitations and references are documented here. These conversions are separate from item secondary-stat parsing: item weights remain per **1 percentage point**, and raw rating still receives no guessed conversion.

**Spirit** offers sliders for time affected by the five-second casting rule and the percentage of Spirit regeneration retained while casting. The initial retained-regeneration value is read from the active talent configuration when possible, including Paladin Reverence. **MP5** also asks for time in combat; its inverse calculation assumes full Spirit regeneration out of combat and applies the casting assumptions during combat. Spirit's mana-regeneration coefficient uses the current Spirit breakpoint and any selected primary-stat modifiers. Spiritual Guidance's selected spell-damage/healing contributions are included in Spirit and subtracted in the reverse MP5 calculation. A zero effective Spirit regeneration rate cannot infer an MP5 weight, so the dialog explains why that calculation is unavailable. Spirit's health regeneration remains outside this calculation.

Conversion references: [Forever character-stat UI](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UIPanels_Game/Camelot/PaperDollFrameStats.lua), [RatingBuster's Forever conversion data](https://github.com/raethkcj/RatingBuster/blob/905c14184527e0466c85b1d180bcd62d875fd4dd/libs/StatLogic/CamelotLogic.lua), [Forever Armor API](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/PaperDollInfoDocumentation.lua), and [Forever Equipment Manager APIs](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/EquipmentManagerDocumentation.lua). The addon has no runtime dependency on these sources.

## Tooltip comparisons

Values use a positive allowlist: supported weapon and armor subtypes in their character equipment slots, plus ammunition in the ammo slot. This includes jewelry, shields/offhands, relics, shirts and tabards. A weapon or armor candidate must have its subtype checked in that profile. Unknown numeric subtypes are excluded; missing class/subtype metadata waits for loading rather than assuming eligibility. Full and instant item-info APIs supply the classification. Equipped baselines bypass profile checkboxes while still requiring supported gear.

Version 0.1.14 applies this classification before reading stat APIs or scanning tooltips. Unchecked candidate types also stop before parsing, without saving an empty record that could affect another profile. Only actual item hyperlinks enter tooltip decoration: recipe, enchant, spell and trade links are skipped, including blacksmithing recipe tooltips. Consumables, quest items, crafting materials, bags/quivers, profession equipment and other non-gear items receive no full/Base values, comparisons, upgrade arrows or stat-debug markers, even if an older cache contains a score.

Ammunition's added damage per second uses the existing **Ranged weapon DPS** weight (`rangedDps`). For example, 7.5 ammo DPS at weight 2 gives 15 points. Ammo compares with the equipped ammunition slot; full/Base values and profile upgrade arrows use the same score. Weapon and armor subtype checkboxes do not exclude ammo. Ammunition does not require weapon speed or a damage range, and unreadable DPS remains partial rather than becoming a cached zero.

Every active profile adds one row with its name and score in the profile color. Candidate items show the signed point difference and percentage difference inline, with only the comparison fragment colored green for an increase, red for a decrease, or gray for equality:

`Mageladin    2.56  ↑+1.52 (+146.2%)`

A smaller, indented **Base** subline appears only when its displayed score or any equipped comparison differs from that profile's main row. Identical values are hidden, including differences too small to change the rounded display. It scores the same item without its enchant and compares it against the equipped items with their enchants removed too, so an equipped enchant can make Base relevant even on an unenchanted candidate. The client supplies the unenchanted stats directly; the addon does not subtract guessed enchant bonuses. Intrinsic item variants, including random-suffix stats, remain part of the base value. Equipped and shopping tooltips show the base score alone when it differs. Base loading/errors remain visible when they add different information, and partial-data warnings are retained even when a duplicate numeric row is hidden. The full score above still includes recognized enchants.

A smaller **Average use** subline adds the average gain from readable on-use stat buffs to the unenchanted Base value. Each effect contributes `stat amount × duration / cooldown`, using seconds for both times and limiting uptime to 100%. For example, 120 spell power for 10 seconds on a 2-minute cooldown contributes 10 average spell power; the profile's spell-damage and healing weights determine its value. Each equipped comparison uses its own Base plus average-use value too. The subline appears only when its rounded score or comparisons differ from Base, including a passive candidate compared with an equipped on-use item.

This estimate assumes using the item as soon as its cooldown ends. It needs an explicit flat stat amount, buff duration and total cooldown in the tooltip. It does not use the remaining cooldown, guess rating conversions, or model encounter length, delayed uses, shared trinket cooldowns, stacking, decreasing bonuses, proc chance or direct damage/healing abilities. Unsupported effects or an unavailable weighted secondary-stat unit show **Average use: unavailable** while retaining the ordinary scores. Bag, roll and chat arrows continue to use each enabled profile's full static score.

Version 0.1.8 accepts Forever's named item-quality colors (`|cnIQ2:`) as well as hexadecimal link colors, fixing **Base: Invalid item link** for those links. Both candidate and equipped item links retain their complete variant data when removing the enchant.

The up/down indicators use packaged arrow textures so they display even when the tooltip font has no Unicode arrow glyphs. Equality uses `=`. Two spaces separate the score from the first comparison. Multiple replacement choices share the same row, in equipped slot order:

`Mageladin    2.56  ↑+1.52 (+146.2%) | =0.00 (+0.0%)`

Percentages use:

`percentage = (candidate_score - equipped_score) / equipped_score * 100`

Rings and trinkets show both replacement choices. A two-handed weapon is compared to the combined equipped main-hand and off-hand score. Generic one-handed weapons show an off-hand comparison only when dual wielding is available and the equipped main hand is compatible. A shield/off-hand item does not receive a misleading comparison against a two-handed main hand.

An empty slot has score zero; a zero or negative baseline displays **percentage n/a** unless the scores are equal, which displays `=0.00 (+0.0%)`. Equipped and native shopping tooltips show their own item scores without recursively repeating candidate comparisons. Comparisons involving a partial candidate or equipped baseline display a warning because the missing stats could change the result. The addon evaluates item stats, not whether your class can equip every item you inspect.

## Optional upgrade arrows

In `/zv`, select each profile you want to use and check **Use this profile** in the **Upgrade arrows** panel. Any number of profiles can identify upgrades together, independently of their tooltip **Active** setting. Existing main-profile selections migrate automatically. Copies start with upgrade arrows disabled; full profile exports preserve the activation choice.

Use **Compare: Equipped** to choose that profile's baseline: currently equipped items, or one of the current character's Blizzard Equipment Manager sets. The selection also applies to that profile's Full, Base and Average use tooltip comparisons. Set references are bound to their character. A deleted set, another character's set, an ignored slot or an unreadable set item produces an unavailable comparison; it never silently falls back to equipped gear or an empty slot. Open the appropriate bag or bank when the full stored item link is unavailable. Enchants and random-suffix variants are retained; selecting a set does not equip or modify it.

Enable any of the three locations separately (all are off initially):

- **Item windows**: profile-colored arrows on upgrade item icons in bags, banks, trade, vendor, auction-house and loot windows.
- **Loot rolls**: profile-colored arrows on native loot-roll icons, including pooled gamepad roll cards.
- **Chat item links**: each matching profile's colored arrow, preceded by its optional profile icon, immediately after a newly received item link.

Item icons show up to three arrows in profile order, followed by a small **+N** count for additional matches. An arrow means the item scores higher than a replacement under that profile's selected comparison target. Rings/trinkets need to beat at least one comparable slot; two-handed weapons use the combined main/off-hand score. Comparisons wait for main-hand compatibility where needed. Parsing or stat-unit issues suppress the affected profile's upgrade decision, while tooltips retain their known subtotal and diagnostic warning.

Item-window and roll arrows refresh after item data loads, equipment changes (including enchants), equipment-set edits, bag/bank moves, item-window updates, and profile/option edits. They clear when an icon is reused or a roll ends. Chat arrows are a snapshot when each message arrives: an uncached item link requests data and stays unmarked in that message; later messages can show its arrow once the data is available. Existing chat history is retained as originally displayed.

Version 0.1.13 fixes repeated hover work: only item-data completions the addon is waiting for invalidate comparisons and refresh icons; unrelated, duplicate and failed notifications do not redraw all bags. A refresh checks each icon once. Partial reads and subtotals share a bounded, unsaved one-second cache across profiles, Full/Base rows and equipped comparisons, and temporary loading decisions retry after expiry. Completed requests, equipment/enchant changes and cache clearing invalidate those reads immediately. Definitive exclusions reuse a false upgrade decision. Automatic metadata retries are throttled; explicit diagnostic refreshes remain available. These caches reduce repeated scans without turning incomplete data into permanently saved scores.

Native Blizzard bag, bank, trade, vendor, auction-house, loot and loot-roll windows are supported. Merchant purchase and buyback icons share the same upgrade check. Loot rows clear immediately when looted, released, reused or closed; money and currency rows receive no arrow. BetterBags 0.5.14 is supported automatically, including its bank and list-row item icons; it uses the same **Item windows** checkbox and enabled upgrade profiles. Arrows update when equipment, profiles or item data change, and clear when a slot is reused. Empty slots and item-browser previews are excluded.

Other third-party bag addons can integrate their buttons explicitly with `ZwykValues:RegisterUpgradeItemButton(button, linkProvider)` and re-register after their own slot updates; `linkProvider(button)` must return the current full item link or nil.

After upgrading to 0.1.22, parser-versioned cache keys automatically reread items, including Mana values previously ignored by older readers. The report's top-level addon version identifies the exporter; each entry's `parserVersion` and `lastSeen` identify when that issue was collected. Issue exports intentionally preserve historical problems. To collect a fresh report, run `/zv clearissues`, then `/zv clearcache`, hover the affected items again, and run `/zv exportissues`.

## Debugging unrecognized stats

Enable **Mark unrecognized stats in tooltips** in the editor. Static stat lines that the parser cannot recognize receive an orange `[ZV ?]` marker next to their text. This also works with no active profiles. It is off by default and does not change weights or item scores.

The inline marker identifies a specific unrecognized line. A partial-data notice covers all detected issues, including unknown API fields, missing tooltip data and unavailable stat units, which may have no identifiable line to mark. Both indicators can appear for the same item. The partial-data notice is shown once per tooltip, and calculated known values remain visible.

Use **Export issues** in the editor or `/zv exportissues` to copy one JSON report for every encountered item variant with issues. It includes raw client stats, original tooltip lines, parsed stats, warnings and profile-specific score issues. Collection runs even when inline debug markers are disabled. The issue history is separate from the score cache, survives `/reload` and logout, and is retained until `/zv clearissues`; clearing the score cache does not erase it. Repeated reads update a variant's diagnostic entry rather than adding duplicate items. This reports items encountered by the addon, rather than scanning the entire item database.

Diagnostics include those lines, raw client stat keys, and parser warnings. Item descriptions, requirements, use effects, and set/proc descriptions are not marked as missing static stats. The detection is deliberately limited to stat-looking lines; it cannot identify every possible novel tooltip wording before that wording has been observed.

## Persistent cache

Parsed stats and profile scores are stored locally. Cache keys include the full item payload, so suffixes, enchants, gems, and other variants do not collapse to one item ID; build, locale, and character level provide additional separation. Repeated tooltips and equipped comparisons reuse stored totals.

Editing weights increments the profile revision and invalidates its scores. Color/name/active changes update display without changing stat values. The item cache is bounded to 2,000 variants. Missing or incomplete item data are not permanently cached as a zero-stat item. Equipment changes update comparisons; level/build/parser changes invalidate incompatible data.

| Command | Action |
| --- | --- |
| `/zv` or `/zwykvalues` | Open or close the profile editor |
| `/zv cache` | Show item and score cache counts |
| `/zv clearcache` | Clear parsed stats and scores |
| `/zv inspect` | Open diagnostics for a hovered item, or the main-hand item |
| `/zv inspect <item link>` | Open diagnostics for a pasted item link |
| `/zv exportissues` | Copy diagnostics for all encountered item variants with issues |
| `/zv clearissues` | Reset the recorded issue history without changing profiles or score caches |
| `/zv help` | Show commands |

## Scope and validation

This release evaluates static item stats and separately estimates the average of supported on-use stat buffs. Its weight helpers include the explicitly supported stat bonuses; it does not simulate procs, set bonuses, stat caps, complete talent trees, DPS rotations, class equipment restrictions, or future equipment combinations. Spell-power or attack-power weights should already include their expected value for your build. A higher score is a stat-weight estimate, not a simulated DPS percentage.

The Lua scoring, JSON, cache, parser, comparison, issue export, and tooltip/event logic are covered by mocked API tests included in `tests`. There is no running WoW client in this environment, so the actual UI rendering, the current Forever beta stat vocabulary, and secure tooltip behavior require an in-game check. Use `/zv inspect` for one item or `/zv exportissues` for all recorded issues.

Run the included tests from the addon directory with a Lua interpreter, for example:

```sh
lua tests/test_core.lua
lua tests/test_derived_weights.lua
lua tests/test_calculation_pipeline.lua
lua tests/test_equipment_sets.lua
lua tests/test_items.lua
lua tests/test_compare.lua
lua tests/test_base.lua
lua tests/test_on_use_items.lua
lua tests/test_on_use.lua
lua tests/test_report_stats.lua
lua tests/test_report_armor.lua
lua tests/test_weapon_schools.lua
lua tests/test_filters.lua
lua tests/test_item_metadata.lua
lua tests/test_tooltips.lua
lua tests/test_bootstrap.lua
lua tests/test_integration.lua
lua tests/test_ui.lua
lua tests/test_upgrades.lua
lua tests/test_indicators.lua
lua tests/test_betterbags.lua
lua tests/test_hover_performance.lua
```

`luatex --luaonly` can also run the tests when a standalone Lua executable is unavailable. Production modules use Lua 5.1-compatible syntax.

## Files

- `JSON.lua`: strict JSON reader/writer; no executable imports.
- `Stats.lua`: stat schema and native API mappings.
- `Core.lua`: profile management, import/export, scoring, and score-cache invalidation.
- `Items.lua`: item variants, client data loading, normalization, static tooltip parsing and timed on-use stat buffs.
- `DerivedWeights.lua`: on-demand class/level weight calculations and regeneration assumptions.
- `EquipmentSets.lua`: read-only, character-bound Equipment Manager baseline snapshots.
- `Compare.lua`: selected baseline slot comparisons.
- `Upgrades.lua`: independent profile upgrade decisions and local chat-link decoration.
- `Indicators.lua`: native bag/loot-roll overlays and refresh hooks.
- `Tooltips.lua`: native tooltip hooks and refresh handling.
- `Textures/ArrowUp.tga` and `Textures/ArrowDown.tga`: tooltip comparison indicators; `ArrowUpWhite.tga` supports profile-colored upgrade markers.
- `UI.lua`: profile and weight editor.
- `Bootstrap.lua`: saved variables lifecycle, events, diagnostics, and slash commands.

## License

MIT. See `LICENSE`.
