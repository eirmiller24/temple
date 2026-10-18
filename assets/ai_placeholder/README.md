# AI-generated placeholder art — the quarantine

**Policy (CLAUDE.md, README.md):**

1. **Everything AI-generated lives here, by class, and nowhere else.**
   `assets/ai_placeholder/<class>/` — `objects/`, `enemies/`, `pickups/`,
   `stations/`, `effects/` today; add a class folder when a new kind of
   placeholder appears. Purchased art never goes here; AI art never goes
   under `assets/<class>/`.
2. **It MAY ship.** The game is allowed to release with these sprites in
   it. "Placeholder" means "replaceable by a manifest edit", not "must be
   deleted first".
3. **Deleting this folder must never break the game.** Every manifest
   path into it (`data/sprites.json` and friends) resolves through
   `SpriteDb`, which falls back when a sheet is missing, so an
   `rm -r assets/ai_placeholder` leaves a playable build with blank or
   fallback sprites — never a crash, never missing collision (collision
   is the kind layer, which has no art).
4. **Every file has a provenance entry.** Each class folder carries an
   `ai_provenance.json` with one record per file:

   ```json
   {"file": "box.png", "tool": "pixellab", "method": "...", "prompt": "...",
    "ids": {...}, "date": "YYYY-MM-DD", "notes": "...",
    "origin": "copied from dungeon-platformer <path>"}
   ```

   `tests/test_assets.tscn` fails on any png/wav/ogg in here without an
   entry, and on any manifest path that is neither here nor covered by a
   `SOURCES.md` line.
5. **Never feed purchased art to a generator.** The Knight
   (`assets/character/`) forbids any AI use outright; the Szadi packs and
   the Forest Monsters do not grant it either. Style references for
   PixelLab come from other AI placeholders or from scratch, never from
   `assets/<class>/`.

The current files were all generated with **PixelLab** for the previous
project (dungeon-platformer, 2026-07) and copied over unchanged; their
records below carry the original object / animation ids so any sheet can
be regenerated or re-animated. Two were renamed on copy:
`stone_guardian.png` was `basalt_sentinel_ai.png`, `riftmaw.png` was
`riftmaw_ai.png`.

| folder | files | used by (data/sprites.json) |
|---|---|---|
| `objects/` | `box.png`, `button.png`, `boulder.png` | `objects.push_block`, `objects.button`, `objects.boulder` |
| `enemies/` | `stone_guardian.png`, `riftmaw.png` | `enemies.stone_guardian`, `enemies.riftmaw` |
| `pickups/` | `chest.png`, `chest_cache.png`, `equipment.png`, `money.png` | `objects.chest`; the rest are spare |
| `stations/` | `beacon.png`, `training_lever.png`, `wave_lever.png` | `objects.save_shrine`, `objects.lever`; `wave_lever` spare |
| `effects/` | `smash_burst.png` | spare (impact burst, 6 frames) |
| `ui/` | `item_<id>.png` ×12 (generated here, 2026-10-17) | `icons.<id>` — the pause menu and HUD item icons |
| `props/` | `rubble_slope_tall.png`, `rubble_slope_low.png`, `rubble_heap_1..4.png` (generated here, 2026-10-17) | none — `Sprite2D`s under `crevasse` `DecorBack` |
