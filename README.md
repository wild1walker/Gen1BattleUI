<p align="center">
  <a href="https://wild1walker.github.io/Gen1Wild/"><img src="docs/banner.png" alt="Gen1Wild" width="400"></a>
</p>

<h1 align="center">Gen1BattleUI</h1>

<p align="center">
  <img src="docs/logo.png" alt="" width="96">
</p>

<p align="center">
  <a href="https://wild1walker.github.io/Gen1Wild/"><img src="docs/lineup.png" alt="Check out my other mods!" width="880"></a>
</p>

The battle menu, as four buttons instead of a list.

A mod for [Gen1Recomp](https://github.com/bryanthaboi/gen1recomp).

---

## What it does

### Four buttons, in the game's own boxes

**`FIGHT`**, **`PKMN`**, **`ITEM`** and **`RUN`** each get a bordered box of
their own, laid out two by two across the bottom of the screen. The four moves
get the same four boxes when you pick `FIGHT`.

Nothing new was invented to draw them. A button here is `Font.drawBox` — the
same call, the same border glyphs, the same white interior every text box in
the game is made of — so a skin or a font mod that redraws the border redraws
these buttons with it, and this mod never has to know it happened.

That decision is also what fixes the sizes. A Game Boy text box spends its
first and last tile row on its border, so the smallest box that can hold a
line of text is **three tile rows**. Two rows of buttons is six, which is
exactly the six rows the classic layout's bottom strip has:

```
rows 12-14   FIGHT | PKMN        four 10x3 boxes, tiling
rows 15-17   ITEM  | RUN         the twenty-by-six strip exactly
```

### The grid was already in the numbers

The engine has always read the command menu as a 2×2 — `col = (i-1) % 2`,
`row = (i-1) // 2`, which is why <kbd>←</kbd> and <kbd>→</kbd> already crossed
between `FIGHT` and `PKMN`. It was only ever *drawn* as four words in one box.
So none of the menu's behaviour is replaced here: `menuIndex` is still the
engine's, still means what it meant, and is still moved by the engine's own
input handling. This is the drawing catching up with the arithmetic.

The move menu is the one that actually changes. It was a vertical list, so
<kbd>←</kbd> and <kbd>→</kbd> did nothing; the engine already has a hook for
making it a grid (`battle.move_grid_navigation`, which the widescreen layout
answers for itself), and this mod answers it too.

### Dialogue takes the strip back on its own

There is no handoff to get wrong. The mod asks the engine not to draw the
bottom strip for the three phases that are a *menu* — the command menu, the
move menu, and Mimic's copy menu — and asks for nothing else. `messages` is
left completely alone, so when the battle talks it is still the engine's own
text box, in the engine's own place, with the engine's own scroll and its own
blinking arrow. The buttons are simply not drawn underneath it, and they are
back on the frame the menu is.

The same rule is what keeps `PKMN` and `ITEM` working. A battle with a screen
open above it is still a battle whose strip is being drawn, so a mod claiming
it on the phase alone would take that screen's own prompts down with it. The
strip is claimed only while the battle is the **top** of the state stack.

### `ITEM` parks the menu rather than replacing it

The bag does not leave the menu, it opens **on** it. Its item list is the one
list in the game that is not a screen of its own — `ListMenu`'s `itemBox`,
`isOpaque = false`, *"a partial box the map stays visible around"* — and it is
sixteen tiles at (4,2), so it stops at y=103 and the strip underneath is still
on screen.

So the buttons stay up, and the hand on `ITEM` goes **hollow**: the same
marker every list in this game leaves on the row it is acting on. No filled
hand is drawn anywhere, because the cursor is not in the grid any more.

That state is deliberately **not** claimed. Returning `false` for the battle
would take the bag's own boxes with it — `How many?`, the `YES`/`NO`, the use
message — because every box above a battle inherits the battle's answer. So
the engine keeps drawing its empty box and the buttons go over the top of it,
which lands in the same pixels: the four button boxes tile exactly the
twenty-by-six that box occupies.

`PKMN` reaches the same code and is never seen down it — `PartyMenu` is
opaque, so the stack stops drawing at it and the battle underneath, this
overlay included, never runs at all.

### What two columns inside 160 pixels costs

A classic cell is the box's eight interior tiles less the one kept for the
cursor: **seven glyphs**, where the vanilla list had fourteen. So long move
names are cut, with the engine's own trailing-dot idiom:

| | |
| --- | --- |
| `QUICK ATTACK` | `QUICK.` |
| `THUNDERSHOCK` | `THUNDE.` |
| `SAND-ATTACK` | `SAND-A.` |

That is the real price of the layout, and it is paid back rather than hidden.
The panel above the grid carries the highlighted move's name, its type and its
PP — which the vanilla list never showed all at once either.

The panel stands where the vanilla `TYPE/PP` box stood, `(0,8)`, and is
fourteen tiles by five: twelve interior glyphs, which is exactly the length of
Gen 1's longest move name, so it never cuts. Name, type and PP each get a row
of their own. Fourteen is the narrowest that can promise that, and it stops 48
pixels short of the full width — which keeps it clear of the player's own HP
numbers on the right.

### The type is coloured, and so are the names

The move's type reads in that type's own colour in the panel, and each
button's move name reads in its own — so the grid is four types at a glance
and the panel says which one the cursor is on.

The letters themselves are coloured, not a field behind them. That takes a
shader: a tile glyph is black on transparent, so `setColor` cannot tint one,
and the way through is to throw the glyph's RGB away and keep only its alpha.
The glyph becomes a stencil and the stencil is filled with the type's colour —
same tile sheet, same font, same pixels, different ink.

The palette is darker than the familiar type colours, because these are
letters on a white box rather than a chip behind them; `ICE` and `ELECTRIC` at
their usual brightness are close to unreadable as text. A host with no
`love.graphics.newShader`, and a type this mod has no colour for, both draw
plain black. **`TYPE COLOUR`** turns it off.

### Which is why there is a second font

The tile font is 8 pixels a glyph and cannot be anything else: it is a tile
sheet. A cell is seven of them. So in the game's own font a 2×2 grid **cannot**
print `SELFDESTRUCT`, whatever the boxes do.

A move menu whose names do not all fit is drawn in **Plain Pixel** instead —
the TTF the engine already ships for its translation mode. Its advance is
narrower, and the same cell holds twelve of it. The engine's own whole-game
TTF mode is *not* switched on; the face is loaded and used for move names
alone. The size is chosen rather than fixed: the largest one whose twelve
glyphs still fit wins.

A grid takes it for **all four names or none** — `GUST` in one font beside
`THUNDERSHOCK` in another reads as a fault, not a choice. So a party whose
names all fit is vanilla to the pixel, the command menu never moves, and the
wide layout never reaches for it. **`FULL NAMES`** — off by default, because
the panel above already reads the whole name in the game's own font — turns it
on.

**`MOVE PANEL`** in the mod manager turns the panel off and gives the picture
behind it back.

### Widescreen too

`OPTION` → `BATTLE LAYOUT` → `WIDE` gets the same grid, built differently.

Five tile rows is what that layout's strip has, and six do not fit in five
without eating a row of battlefield. So instead of four boxes it is **one box
ruled into four cells** with its own border glyphs — five rows being exactly
border, text, rule, text, border. Same grid, same cells, one shared frame
instead of four.

The wide cells are twelve glyphs, which is what that layout's own move grid
already gave, so names arrive whole there and nothing is cut. Its
`What will X do?` prompt keeps the left half of the strip, and the move
panel keeps its ten tiles on the right.

### The XP bar

Gen 2 draws an experience bar in its own player HUD; Gen 1 has none, and this
is the Gen 1 substitute. It fills as the highlighted Pokémon earns experience,
runs the Gen 2 fill-hold-burst-refill on a level up, and takes the palette's
own shade unless a colourised mode wants Gen 2's blue.

It was **Gen1WildQOL**'s until 1.3.0, and it is here because of what being
here fixes.

Over there it was drawn by a wrapper around `battle.draw` — and `battle.overlay`,
this mod's only way onto the screen, is the *last hook inside* that function.
So the bar drew after every link on that hook, at any priority. It could not
be drawn over. What it did instead was clip itself to `x=88`, which is where
the **vanilla** move panel ends; this mod's panel ends at 112, and those
twenty-four pixels were a blue line lying across the `PP` row every time a
move menu was up. Raising this mod's hook priority — which 1.2.1 did — changed
nothing, because priority was never what decided the order.

In one file there is nothing to decide. The bar goes down first and the grid
second, so the panel covers it the way it covers anything else beneath it, and
a panel that changes width takes the covering with it. **`XP BAR`** turns it
off.

### The level-up box comes up over the line, not after it

Level up in a battle and the engine prints `IVYSAUR grew to level 28!`, waits
for a press, **clears it**, and only then opens the `ATTACK`/`DEFENSE`/`SPEED`
/`SPECIAL` window — over an empty text box, with nothing left on screen saying
what those numbers belong to. Two screens and two presses.

The ROM prints one. `GrewLevelText` ends in `text_end` rather than `prompt`,
so `PrintText` returns without ever blinking the arrow, and `PrintStatsBox`
draws its window into the screen that line is *still on*; the button press
that follows dismisses the pair together.

So the line is re-marked as what the ROM makes it — the engine's own `auto`
row kind, the one the used-move line rides through its animation, which leaves
the typed page drawn under whatever runs next — and the level-up jingle moves
onto the stat box, which is the beat `sound_level_up` lands on anyway. Nothing
is queued and nothing is inserted: the two rows the engine already made come
back with two flags moved between them, so everything queued after them stays
exactly where it was. **`LEVEL-UP BOX`** turns it off and gives the engine's
two screens back.

### The ball you threw is the ball you see

Under **`COLORS = ADVANCED`** every sprite in a battle takes its colour from
the SGB zone underneath it, and a thrown ball is a sprite like any other — so
a `GREAT BALL` and an `ULTRA BALL` came out the same colour as each other and
as the grass behind them. Now the toss, the wobbles and the ball resting
through the caught text are each ball's own colours: red, blue, gold, purple,
olive.

There is one place that is decided — `BattleState:animSpriteColors`, the funnel
`drawAnimLayer` builds its colour function from for the playing animation and
the resting ball alike — so there is one wrap, and it hands the engine's own
answer straight back for every sprite that is not a ball.

**The band along the seam is a third colour a two-tone sprite does not have.**
The ball tiles do use all three opaque DMG indices — the bottom crescent, the
body mass, the outline ring — but vanilla's `rOBP0` shade map collapses two of
them onto one shade, and the pixels a real Poké Ball's band runs through are
*body* pixels, indistinguishable from the rest of it. So the band comes with
re-indexed art: a copy of the sheet in which those pixels move onto index 3 and
the outline ring moves onto 2. Painted `{ accent, body, line }` that is the
band; painted `{ accent, body, body }` it is pixel-identical to vanilla, which
is what a ball with no band and a player with **`BALL BAND`** off both get.

That copy is rebuilt at runtime from **your own** extracted sheet. This art is
ROM-derived, the engine is built so Nintendo's graphics come out of your
cartridge and are never redistributed, and a mod has no business being the
exception: what ships here is a table of which pixels play which part.

The `MASTER` and `ULTRA` tosses keep their palette strobe, in their own
colours now — and the band holds still through it, because `OBJ_SHADES` leaves
index 3 on the dark shade in both halves of the flash. Poof clouds and every
other battle animation are left exactly as vanilla, and so is every colour
mode that is not `ADVANCED`: those deliberately have no per-sprite colour to
give, and their `nil` is passed straight through.

### Not at the Pokémon Center, and why

Pokeball Colors lights each ball in the heal machine in the colours of the
ball that Pokémon was caught in. That is not here, and it is the one piece of
it that was deliberately left behind rather than simply scoped out.

**Gen 1 does not record what caught a Pokémon.** Not in the engine, and not in
the ROM it is a recompilation of: the party structure is species, HP, status,
types, catch rate, moves, OT, exp, stat exp, DVs, PP and level, and there is
no ball anywhere in it. Caught data arrives with Gen 2; a real per-Pokémon
ball field arrives with Gen 3.

So the machine cannot be *told* which ball to light. It can only be told by a
field the mod invents, writes at catch time, and leaves in your save forever,
on every Pokémon you ever catch. That is a bigger thing than the feature it
buys — a battle UI mod should be removable, and a save still carrying a field
this mod made up long after it is uninstalled is not that.

The battle is different, and that is the whole point: there the engine already
knows which ball is in flight, for exactly as long as it is in flight. Nothing
has to be written down. This mod subscribes to no catch, owns no field on a
Pokémon and adds no byte to your save.

If you want the Center, **Pokeball Colors** does it, and owns the
`mon.caughtBall` field that makes it possible. Install it and this mod's ball
colouring stands down in its favour.

### Where this came from, and what was left behind

The colours and the two seams are **[Pokeball
Colors](https://github.com/mistermiracle3036/Pokeball-Colors)** by Mister
Miracle (MIT), ported down to what Red, Blue and Yellow actually ship: the five
native balls and nothing else.

Left behind on purpose: its `registerColors` and `registerColorResolver`
registries, the colours it keeps for **Custom Poké Balls**, **Too Many Balls**
and **Snag Quest**, its Gold heal machine, its dev toggle that stocks every
ball in every mart — and its Pokémon Center, for the reason above. A ball from
a mod is that mod's business, and that mod is where it is answered — **install Pokeball Colors and this file stands down
whole**, colours and Center and all, rather than the two of them wrapping one
funnel and arguing about it.

---

## Options

| Row | Default | What it does |
| --- | --- | --- |
| `MOVE PANEL` | on | The name, type and PP of the highlighted move, above the grid, where the vanilla `TYPE/PP` box stood. Off gives the picture behind it back — and, on the wide layout, gives its tiles to the grid, because a strip that stops short of the screen edge is a hole in the frame rather than a saving. |
| `XP BAR` | on | A Gen 2 style experience bar under your Pokémon, filling towards the next level, with Gen 2's fill-hold-burst-refill on a level up. Drawn before the move panel, so the panel covers it rather than the other way round. |
| `TYPE COLOUR` | on | The type in the panel and each move name on its button, in that type's own colour, drawn through a shader that inks the game's own glyphs. Off is plain black text. |
| `LEVEL-UP BOX` | on | The level-up stat window over the `grew to level` line rather than after it, dismissed together, the way `text_end` + `PrintStatsBox` prints it in the ROM. Off is the engine's two screens, with the text box under the window blank. |
| `BALL COLOUR` | on | The ball you throw in its own colours — the toss, the wobbles and the ball resting through the caught text — for the five balls Red, Blue and Yellow ship with. `COLORS = ADVANCED` only; the mono modes have no per-sprite colour to give and are passed through whatever this says. |
| `BALL BAND` | on | The black band along a thrown ball's seam, which needs the re-indexed art to have a third region to paint. Off is the two-tone ball on the game's own tiles, which is what a thrown ball looked like before it. |
| `FULL NAMES` | off | Move names in the engine's Plain Pixel when they will not fit the tile font, so they print whole in the buttons too. Off — the default — is the game's own font always, cut to the cell, and the panel above is what reads the whole name. |

---

## What it does not touch

- **The HP panels, the pictures, the animations** — with the one deliberate
  exception of the XP bar, which is drawn under the player's HP numbers
  because that is where Gen 2 puts its own.
- **What the menus do.** Only where they are drawn. Every index, every key,
  every callback is still the engine's, so anything wrong with what the battle
  menu *does* is not this mod.
- **Dialogue, and everything above it.** The text box, its scroll, its
  wait arrow, and every screen pushed over the battle — with the one
  deliberate exception of the level-up line, which is re-marked as the
  ROM's own `text_end` page so its stat box can come up over it rather
  than after it.
- **The HP panels, the pictures, the animations.** The whole top of the
  screen is untouched.

## Known

- **Seven glyphs is seven glyphs in the tile font,** and no arrangement of two
  columns inside 160 pixels changes that. `FULL NAMES` is the way out and it
  is a second face, not a cleverer layout; turning it off puts the cut back.
- **The small face is not the game's font,** so a font mod or a skin that
  redraws the tile sheet does not reach it — unlike the boxes, which are
  `Font.drawBox` and do. That is the trade `FULL NAMES` makes.
- **`THROW ROCK` is cut in a Safari battle** — ten glyphs against seven. It
  reads `THROW.`, with the trailing space taken off the cut rather than left
  as `THROW .`. The wide layout has room and prints it whole.
- **The colour needs a shader,** which is the one thing here that a host can
  simply not have. Without `love.graphics.newShader` the letters are black and
  everything else is unchanged — which is the picture this mod drew before it
  had any colour at all.
- **The overlay draws after the palette pass,** so the buttons are black on
  white and are not recoloured by a `COLORS` zone the way the vanilla strip's
  border is. On the default look this is the same picture; under a mode that
  tints the text box it is not.
- **The level-up jingle loses `WaitForSoundToFinish`,** because the stat box
  it now rides in with parks the queue itself until you dismiss it, which is
  the clear window that wait was there to give it. Mash through the box fast
  enough and the next line can start over the tail of the jingle.
- **A `RARE CANDY` outside a battle is unchanged.** That level-up is the
  party menu's, printed through the map's own text box, and this is a battle
  mod.
- **The first ball of a session has no band.** The re-indexed sheet is only
  safe to serve once this mod's palette has been seen to reach a ball, because
  anything that blits it raw draws a grey ball with a black stripe — which is
  exactly what a sprite pack that ships its own pre-coloured ball art and
  suppresses the palette pass does. So the first throw is the two-tone ball and
  the band arrives with the second; and if that contradiction ever does turn
  up, the band switches off for the session and the other mod's own artwork
  shows through, which is the right outcome — their balls are already coloured.
- **A ball from another mod keeps its vanilla colours,** and says so once in
  the log naming the ball. This mod covers the five native balls; Pokeball
  Colors is the mod that covers the rest, and installing it stands this one
  down entirely.
- **The `ULTRA BALL` looks like it turns over during the toss.** That is the
  Master/Ultra palette flicker, which is on the hardware, in the ball's own
  colours now — and it stops at the wobbles because `SHAKE_ANIM` never
  flickers.
- **The Pokémon Center is not coloured,** and will not be. Knowing which ball
  caught a Pokémon means inventing a field Gen 1 never had and leaving it in
  your save forever; the battle needs no such thing, because the engine knows
  which ball is in flight while it is in flight. Pokeball Colors is the mod
  that does the Center.
- **A throw while drawing costs a frame's buttons, not the battle.** The draw
  is wrapped and logged; a load-time failure is *not* swallowed, and marks the
  row enabled-but-broken in `MODS` with the reason, because an enabled mod
  that silently changes nothing looks exactly like one that was never
  installed.

---

## Install

**MODS** → **Import mod .zip**, or add the index at **MODS** → **FIND MODS**:

```
wild1walker/Gen1Wild
```

## Credits

- **Gen1Recomp** — the battle hooks this is built on: `battle.overlay`,
  `battle.bottom_ui_visible`, `battle.move_grid_navigation` and
  `battle.exp_award` were already there, and this mod is what happens when a
  mod uses all four.
- **pret/pokered** — `engine/battle/core.asm`, whose `DisplayBattleMenu` and
  `MoveSelectionMenu` are the two screens this re-dresses, and whose 2×2
  reading of `menuIndex` is why the command menu needed no new input handling.
- **Plain Pixel** by Douglas Vautour (CC-BY 4.0), which Gen1Recomp bundles for
  its translation mode and which this mod borrows for move names.
- **[unxpected-uxp](https://github.com/unxpected-uxp/pokemon-gen1-recomp-mod-qol)**
  — the XP bar, from their Quality of Life mod by way of Gen1WildQOL, which
  maintained it and wrote the faint guard it still carries.
- **[Pokeball Colors](https://github.com/mistermiracle3036/Pokeball-Colors)**
  by Mister Miracle (MIT) — the ball colours, the band's re-indexing table and
  both seams the ball colouring is drawn through. Ported here for the five
  native balls; its whole other-mods surface stays over there, and this mod
  stands down when it is installed.
- **Nintendo / Creatures / GAME FREAK** — Pokémon Red, Blue and Yellow.
  Unofficial fan mod, no affiliation, no endorsement.

MIT. See [LICENSE](LICENSE) and
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
