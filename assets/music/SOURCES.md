# Music sources & licenses

Rule (see `assets/SOURCES.md`): record source + license per track here
before it lands. Nothing ships without a redistribution-in-a-binary right.

## Abstraction — Music Loop Bundle (all 8 tracks)

Every `.ogg` here is a "Sketchbook" loop from the **Abstraction Music Loop
Bundle** by **Abstraction / Tallbeard Studios** (Benjamin Burnes),
downloaded from https://tallbeard.itch.io/music-loop-bundle (the pre-2023,
2024-Q3 and 2025-Q4 bundles, kept untouched in
`raw_assets/audio/music-loop-bundle-*/`). License: **CC0 / Public Domain**.
The bundle's `_LICENSE.txt` is copied verbatim to
`assets/licenses/Abstraction_music_LICENSE.txt` and its `_README.txt` to
`assets/licenses/Abstraction_music_README.txt`. The wording:

> This asset bundle is licensed as Public Domain (CC-0 -
> https://creativecommons.org/publicdomain/zero/1.0/)
>
> To the extent possible under law, Abstraction Music
> (https://abstractionmusic.com/) and Tallbeard Studios
> (https://www.abstractionmusic.com/tallbeard.htm) has waived all copyright
> and related or neighboring rights to the music contained in this asset
> pack. This work is published from the United States.
>
> All assets are available to use in any commercial or non-commercial
> project, and may be modified in any way the user chooses.
>
> Although permitted within the license terms, Abstraction and Tallbeard
> Studios do not endorse the use of these assets in any projects relating
> to NFTs, AI/Machine Learning, or direct resale of unmodified assets.

Credit is not required; the README asks that, if we credit, we use the
artist name "Abstraction" with a link to the itch page or
https://abstractionmusic.com/ — do that on the credits screen. The
author's wish (not a term): no NFT / AI / unmodified-resale use.

Wired by `data/music.json` (`tracks.<name>.stream`); loop is set at
runtime for ogg.

| file(s) | pack / author | license | license file | notes |
|---|---|---|---|---|
| `Sketchbook 2024-02-07.ogg` | Abstraction Music Loop Bundle — Abstraction / Tallbeard Studios | CC0 | `assets/licenses/Abstraction_music_LICENSE.txt` | track `boss` |
| `Sketchbook 2024-03-20_01.ogg` | same | CC0 | same | track `quiet` |
| `Sketchbook 2024-06-19.ogg` | same | CC0 | same | track `collapse` |
| `Sketchbook 2024-08-07.ogg` | same | CC0 | same | track `galleries` |
| `Sketchbook 2024-09-04_LOOP.ogg` | same | CC0 | same | track `title` |
| `Sketchbook 2024-11-30.ogg` | same | CC0 | same | track `cistern` |
| `Sketchbook 2024-12-26.ogg` | same | CC0 | same | track `vault` |
| `Sketchbook 2025-11-13.ogg` | same | CC0 | same | track `deep` |

Wiring a new track: drop the `.ogg` here, add
`"name": {"stream": "res://assets/music/<file>.ogg", "volume_db": 0.0,
"loop": true}` to `data/music.json`, add a row above.
