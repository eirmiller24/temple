# Writing in the Script of Rhys

How to put text in the script on a wall, in a texture or in a test, and how
to change the glyphs. The design is `design_v2.md` §11 (the script) and §14
(the language swap); this is the tool that implements the **plain register**
of §11.1. The decorative register (ligatures, mirroring) is not generated —
it stays hand-drawn.

| What | Where |
|---|---|
| Glyph shapes, spacing, default size and ink | `data/script.json` |
| Composer + pixel renderer (plain class, no autoloads) | `game/script/rhys_script.gd` (`RhysScript`) |
| Inscription node for rooms (live in the editor) | `game/script/script_text.gd` (`ScriptText`) |
| PNG baker (headless) | `tools/bake_script.gd` |
| Tests | `tests/test_script.tscn` |

---

## 1. Typing text

You type **sounds, not spelling** (§11.1: *safe* is S·e·F). Lower or upper
case, it doesn't matter.

| Type | Glyph | | Type | Glyph |
|---|---|---|---|---|
| `s` | S | | `z` | Z |
| `t` | T | | `d` | D |
| `k` | K | | `g` | G |
| `p` | P | | `b` | B |
| `h` | H | | `w` | W |
| `'` or `\|` | null | | `y` | Y |
| `r` | R | | `l` | L |
| `f` | F | | `v` | V |
| `n` | N | | `m` | M |
| `sh` | Sh | | `j` | J |
| `ch` | Ch | | `kh` | Kh |
| `th` | Th | | `dh` (or `dth`) | Dh |

Vowels: `a` (ah), `i` (ee), `u` (oo), `e` (eh), `o` (oh), `ai` (eye),
`au` (ow), and the null vowel `'` or `|` (short a/i/e). `'` and `|` are the
same glyph in either slot — the slot decides which it is, exactly as in the
script.

`c`, `q` and `x` are refused with a hint (soft c is `s`, hard c is `k`,
x is `ks`). So is any punctuation: §11.4 hasn't defined it yet.

**Digraphs.** The longest match wins, so `sh` is Sh. Put a `.` (or `·`, or
`-`) between letters to split one: `s.h` is S then H, `a.i` is a then i.

**What the tool does for you:**

- Consonants and vowels alternate (§11.1). Two consonants in a row share
  one slot, stacked, first on top: `sw'ch` → [S/W]·|·Ch.
- A word that starts with a vowel gets the null consonant: `over` → '·o·V·e·R.
- The null vowel is never written at either end of a word (Eir,
  2026-10-15). `'|z` ("is") is just Z, `dh|` ("the") is just Dh, and
  `'|fily|` ("Ophelia") is F·i·[L/Y]. A leading one takes its null
  consonant with it. Inside a word it stays: `kwesch|n` is
  [K/W]·e·[S/Ch]·|·N. So *be that is the question* is
  B·i·[∅/Dh]·a·[T/∅]·[Z/∅]·[Dh/∅]·[K/W]·e·[S/Ch]·|·N. A word that is
  nothing but the null vowel ("a") is just the null consonant, one
  stroke, and breaks like any one-consonant word. The pillar
  syllable *Rhys'* (`rh's'`) is [R/H]·|·S. All of this is in design_v2
  §11.3 and §11.6.
- Spaces between words become the §11.4 word breaks — half-empty slots or
  the underscore, whichever the table says:

  | You type | Chain |
  |---|---|
  | `dor sef` | D·o·[R/∅]·S·e·F |
  | `traks dor` | [T/R]·a·[K/S]·[∅/D]·o·R |
  | `traks tren` | [T/R]·a·[K/S]·_·[T/R]·e·N |
  | `sa 'o` | S·a·_·o |
  | `dor 'over` | D·o·R·_·'·o·V·e·R |
  | `sa dor` | S·a·[∅/D]·o·R |
  | `sa traks` | S·a·'·_·[T/R]·a·[K/S] |

  Vowel → single consonant uses the start-of-word half (Eir, 2026-10-15).
  A stack has no free half, so vowel → stack keeps V·'·_·C — a
  placeholder, marked *(assumed)* in design_v2 §11.4.

- A new line (Enter in the inspector, `\n` on the command line) starts a
  fresh chain. Nothing wraps on its own.

**What it guesses, and tells you about.** These are warnings, shown on
the node and printed by the baker — never silent:

- *Three consonants in a row* (`strong`): there's no slot for the third, so
  a null vowel goes in after the stack: [S/T]·|·R·o·[N/G]. Write it the
  way you want instead (`s'trong`, or brackets, below).
- *Two vowels in a row* (`a.i`): a null consonant goes between them.

**Writing the chain yourself.** The design doc's chain notation is valid
input and comes out unchanged: `[T/R]·e·[N/∅]·[T/R]·a·[K/S]`. Use
brackets for a stack (`[r/h]`), `∅` or `-` for an empty half (`[n/-]`),
and `_` for an underscore space. Where you write a break by hand, the
automatic word-break rules stay out of the way.

**Examples from the design doc:**

| Word | Type | Chain |
|---|---|---|
| Door | `dor` | D·o·R |
| Safe | `sef` | S·e·F |
| Switch | `sw'ch` | [S/W]·\|·Ch |
| Rhys | `rh's` | [R/H]·\|·S |
| Rhys'sthylceras | `rh's'sth'lseras` | [R/H]·\|·S·\|·[S/Th]·\|·[L/S]·e·R·a·S |
| train tracks | `tren traks` | [T/R]·e·[N/∅]·[T/R]·a·[K/S] |
| Games over | `gems 'over` | G·e·[M/S]·_·'·o·V·e·R |

## 2. An inscription in a room — `ScriptText`

Add a **ScriptText** node (it's a `Sprite2D`) under the room's paint —
`DecorBack`, `DecorFront` or `Props` — and type into **Text**. The glyphs
appear in the viewport as you type.

- **Chain** (read-only) shows how the text was read. Check it.
- The scene-tree **warning icon** lists anything refused or guessed.
- **Height px / Stroke px**: 0 means the default in `data/script.json`.
- **Orientation**: `rtl` (the base) or `ttb` (the same writing turned 90°
  counterclockwise, §11.1). **Align**: `start` is where reading begins.
- **Ink**: any colour. Lights and materials work as on any sprite.
- **Reload glyph data** re-reads `data/script.json` and redraws every
  ScriptText in the scene. In the game, F3 does the same.

The texture is rendered when the scene loads and is **not saved** in the
`.tscn`; the scene only stores the text and the settings. It is paint: it
never collides.

Later, `text` becomes a localized string key run through
grapheme-to-phoneme, and every ScriptText re-renders when the language
changes (§14.1–14.2). That is where `text` comes from, not how it draws.

## 3. A PNG — `tools/bake_script.gd`

```bash
godot --headless --path . -s res://tools/bake_script.gd -- "rh's'sth'lseras"
godot --headless --path . -s res://tools/bake_script.gd -- "dor" --out res://assets/script/door.png
godot --headless --path . -s res://tools/bake_script.gd -- "dor sef\nsw'ch" --ttb --height 13
godot --headless --path . -s res://tools/bake_script.gd -- --batch sigils.txt --out-dir res://assets/script
godot --headless --path . -s res://tools/bake_script.gd -- --chart --height 13 --scale 4
godot --headless --path . -s res://tools/bake_script.gd -- --chain "gems 'over"
```

The result is ink on a transparent background, black unless `--color`
says otherwise. To tint the PNG in Godot with `modulate`, bake it white
(`--color ffffff`). Without `--out` the PNG goes to
`user://script/<text>.png`, so nothing lands in the repo unless you ask.
`--scale N` is only for looking at the result; never ship an upscaled bake.
The batch file has one `name: text` per line, `#` starts a comment, and
`\n` is a line break. The full option list is in the script's header.

A baked PNG is our own art, not AI art: it goes under `assets/<class>/`
(e.g. `assets/script/`) with a `SOURCES.md` line saying which text and
which `data/script.json` produced it. **Re-bake after any glyph change.**
A ScriptText never needs re-baking, which is why rooms should use it.

## 4. Sizes, and what survives pixel art

A full-height glyph maps the 12-unit grid onto `height_px − 1` pixels, so
**heights of 12k+1 (13, 25, 37, 49) put every grid point on a pixel.**
Stacked consonants get about half that, rounded, so they never land
exactly.

`--chart` prints every glyph at full and half height. That's the check
for §11.9 rule 4. As of the first transcription:

- **25 px** (the default): every full-height glyph is clean. Half-height
  Ch/Kh, Th/Dh, Sh/J and M lose their inner strokes.
- **13 px**: full-height glyphs read. Half-height R/L and Sh/J become solid
  blocks, and F/V, Ch/Kh, Th/Dh, N/M and P/B are blobs. Only S/Z, T/D,
  K/G and H/W survive at half height.
- **37 px**: halves are mostly readable.

So stacked clusters need large text, or the dense glyphs need simpler
half-size shapes. That's a glyph-design decision, not a tool setting.

## 5. Changing a glyph

Everything is in `data/script.json`:

```json
"S": {"class": "consonant", "input": ["s"], "w": 6, "strokes": [[0,0, 0,12], [0,0, 6,12]]}
```

- `strokes`: polylines `[x0,y0, x1,y1, …]` on a grid where y runs from 0
  (the top of the slot) to `grid` (12, the bottom), and x from 0 to `w`.
  A point outside that box is a load error.
- `w`: the glyph's width in grid units. The slot is as wide as its widest
  glyph.
- `class`: `consonant`, `vowel`, `null` or `space`. `input`: what you type.
  `pair_of`: the consonant this one adds a base stroke to (§11.2). It's
  information for the future collision checker; nothing derives from it.
- Vowels are drawn in full-slot coordinates, so `i` and `au` sit in the
  top part of the slot because their strokes do.
- `layout` and `render` hold the spacing and the defaults; every value is
  required.

Edit, then press **Reload glyph data** on any ScriptText (or F3 in the
game), or re-run `--chart`. `tests/test_script.tscn` checks that every
glyph draws, that consonants fill their slot, and that the design doc's
example chains still come out.

## 6. What is decided, and what is a placeholder

Decided (from the design doc): phonetic chains, alternating
consonant/vowel slots, vertical-only stacks, one null glyph in two roles,
the §11.4 word-break table, right-to-left as the base orientation,
top-to-bottom as its 90° counterclockwise turn, and plain register for
anything generated.

Placeholders this tool filled, where the design is silent:

- The **cleaned-up glyph geometry** — the sketches in `script.xcf` snapped
  to a 12-unit grid, with mirror pairs made symmetric. Compare them
  against the sketch before trusting them.
- **Spacing**: `slot_gap` 3, `cluster_gap` 1, `line_gap` 6 units, and an
  underscore 6 units wide.
- **Stacks are centred** in their slot.
- **A third consonant gets a null vowel** after the first two. The stack is
  filled from the left, so `strong` gives [S/T]·|·R, not S·|·[T/R].
- **Two vowels in a row get a null consonant.**
- **Single consonant → stack** uses the top half-slot, the same as single →
  single (§11.4 lists only "consonant").
- **Vowel → stack** keeps the null consonant and underscore (V·'·_·[C/C]),
  since a stack can't move into a half-slot.
- **Lines don't wrap.** In `ttb`, lines become columns running left to
  right, because that's where the turn puts them.
- **`dth` is also typed as Dh**, because `script.xcf` labels the glyph
  "Dth".
- **Default size** 25 px, 1 px stroke, black ink.

Not built yet: grapheme-to-phoneme and the localization pipeline (§14.2
steps 1–4), the decorative register and sigil sets, punctuation, the
automated collision checker and the LLM decipherment harness (§11.9).
