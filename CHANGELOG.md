# Changelog

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
