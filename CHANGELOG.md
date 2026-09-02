# Changelog

## 1.7.0

- **The XP bar draws on a voxel mod's battle again.** A voxel fork draws the
  fight in 3D over the map and moves the HUDs onto its own window-sized world
  canvas. A bar left behind in the GB frame is a blue line floating in the
  wrong place; a bar drawn in 160x144 coordinates onto a window-sized canvas is
  worse. So the bar asks, every frame, whether the HUDs really were moved this
  frame, and follows them onto the fork's canvas when they were.

  The answer is no unless a fork explicitly says yes: with no voxel mod, and
  under a fork that leaves the HUDs in the frame, the classic path runs
  unchanged. A fork that moves them but publishes no geometry gets no bar for
  the frame rather than a bar guessed onto the wrong canvas. The canvas is put
  back even if the paint raises, so a bar that fails once cannot leave the rest
  of the battle drawing into the world image.

  This needs `mod.voxel`, which the Gen1WildUI bundle supplies. Standalone it
  is absent, every use is guarded, and the classic path is what runs.

- **No line across the move panel's PP row.** The panel is drawn after the bar
  and covers it, and drawing the bar first was taken to be the whole fix. It is
  the whole fix for the pixels and not for the mark: `markTrueColor` re-blits
  its region **raw** after the pass composes, so the length of bar lying under
  the panel came back on top of it, as a line across the PP row. Draw order
  cannot reach that. The bar now stops where the panel starts and marks only
  what it drew. The panel is fourteen tiles and the bar runs to 147, so the bar
  is shorter, never absent.

- **The type line's mark no longer clips the top of PP.** A full-height mark's
  surrounding art zone is one pixel larger than the mark, which put its bottom
  edge on the PP line's first pixel row and mapped that row's ink to black.
  Marks that own a text row now use `C.MARK_ROW`, one shorter than the row, so
  the ring lands inside the row it belongs to.


## 1.6.1

- **The XP bar no longer shows through the level-up pop-up.** `battle.overlay`
  fires whenever the battle *draws*, and the battle keeps drawing while another
  state is on top of it — that is how the level-up stat window appears over the
  fight rather than over nothing. For most of what this mod draws that costs
  nothing, because the state above draws second and covers it. The bar is the
  exception: the wide layout's fill is marked `trueColor`, and a `trueColor`
  rectangle is spliced onto the pass's zone list and re-blits its region **raw**
  once the pass is composed. The battle and everything pushed over it share one
  pass and one canvas, so that strip came back over the window.

  The bar now stands down while anything is standing on the battle. A stack it
  cannot read leaves the bar drawn — this is a guard against covering
  something, not a licence to blank the HUD if the shape of the game is not
  what is expected here.

Every reason the bar has not to draw is collected into `XP.wouldDraw`, published
as `mod.exports.xpBarWouldDraw`, so the question can be asked without a canvas
to answer it on.

## 1.6.0

Gen1WildUI carried this as an overlay while it was ahead of a release here; it
shipped in the bundle's 1.22.0. Same code, in the mod that owns it.

- Coloured ink on a themed battle box leaves the palette pass instead of coming
  out grey. `C.onDark` lays the matte, lifts the colour and hands back the mark;
  it answers nil anywhere that is not a `DARK` `ADVANCED` build, so nothing
  changes on any other build — and with no theme provider installed there is no
  `DARK` build to be on, which is every standalone install.
- `C.faceHeight` measures the small face rather than assuming a tile row, so a
  coloured label claims the rectangle it actually occupies.

**Inert standalone**, like the matte changes in the box and party screens: the
code is here so it lives with the feature rather than in a bundle's overlay.

## 1.5.2

- **The level-up stat box came up over a blank text box again when Gen1WildQOL's
  `EXP SHARE` was on.** Reported from device with a screenshot: the exact
  picture 1.4.0 was written to fix, back for anyone running both mods.
- **It was a hook priority, not the retiming.** `Hooks` sorts a chain
  highest-first and runs the first link *outermost*
  (`src/mods/Hooks.lua:26`), and an unprioritised link is `priority or 0`.
  Gen1WildQOL's EXP SHARE wraps `battle.exp_award` at **priority 90** and, in
  every mode except `OFF`, awards the exp itself and returns **without calling
  `nextFn`** — so this mod's link sat inside it and never ran at all. The rows
  were queued exactly as vanilla queues them and never re-marked, which is the
  engine's own two screens: the line prompts, clears, and the stat box arrives
  over an empty box.
- **This link is now outermost (priority 5000).** It calls `next()` and then
  *reads* what the chain queued, so it has to be the link the chain starts at
  — an inner link cannot read a queue built by an outer one that never called
  through. It costs the other mod nothing: `next(ctx)` is still what awards the
  exp, theirs when they are the ones doing it, and its result is handed
  straight back. Their award goes through the engine's own `ctx.applyShare`, so
  the rows are the same rows and the retiming finds them.
- **And it no longer fails silently.** A miss now logs how many level-up lines
  were joined, how many were expected, and the exact text it could not match —
  because "reached and found nothing" and "never reached at all" produced the
  same blank box, and neither said so.
- The suite gained the case that was missing: a link above this mod's that
  queues the award's own rows and never calls on, asserted to still come out as
  one screen. It fails without the priority. Modelled on how that mod behaves
  rather than named after it, so any other mod that owns the award the same way
  is the same test.
- **The suite's award helper was also circular** and is fixed: it hand-built
  the queue as two literal rows instead of letting the engine build it, so it
  was checking this mod against its own assumption rather than against
  `sayNextWaitSfx`/`uiNext`.

## 1.5.1

Drops `gen1_wild_ui` from `optional_dependencies`. It could never be
satisfied: [Gen1WildUI](https://github.com/wild1walker/Gen1WildUI) carries this
mod as its `BATTLE MENUS` feature and lists `Gen1BattleUI` in its `conflicts`,
so the two are mutually exclusive by design and the engine will not have both
installed for the optional dependency to find. The entry predates that
conflict.

It is also what every other mod in the suite does: the bundle names the
standalone it absorbs, and the standalone says nothing about the bundle.
Nothing else changed.

## 1.5.0

- **The ball you throw is coloured as itself.** Under `COLORS = ADVANCED`
  every sprite in a battle takes its colour from the SGB zone underneath it,
  and a thrown ball is a sprite like any other — so a GREAT BALL and an ULTRA
  BALL came out the same colour as each other and as the grass behind them.
  The toss, the wobbles and the ball resting through the caught text are now
  each ball's own: red, blue, gold, purple, olive.
- **And at the Pokémon Center.** The heal machine lit one ball per party
  member and painted all six the same; each one is now the ball that Pokémon
  was *caught* in. Written only into an empty field and never over one, which
  is the rule that lets it share a save with the mod it came from. Anything
  caught before this installed heals as a POKE BALL and corrects itself as the
  party turns over.
- **That one feature writes to your save, and it is the only thing in this mod
  that does.** Gen 1 records nothing about what caught a Pokémon — not in the
  engine, and not in the ROM it recompiles, whose party struct is species, HP,
  status, types, catch rate, moves, OT, exp, stat exp, DVs, PP and level with
  no ball anywhere in it. Nor does Gen 2 — Crystal's caught data is time,
  level, location and OT gender — and Gen 3 is the first generation to record
  the ball at all, as four bits in the Misc substruct's origins halfword. So
  the machine can only be told by a field the mod invents.
  `mon.caughtBall` goes onto the Pokémon, and a Pokémon *is* `save.party[i]` —
  `SaveSerializer` writes every key it finds — so it lands in the save beside
  `species` and `dvs` and stays there after an uninstall. One string per
  Pokémon caught. It is a Lua key on a mon table, which is this engine's idiom
  for every other field too, but it maps to no byte in the real Gen 1 format:
  `GenSave.encodeMon` writes fixed offsets from a known field list, so an
  export to a 32768-byte `.sav` drops it and a round trip lights every ball
  red until the party turns over.
- **The namespaced alternative was considered and turned down.** `mod.save`,
  backed by `save.modData["Gen1BattleUI"]`, would vanish cleanly with the mod
  — but a side table needs a key, and a Gen 1 Pokémon has no unique id. The
  best available keys are a content fingerprint (OT id, nickname, DVs) that
  can collide and a party slot that cannot survive a deposit. A field *on* the
  Pokémon needs no key: it goes where the Pokémon goes, through the box and
  through a trade. It is also the field Pokeball Colors already owns, by the
  same only-if-absent rule, which is what lets the two share a save.
- **Ported from [Pokeball
  Colors](https://github.com/mistermiracle3036/Pokeball-Colors)** by Mister
  Miracle (MIT), cut to what Red, Blue and Yellow actually ship: the five
  native balls. Its `registerColors` and `registerColorResolver` registries,
  its colours for Custom Poké Balls, Too Many Balls and Snag Quest, its Gold
  heal machine and its every-ball-in-marts dev toggle are all deliberately
  left over there. **Install that mod and this one stands down whole** —
  colours, Center and all — rather than the two of them wrapping one funnel
  and arguing about it.
- **The band along the seam is a third colour a two-tone sprite does not
  have.** The ball tiles do use all three opaque DMG indices, but vanilla's
  `rOBP0` map collapses two of them onto one shade, and the pixels a real
  Poké Ball's band runs through are *body* pixels. So the band comes with
  re-indexed art — the seam onto index 3, the outline ring onto 2 — rebuilt at
  runtime from **your own** extracted sheet, because this art is ROM-derived
  and the engine is built so it never leaves your cartridge. Painted
  `{ accent, body, body }` that sheet is pixel-identical to vanilla, which is
  what `BALL BAND` off gives back.
- **One correction to what was ported.** `OBJ_SHADES` maps index 3 to the dark
  shade in *both* halves of the Master/Ultra flicker, so the outline ring does
  not take part in the flash. The original works its fallback out after the
  swap, so a ball with no band renders that ring in its accent for the flashed
  frames — and of the five native balls the one with no band is the ULTRA
  BALL, which is also one of the two that flicker. Here the band and its
  fallback are both taken from the unswapped body and only the pair swaps.
- **`BALL COLOUR`, `BALL BAND` and `CENTER BALLS`** in the mod manager, all on
  by default. `ADVANCED` only, throughout: the mono modes deliberately have no
  per-sprite colour to give, and their `nil` is passed straight through.
- The suite drives the engine's own `ballChain` and `AnimPlayer.start` and
  reads the colours back out of `animSpriteColors`, so "every sprite that is
  not a ball comes back exactly as the engine coloured it" is checked against
  the engine's own answer rather than asserted.

## 1.4.0

- **The level-up stat box comes up over the line that announced it.** Reported
  as "the stat pop-up shows with the chat box blank" — and it did: the engine
  queued `X grew to level N!` as a prompt row and the stat window as the row
  behind it, so the line was dismissed and cleared before the window was
  pushed. Two screens, two presses, and the second one with nothing on it
  saying what the numbers belonged to.
- **The ROM prints one screen.** `GrewLevelText` ends in `text_end` rather than
  `prompt` (`engine/battle/experience.asm:369-372`), so `PrintText` returns
  without blinking the arrow and `PrintStatsBox` draws into the screen that
  line is still on; the press that follows takes both away.
- **So the line is re-marked, not redrawn.** It becomes the engine's own
  `auto` row — the kind whose path sets `msgHold`, which is exactly "the typed
  page stays drawn behind whatever runs next" — and the level-up jingle moves
  onto the stat box's own factory, because the auto path never asks a row for
  its sound. It rings once, as the box opens, which is where
  `sound_level_up` rings in the ROM.
- **Nothing is queued and nothing is inserted.** The queue's own inserts are
  positional, and the exp award is not the last thing a faint queues — the
  trainer's `sent out X!` goes in afterwards, by position. A row added in the
  middle of the exp rows would have slid that line into the middle of them
  too. Two flags moved between two existing rows move nothing.
- The rows are named by their **text**, built through the same `Strings` call
  the engine builds them with from the levels `battle.exp_gained` announces:
  "a message carrying a sound in front of a UI row" is also `X learned MOVE!`
  in front of the forget menu, and that one keeps its prompt.
- **`LEVEL-UP BOX`** in the mod manager, on by default; off is the engine's
  two screens.
- The suite drives the engine's own `updateQueue` and `drawTextArea` over both
  cases, so "the box under the stat window is not blank" is checked as the
  glyphs that actually go down in it.

## 1.3.0

- **The XP bar lives here now.** It was Gen1WildQOL's — one of the four
  features that mod carries from unxpected-uxp's Quality of Life. It is a
  battle UI feature and this is the battle UI mod, and moving it is what
  actually fixed the bug 1.2.1 and 1.2.2 both failed to.
- **Which was that the bar lay across the move panel.** From over there it was
  drawn by a wrapper around `battle.draw`, and `battle.overlay` — this mod's
  only way onto the screen — is the *last hook inside* that function. So the
  bar drew after every link on it, at any priority. It could not be drawn
  over. 1.2.1 raised this mod's hook priority to fix it and that did nothing,
  because priority was never what decided the order.
- Unable to be drawn over, the bar clipped itself instead: to `x=88`, which is
  where the **vanilla** move panel ends. This mod's panel ends at 112. Those
  twenty-four pixels were the blue line on the `PP 27/35` row.
- **Here there is no clip.** The bar and the grid go down in one function, bar
  first, so the panel covers it exactly as far as the panel reaches — and a
  panel that changes width takes the covering with it, which is the property
  no clip could have had.
- The numbers, the level-up fill-hold-burst-refill and the wide layout's
  boxed-and-labelled version are ported as they were, as is the guard that
  stops the bar once your Pokémon faints and the engine clears the HUD out
  from under it. **`XP BAR`** turns it off; on is what it was over there.
- **The 3D-battle path is not carried over.** It drew into another mod's
  canvas through a handshake with that mod's `snapHUDs`, and the handshake was
  what decided whether the path was taken. Ported without it, it would be
  taken whenever that mod was loaded — worse than not having it at all.
- **`mod.exports.panelRect(battle)`** publishes the panel's rectangle in game
  pixels, for anything else that draws after this mod and must not be drawn
  over. `nil` means nothing of this mod's is up there.
- **The published tile geometry is no longer a second copy.**
  `geometry.classic.panel` is the table the drawing reads. It had said eleven
  tiles ever since 1.2.1 made the box fourteen — a stale number is exactly
  what makes a neighbour clip to the wrong place, which is the shape of this
  whole release.

## 1.2.2

- **The colour is in the letters now, not behind them.** 1.2.1 put the type on
  a coloured chip because a tile glyph is black on transparent and `setColor`
  cannot reach it. It can be reached — with a shader that throws each glyph's
  RGB away and keeps only its alpha, so the glyph becomes a stencil and the
  stencil is filled with the type's colour. Same tile sheet, same font, same
  pixels; different ink. No chip is drawn any more.
- **The move names on the buttons are coloured too, by their own type.** So
  the grid reads as four types at a glance and the panel says which one you
  are on. The panel colours the word `FIRE`; the buttons colour the names.
- The palette is darker than the familiar type colours, because these are the
  letters rather than a field behind them — `ICE` and `ELECTRIC` at their
  usual brightness are close to invisible as text on a white box.
- `FULL NAMES` takes the same ink without going near the shader: a TTF glyph
  really is drawn in the current colour.
- A host with no `love.graphics.newShader` draws the letters black and loses
  the colour, which is the picture this mod drew before it had any. A type
  this mod has no colour for — a mod's own — is left black as well.
  **`TYPE COLOUR`** turns the whole thing off.

## 1.2.1

- **The panel reads the move name whole again, and is three rows.** 1.2.0 cut
  it to eleven tiles, which cut names with it — `QUICK ATTACK` became
  `QUICK AT.` That was me over-correcting a report about the EXP bar into a
  report about the HUD. Name, type and PP now each get their own row.
- **Fourteen tiles wide, not twenty.** Twelve interior tiles is twelve glyphs
  of the game's own font, and Gen 1's longest names are exactly twelve — so
  fourteen is the narrowest the panel can be and still never cut. That is 48
  pixels short of the full width it used to run to.
- **The EXP bar no longer lies across the panel.** Narrowing was only half of
  it: another mod draws that bar and drew it *after* this panel. The overlay
  hook now carries a priority that puts this mod's link outermost, and since
  it calls `next()` before it draws, outermost means drawn **last** — so the
  panel covers what it overlaps instead of being covered.
- **The type sits on a chip in its own colour.** Behind the word, not in it: a
  tile glyph is black on transparent and comes out black whatever colour is
  set, so tinting the letters would mean giving up the game's own font for
  them. A type the table does not know — a mod's — simply gets no chip.
  **`TYPE COLOUR`** turns it off.
- **`FULL NAMES` now defaults off.** The buttons are the game's own font, cut
  to the cell, which is what the 2×2 has always looked like; the panel above
  is what reads the whole name. On is still there for anyone who wants the
  names whole in the buttons too.

## 1.2.0

- **Move names print whole.** The tile font is 8 pixels a glyph and a classic
  cell is seven of them; Gen 1's longest move names are twelve. That is
  arithmetic about an 8x8 sheet, not a layout that could be tuned — in the
  game's own font, a 2x2 grid *cannot* show `SELFDESTRUCT`.
- So a move menu whose names do not all fit is drawn in **Plain Pixel**, the
  TTF the engine already ships for its translation mode (`Font.PLAINPIXEL`,
  CC-BY 4.0, Douglas Vautour). Its advance is narrower, and the same cell
  holds twelve of it. The engine's own whole-game TTF mode is *not* switched
  on — that is a font swap for the whole game, and a battle mod has no
  business making one; the face is loaded and used for move names alone.
- The size is chosen, not fixed: the largest one whose twelve glyphs still fit
  the cell wins, so a different cell width or different font metrics resize it
  rather than overflow it.
- **A grid takes the small face for all four names or none.** `GUST` in one
  font beside `THUNDERSHOCK` in another, in the same four boxes, reads as a
  rendering fault rather than a choice. A party whose names all fit is still
  vanilla to the pixel, the command menu never moves, and the wide layout —
  twelve glyphs a cell already — never reaches for it at all.
- The panel takes the **cells'** face, sized from the cell: chosen from the
  panel's own width instead, the same name came out larger up there than on
  the button it describes.
- **`FULL NAMES`** in the mod manager, on by default. Off is the game's own
  font always, and names are cut to the cell as before.

## 1.1.2

No change to the mod. 1.1.1's tag carried a stray `mods/Gen1BattleUI` gitlink
— a copy of this repo committed inside itself from a test-harness copy run in
the wrong directory. `git archive` skips gitlinks, so the 1.1.1 archive was
never affected and neither was anything installed from it; what it broke was a
**recursive** clone of the tag, which is how Gen1WildUI checks this repo out
as a submodule:

```
fatal: No url found for submodule path 'upstream/Gen1BattleUI/mods/Gen1BattleUI'
```

Removing it from `main` did not fix the tag, so this is a clean tag to pin to.
`mods/` is now in `.gitignore`.

## 1.1.1

- **The move panel no longer covers the player's HP.** 1.1.0 drew it twenty
  tiles wide across rows 8-11; `DrawPlayerHUDAndHPBar` puts the name, level,
  HP bar, HP numbers and underline across rows 7-11 from x=72 rightwards, so
  the panel wiped every one of them but the name. Choosing a move is the one
  moment that screen exists to inform, and it was the moment your own HP went
  away.
- The panel now keeps the footprint of the vanilla box it stands in for:
  `(0,8)` 11x5, `PrintMenuItem`'s TYPE/PP box, with the name, type and PP on
  its three interior rows. That is also what keeps everything *else* clear --
  anything another mod draws on that side of the screen, an EXP bar included,
  was laid out around the vanilla box and not around this one.
- The cost is the name: nine glyphs where 1.1.0 had eighteen, against the
  cell's seven. `QUICK ATTACK` reads `QUICK AT.` in the panel and `QUICK.` on
  the button.
- Mimic's panel keeps `.mimicmenu`'s `(0,7)` box and takes two tiles more than
  its 16 -- that box already covers the HP bar and numbers in vanilla, so the
  rule above was never one that screen kept, and the two tiles are what give
  `WHICH TECHNIQUE?` its sixteenth glyph.
- A test now asserts the rule directly: above the button strip, nothing this
  mod draws may reach the column the HP numbers start in.

## 1.1.0

- **`ITEM` no longer clears the buttons away.** The bag's item list is the one
  list in the game that is not a screen of its own — `ListMenu`'s `itemBox`,
  `isOpaque = false`, sixteen tiles at (4,2), so it stops at y=103 and the
  strip underneath it stays on screen. `openItems` sets the phase to
  `messages` with nothing to say, so what was drawn down there was the
  engine's empty text box. Now the menu it was opened from stays up, with the
  hand left **hollow** on `ITEM` — the same marker every list in the game
  leaves on the row it is acting on.
- That state is deliberately **not** claimed through
  `battle.bottom_ui_visible`. Returning `false` for the battle would take the
  bag's own boxes down with it — `How many?`, the `YES`/`NO`, the use message
  — because every box above a battle inherits the battle's answer
  (`src/battle/UIVisibility.lua`). The engine keeps drawing its empty box and
  the buttons go over the top of it, which lands in the same pixels: the four
  button boxes tile exactly the twenty-by-six that box occupies.
- `PKMN` reaches the same code and is never seen down it: `PartyMenu` is
  opaque, so the stack stops drawing at it and the battle underneath — this
  mod's overlay included — never runs.
- The two cursors now come from the engine's own `Theme.cursor` and
  `Theme.cursorHollow` rather than being written out here, so a skin that
  restyles the arrow restyles these with it.

## 1.0.0

First release.

- The battle command menu is four bordered buttons in a 2×2 grid instead of
  four words in one box: `FIGHT` and `PKMN` on the top row, `ITEM` and `RUN`
  on the bottom. Four 10×3 boxes tile the classic layout's twenty-by-six
  bottom strip exactly, and a button is `Font.drawBox` — the game's own text
  box — so a skin or a font mod redraws them with everything else.
- The move menu is the same grid. It was a vertical list, so this one needed
  the engine's `battle.move_grid_navigation` hook as well to make <kbd>←</kbd>
  and <kbd>→</kbd> cross it; the command menu needed no input change at all,
  because the engine has always read `menuIndex` as a 2×2.
- A panel above the move grid carries the highlighted move's full name, its
  type and its PP, in the place the vanilla `TYPE/PP` box occupied and
  covering what it covered. `MOVE PANEL` in the mod manager turns it off.
- Mimic's copy menu is the same grid, one tile row lower, matching the row the
  engine clips the player's picture to for it.
- Safari keeps its own four: the ball count still rides its button.
- Widescreen (`BATTLE LAYOUT` → `WIDE`) gets the same grid as one box ruled
  into four cells, because five tile rows will not hold two three-row boxes.
  Its cells are twelve glyphs, so move names arrive whole; the
  `What will X do?` prompt and the move panel keep their halves of the strip.
- Dialogue is untouched. Only the three menu phases are claimed, and only
  while the battle is the top of the state stack — so the battle's text box,
  and every prompt belonging to a party or bag screen opened from the menu,
  still draws itself.
