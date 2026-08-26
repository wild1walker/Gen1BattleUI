# Changelog

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
