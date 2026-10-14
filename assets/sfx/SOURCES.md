# SFX sources & licenses

Rule (see `assets/SOURCES.md`): record source + license per sound here
before it lands. Nothing ships without a redistribution-in-a-binary right.

## "400 Sounds Pack" (all 50 wavs) — OPEN ITEM

Every `.wav` in this folder comes from the purchased **"400 Sounds Pack"**
(kept untouched in `raw_assets/audio/400 Sounds Pack/<category>/`,
gitignored). 45 of them were copied straight from the pack's category
folders (Combat and Gore, Environment, Footsteps, Items, Materials, UI);
the 5 `sword_*.wav` files are the ones dungeon-platformer had already
pulled into its `assets/sfx/` from the same pack.

**OPEN ITEM — no license on record.** The pack ships no license file, and
none was found in the previous project (its `assets/sfx/SOURCES.md` carried
exactly this note for the sword sounds). Before any public build: retrieve
the author / store page / terms and the purchase receipt, drop the text at
`assets/licenses/400_Sounds_Pack_license.txt`, and fill the columns below.
Until then these sounds are **not cleared to ship**; the fallback is to
replace them with CC0 sounds (freesound / kenney) slot by slot in
`data/sfx.json`.

Wired by `data/sfx.json` (`sounds.<slot>.stream`); one-shots, `pitch` /
`pitch_var` per slot.

| file(s) | pack / author | license | license file | notes (pack folder → sfx.json slots) |
|---|---|---|---|---|
| `crunch.wav`, `punch.wav`, `punch_2.wav`, `squelching_1.wav`, `swipe.wav` | 400 Sounds Pack — author UNKNOWN | **UNKNOWN — OPEN ITEM** | (missing) | Combat and Gore → player_death / enemy_death / wall_break / boss_roar; player_hurt; hit; hit_squish; dash / whip / slingshot / lash |
| `ambient_wind.wav`, `creaky_door_short.wav`, `door_close.wav`, `door_open.wav`, `fire_lighting.wav`, `lock_lock.wav`, `lock_unlock.wav`, `water_dripping.wav`, `water_splashing.wav` | same | **UNKNOWN — OPEN ITEM** | (missing) | Environment → door_open; lantern_on; door_locked; door_unlock; ambient_drip; splash (ambient_wind, door_close, door_open unused) |
| `foley_footstep_concrete_1.wav`, `foley_footstep_concrete_2.wav`, `foley_footstep_concrete_3.wav`, `foley_footstep_concrete_4.wav`, `foley_footstep_gravel_1.wav`, `foley_footstep_gravel_2.wav` | same | **UNKNOWN — OPEN ITEM** | (missing) | Footsteps → footstep; land; footstep_2; jump; enemy_hop (concrete_4 unused) |
| `book_close.wav`, `book_open.wav`, `coin_collect.wav`, `gem_collect.wav`, `heart_collect.wav`, `item_equip.wav`, `keys_jingling.wav`, `map_close.wav`, `map_open.wav`, `page_turn.wav` | same | **UNKNOWN — OPEN ITEM** | (missing) | Items → save / menu_close; menu_open; pickup; heal; item_equip; pickup_key; map_close; map_open; page_turn (coin_collect unused) |
| `concrete_scrape.wav`, `metal_blunt_tap.wav`, `metal_clang.wav`, `pottery_clang.wav`, `stone_push_long.wav`, `stone_push_medium.wav`, `stone_push_short.wav`, `wood_small_hollow.wav` | same | **UNKNOWN — OPEN ITEM** | (missing) | Materials → grapple_shot / wall_clink / hit_stone; grapple_latch / lever; gate_open / boss_charge; gate_close; block_push / boss_slam; button_press / button_release / item_drop (concrete_scrape, pottery_clang unused) |
| `cancel.wav`, `pop_1.wav`, `select_1.wav`, `select_2.wav`, `synth_error.wav`, `toggle_off.wav`, `toggle_on.wav` | same | **UNKNOWN — OPEN ITEM** | (missing) | UI → menu_back; enemy_shoot / spore; menu_move; menu_accept; menu_error; lantern_off / boss_blink (toggle_on unused) |
| `sword_light.wav`, `sword_slice.wav`, `sword_unsheath.wav`, `sword_clash.wav`, `sword_clash_2.wav` | same (via dungeon-platformer `assets/sfx/`) | **UNKNOWN — OPEN ITEM** | (missing) | swing (sword_light); the other four are unused so far |
