# Character sources & licenses

Rule (see `assets/SOURCES.md`): one line per file before it lands.

## Knight (`assets/character/Knight_player/`)

All 36 sheets in `Knight_player/` are one asset: the **Knight** by
**@Jump_Button** (Twitter), 100x64 px frames in a single row, one sheet per
animation. The license is the pack's own `Read_me.txt`, kept in place at
`assets/character/Knight_player/Read_me.txt` (it is the only copy; do not
move it). Store URL / purchase date unrecorded — see `assets/SOURCES.md`.
In `data/sprites.json` it is `players.knight`, a placeholder for the
archaeology student until her own art exists.

**Terms, quoted from `Read_me.txt`:**

> License Permissions:
>
> You can do:
>
> - You can use this asset for personal and commercial purposes. Credit is
>   not required for personal use but is required for any commercial use.
> - Modify to suit your needs.
>
> You can't do or use for:
>
> Do not resell or reproduce the image for profit.
>
> Do NOT use any of my work for AI (artificial intelligence technology,
> Machine Learning technology, or any derived technologies, AI/ML Training)
> NFT, blockchain technology, cryptocurrency, bitcoin, or any platforms or
> purposes that create products using this technology in any form (AI
> creation or NFTs). Such usage is completely prohibited and may result in
> legal action if necessary.

What that means for this project:

- **Credit is REQUIRED** for any commercial build: "Knight character art by
  @Jump_Button" goes on the credits screen. (Not optional, unlike the Szadi
  and Abstraction credits.)
- **No AI use, ever**: these sheets must never be fed to PixelLab or any
  other generator as a style reference, training input, or edit source —
  not even to make a matching placeholder. The `ai_placeholder/` README
  repeats this.
- Editing / re-timing the frames is allowed; reselling or redistributing
  the sheets on their own is not (the binary is fine).

| file(s) | pack / author | license | license file | notes |
|---|---|---|---|---|
| `Attack_KG_1.png` (6 f), `Attack_KG_2.png` (6), `Attack_KG_3.png` (9), `Attack_KG_4.png` (5) | Knight — @Jump_Button | Read_me terms above (commercial OK **with credit**, no AI) | `assets/character/Knight_player/Read_me.txt` | attack / attack2 / attack_air clips |
| `Crouching_KG_1.png` (3), `Crouching_KG_2.png` (4), `Crouching_Idle_KG_1.png` (3), `Crouching_Idle_KG_2.png` (3), `Crouching_Walk_KG_1.png` (4), `Crouching_Walk_KG_2.png` (4) | Knight — @Jump_Button | same | same | crouch / crouch_idle / crawl |
| `Dashing_KG_1.png` (4), `Rolling_KG_1.png` (10) | Knight — @Jump_Button | same | same | dash |
| `Drinking_KG_1.png` (7), `Power_Up_KG_1.png` (10), `Talking_KG.png` (4), `knight_win.png` (5) | Knight — @Jump_Button | same | same | use_item; the rest unused so far |
| `Dying_KG_1.png` (5), `Dying_KG_2.png` (6), `Hurt_KG_1.png` (4), `Hurt_KG_2.png` (4) | Knight — @Jump_Button | same | same | death / hurt |
| `Idle_KG_1.png` (4), `Idle_KG_2.png` (4), `Walking_KG_1.png` (7), `Walking_KG_2.png` (7) | Knight — @Jump_Button | same | same | idle / walk / run |
| `Jump_KG_1.png` (6), `Fall_KG_1.png` (3), `Landing_KG_1.png` (4), `Landing_KG_2.png` (4) | Knight — @Jump_Button | same | same | jump / fall (also swim) / land |
| `Ledge_Grab_KG_1.png` (6), `Grab_idle_KG_1.png` (3), `Wallside_KG_1.png` (2), `ladders_KG_1.png` (4) | Knight — @Jump_Button | same | same | ledge / wall / ladder |
| `Pushing_KG_1.png` (5) | Knight — @Jump_Button | same | same | push |
| `Shield_Up_KG_1.png` (7), `Shield_idle_KG.png` (4), `Shield_Bash_KG.png` (5) | Knight — @Jump_Button | same | same | aim (frame 0 of Shield_Up); the rest unused |
| `Read_me.txt` | Knight — @Jump_Button | (the license itself) | — | keep in place |
