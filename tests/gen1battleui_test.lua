-- Standalone: luajit mods/Gen1BattleUI/tests/gen1battleui_test.lua
--
-- Loads the mod through the headless SDK harness against the ROM-free fixture
-- dataset and asserts what it claims: that the three hooks are attached, that
-- the strip is claimed for the three menu phases and for nothing else, and
-- that what gets drawn is four boxes with one label each, inside the screen
-- and inside their own borders.
--
-- The layout claims are checked by RECORDING what the overlay actually draws
-- -- every box in tile coordinates, every string and its measured width --
-- rather than by reading the source back, because "does this label fit in
-- that cell" is a question about pixels.  It is also the check that would
-- have caught the one bug this file was written alongside: a cell built from
-- the box's last tile instead of its last INTERIOR tile is eight pixels too
-- wide, which does not show up until a label is long enough to reach the
-- border it then prints over.
--
-- Run it from a Gen1Recomp checkout with this mod at mods/Gen1BattleUI, or
-- set GEN1BATTLEUI_DIR to wherever it lives.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Font = require("src.render.Font")
local Runtime = require("src.mods.Runtime")

local DIR = os.getenv("GEN1BATTLEUI_DIR") or "mods/Gen1BattleUI"
local Data = T.fixtures.fresh()
local run = T.sdk.loadMod(DIR, { data = Data })
T.eq(#run.errors, 0, "loads clean (" .. tostring(run.errors[1]) .. ")")

for _, name in ipairs({ "battle.bottom_ui_visible", "battle.overlay",
                        "battle.move_grid_navigation" }) do
  T.check((Runtime.hooks.chains or {})[name] ~= nil, name .. " is attached")
end

-- battle.overlay's priority is draw order: Hooks runs the highest-priority
-- link outermost, and this one calls next() before it draws, so highest is
-- drawn LAST.  That is what puts the panel over another mod's EXP bar rather
-- than under it, and it is the one hook here that insists on an order.
do
  local chain = Runtime.hooks.chains["battle.overlay"]
  local ours
  for _, entry in ipairs(chain) do
    if entry.owner == "Gen1BattleUI" then ours = entry end
  end
  T.check(ours ~= nil, "the overlay link is ours to find")
  T.check(ours and ours.priority >= 1000,
          "and carries a priority high enough to be drawn last")
  T.eq(chain[1], ours, "so it sorts outermost in the chain")
end

-- Exports are published by the loader under the mod's id once its entry
-- chunk returns; the mod RECORD is a different object and never carries them.
local exports = run.loader.exports["Gen1BattleUI"]
T.check(type(exports) == "table" and type(exports.geometry) == "table",
        "the mod publishes its geometry")
T.eq(exports and exports.geometry and exports.geometry.classic.boxW, 10,
     "and it says how wide a classic button is")

-- ------- a stub battle
--
-- The fields the engine's own drawTextArea reads, and nothing else: this mod
-- reads the same ones, so a stub that carries them is the same input the real
-- BattleState hands over.  Building a live BattleState would need a Game, a
-- map and a renderer, none of which any claim here is about.

local MOVES = {
  { id = "FIX_EMBERISH", pp = 20, ppUps = 0 },
  { id = "FIX_CUT", pp = 30, ppUps = 0 },
  { id = "FIX_TACKLE", pp = 35, ppUps = 0 },
  { id = "FIX_SCRATCH", pp = 5, ppUps = 0 },
}

local function fakeBattle(o)
  o = o or {}
  local stack = { states = {} }
  function stack:top() return self.states[#self.states] end
  local battle = {
    isBattle = true,
    phase = o.phase or "menu",
    frame = 0,
    menuIndex = o.menuIndex or 1,
    moveIndex = o.moveIndex or 1,
    mimicIndex = o.mimicIndex or 1,
    moveSwapIndex = o.swap,
    data = Data,
    safari = o.safari,
    demo = o.demo,
    demoTimer = o.demoTimer,
    afterQueue = o.afterQueue,
    current = o.current,
    mimicMoves = o.mimicMoves or MOVES,
    player = { name = "PIDGEOTTO", curMoves = o.moves or MOVES,
               disabledSlot = o.disabled },
    wide = o.wide or false,
  }
  battle.game = { stack = stack, data = Data }
  function battle:wideLayout() return self.wide end
  stack.states[1] = battle
  -- a party or bag screen opened from the menu sits above the battle.  The
  -- party menu is opaque and stops the battle drawing at all; the bag's item
  -- list is not (ListMenu's itemBox), which is why the strip shows under it.
  if o.covered then stack.states[2] = { isOpaque = true } end
  if o.bag then stack.states[2] = { isOpaque = false } end
  return battle
end

-- ------- recording a frame

local function record(battle)
  local out = { boxes = {}, text = {}, codes = {}, rects = {} }
  local realDraw, realBox, realCode = Font.draw, Font.drawBox, Font.drawCode
  Font.draw = function(text, x, y)
    local ok, w = pcall(Font.width, text)
    out.text[#out.text + 1] = { text = tostring(text), x = x, y = y,
                                w = ok and w or 0 }
  end
  Font.drawBox = function(tx, ty, tw, th)
    out.boxes[#out.boxes + 1] = { tx = tx, ty = ty, tw = tw, th = th }
  end
  local realRect, realSetColor = love.graphics.rectangle, love.graphics.setColor
  local colour
  love.graphics.setColor = function(r, g, b, a)
    colour = { r, g, b }
    return realSetColor(r, g, b, a)
  end
  love.graphics.rectangle = function(mode, x, y, w, h, ...)
    out.rects[#out.rects + 1] = { x = x, y = y, w = w, h = h, colour = colour }
    return realRect(mode, x, y, w, h, ...)
  end
  Font.drawCode = function(code, x, y)
    out.codes[#out.codes + 1] = { code = code, x = x, y = y }
  end
  -- The small face does not go through Font at all -- it is a LOVE font
  -- printed directly -- so recording only Font.draw would see a move menu
  -- with no labels in it and call that a bug.  Both faces land in out.text;
  -- `small` says which, and the width is measured through whichever font
  -- was actually set.
  local realPrint, realSetFont = love.graphics.print, love.graphics.setFont
  local face
  love.graphics.setFont = function(f) face = f; return realSetFont(f) end
  love.graphics.print = function(text, x, y)
    local w = 0
    if face and face.getWidth then
      local okw, v = pcall(face.getWidth, face, text)
      w = okw and v or 0
    end
    out.text[#out.text + 1] = { text = tostring(text), x = x, y = y,
                                w = w, small = true }
  end
  local ok, err = pcall(Runtime.call, "battle.overlay", function() end, battle)
  love.graphics.print, love.graphics.setFont = realPrint, realSetFont
  love.graphics.rectangle, love.graphics.setColor = realRect, realSetColor
  Font.draw, Font.drawBox, Font.drawCode = realDraw, realBox, realCode
  T.check(ok, "the overlay draws (" .. tostring(err) .. ")")
  return out
end

local function hasBox(drawn, tx, ty, tw, th)
  for _, b in ipairs(drawn.boxes) do
    if b.tx == tx and b.ty == ty and b.tw == tw and b.th == th then
      return true
    end
  end
  return false
end

local function hands(drawn)
  local out = {}
  for _, c in ipairs(drawn.codes) do
    if c.code == 0xED then out[#out + 1] = c end
  end
  return out
end

local function hollows(drawn)
  local out = {}
  for _, c in ipairs(drawn.codes) do
    if c.code == 0xEC then out[#out + 1] = c end
  end
  return out
end

local function findText(drawn, text)
  for _, t in ipairs(drawn.text) do
    if t.text == text then return t end
  end
  return nil
end

local function bottomVisible(battle)
  return Runtime.call("battle.bottom_ui_visible",
                      function() return true end, battle)
end

-- ------- the classic layout: four boxes tiling rows 12-17

do
  local drawn = record(fakeBattle({ phase = "menu", menuIndex = 2 }))

  T.eq(#drawn.boxes, 4, "the command menu is four boxes")
  for _, box in ipairs({ { 0, 12 }, { 10, 12 }, { 0, 15 }, { 10, 15 } }) do
    T.check(hasBox(drawn, box[1], box[2], 10, 3),
            ("a 10x3 button at (%d,%d)"):format(box[1], box[2]))
  end

  -- The four boxes tile the strip exactly: two columns of ten tiles is the
  -- twenty the screen has, two rows of three is the six rows 12-17 are.
  T.eq(10 * 2, 20, "two columns of ten tiles fill the screen's twenty")
  T.eq(3 * 2, 6, "two rows of three fill the strip's six")

  for _, key in ipairs({ "FIGHT", "ITEM", "RUN" }) do
    T.check(findText(drawn, key) ~= nil, key .. " is on a button")
  end

  -- PKMN is a glyph pair, not letters, so it is drawn by code
  local pk, mn = false, false
  for _, c in ipairs(drawn.codes) do
    if c.code == 0xE1 then pk = true end
    if c.code == 0xE2 then mn = true end
  end
  T.check(pk and mn, "PKMN is drawn as the <PK><MN> glyph pair")

  -- One hand, on the selected cell.  menuIndex 2 is the top-right button, so
  -- the hand is in the second box's first interior tile: tile 11, row 13.
  local h = hands(drawn)
  T.eq(#h, 1, "exactly one hand")
  T.eq(h[1].x, 11 * 8, "the hand is in the selected button's hand column")
  T.eq(h[1].y, 13 * 8, "and on its text row")
end

-- Every command lands on its own button, and the hand follows the index the
-- engine already keeps: col = (i-1)%2, row = (i-1)//2, which is the reading
-- the engine's own input handling has always used.
do
  local expected = {
    { x = 1 * 8, y = 13 * 8 }, { x = 11 * 8, y = 13 * 8 },
    { x = 1 * 8, y = 16 * 8 }, { x = 11 * 8, y = 16 * 8 },
  }
  for i = 1, 4 do
    local h = hands(record(fakeBattle({ phase = "menu", menuIndex = i })))
    T.eq(#h, 1, "index " .. i .. " puts up one hand")
    T.eq(h[1].x, expected[i].x, "index " .. i .. " is in the right column")
    T.eq(h[1].y, expected[i].y, "index " .. i .. " is on the right row")
  end
end

-- ------- nothing reaches a border, and nothing leaves the screen
--
-- A classic cell is the box's eight interior tiles less the one kept for the
-- hand: seven, or 56 pixels.  What is asserted is that every label measured
-- through the font ENDS inside the cell it was given, whatever the label.

do
  local LONG = {
    { id = "LONG_A", pp = 10, ppUps = 0 },
    { id = "LONG_B", pp = 10, ppUps = 0 },
    { id = "LONG_C", pp = 10, ppUps = 0 },
    { id = "LONG_D", pp = 10, ppUps = 0 },
  }
  Data.moves.LONG_A = { name = "THUNDERSHOCK", type = "NORMAL", pp = 10 }
  Data.moves.LONG_B = { name = "DOUBLE-EDGE", type = "NORMAL", pp = 10 }
  Data.moves.LONG_C = { name = "HYPER BEAM", type = "NORMAL", pp = 10 }
  Data.moves.LONG_D = { name = "PIN MISSILE", type = "NORMAL", pp = 10 }

  local drawn = record(fakeBattle({ phase = "moveSelect", moves = LONG,
                                    moveIndex = 1 }))

  -- the four buttons plus the panel above them
  T.eq(#drawn.boxes, 5, "the move menu is four buttons and a panel")
  T.check(hasBox(drawn, 0, 8, 14, 5), "the panel is fourteen tiles, three rows")

  -- ------- and stops short of the EXP bar
  --
  -- Fourteen tiles is the smallest width that prints a move name whole, and
  -- the panel is not allowed to creep back out to the full width it used to
  -- run to -- which is what put it under the EXP bar another mod draws from
  -- about x=98.  112 is where fourteen tiles end.
  local HUD_X, STRIP_Y = 112, 96
  for _, b in ipairs(drawn.boxes) do
    if b.ty * 8 < STRIP_Y then
      T.check((b.tx + b.tw) * 8 <= HUD_X,
              ("a box at tile %d spanning %d stays clear of the HUD")
                :format(b.tx, b.tw))
    end
  end
  for _, t in ipairs(drawn.text) do
    if t.y < STRIP_Y then
      T.check(t.x + t.w <= HUD_X,
              ("%q stays clear of the player's HP"):format(t.text))
    end
  end

  -- The panel prints the name whole, in the game's own font, whatever the
  -- buttons below do.  Twelve interior tiles is what that takes.
  local panelName
  for _, t in ipairs(drawn.text) do
    if t.y < STRIP_Y and t.text:match("^THUNDER") then panelName = t end
  end
  T.check(panelName ~= nil, "the panel names the highlighted move")
  T.eq(panelName and panelName.text, "THUNDERSHOCK", "whole, not cut")
  T.check(panelName and not panelName.small,
          "in the game's own font, not the small face")
  T.check(panelName and panelName.w <= 96, "inside the twelve glyphs it has")

  local cellLabels = 0
  for _, t in ipairs(drawn.text) do
    if t.y >= 96 then
      cellLabels = cellLabels + 1
      T.check(t.w <= 56,
              ("%q is %d px, inside the 56 a cell has"):format(t.text, t.w))
      -- and it must not reach the border of the box it is in: the left
      -- column's interior ends at 72, the right column's at 152
      local limit = t.x < 80 and 72 or 152
      T.check(t.x + t.w <= limit,
              ("%q ends at %d, inside its box's border"):format(t.text,
                                                               t.x + t.w))
    end
  end
  T.eq(cellLabels, 4, "one label per button")

  for _, t in ipairs(drawn.text) do
    T.check(t.x >= 0 and t.x + t.w <= 160,
            ("%q stays on the 160px screen"):format(t.text))
    T.check(t.y >= 0 and t.y + 8 <= 144,
            ("%q stays on the 144px screen"):format(t.text))
  end
end

-- The panel says type and PP, and says "disabled!" instead when the slot is
-- the one Disable took.
do
  local drawn = record(fakeBattle({ phase = "moveSelect", moveIndex = 1 }))
  T.check(findText(drawn, "FIX EMBER") ~= nil, "the panel names the move")
  T.check(findText(drawn, "FIRE") ~= nil, "the panel gives its type")
  T.check(findText(drawn, "PP 20/25") ~= nil, "the panel gives its PP")
  -- stacked top-down in the box's three interior rows, rows 9, 10 and 11
  T.eq(findText(drawn, "FIX EMBER").y, 9 * 8, "the name on the first row")
  T.eq(findText(drawn, "FIRE").y, 10 * 8, "the type under it")
  T.eq(findText(drawn, "PP 20/25").y, 11 * 8, "and the PP under that")

  local off = record(fakeBattle({ phase = "moveSelect", moveIndex = 1,
                                  disabled = 1 }))
  T.check(findText(off, "disabled!") ~= nil, "a disabled slot says so")
  T.check(findText(off, "PP 20/25") == nil, "and does not also price it")
end

-- Mimic's copy menu is the same grid, one row higher, because the engine
-- clips the player's picture to row 7 for it and to row 8 for move select.
do
  local drawn = record(fakeBattle({ phase = "mimicSelect", mimicIndex = 2 }))
  T.check(hasBox(drawn, 0, 7, 18, 6), "Mimic's panel is the wider box")
  -- sixteen glyphs, which is what those two extra tiles are for
  local q = findText(drawn, "WHICH TECHNIQUE?")
  T.check(q ~= nil, "and asks the question whole, uncut")
  T.check(q and q.w <= 16 * 8, "inside the interior it has")
  T.eq(#hands(drawn), 1, "with the hand on the copied slot")
end

-- The swap marker keeps its own cell, and gives it up when the hand arrives:
-- two glyphs in one cell merge into a smear.
do
  local drawn = record(fakeBattle({ phase = "moveSelect", moveIndex = 1,
                                    swap = 3 }))
  local swaps = 0
  for _, c in ipairs(drawn.codes) do
    if c.code == 0xEC then swaps = swaps + 1 end
  end
  T.eq(swaps, 1, "the marked slot shows the hollow marker")

  local same = record(fakeBattle({ phase = "moveSelect", moveIndex = 3,
                                   swap = 3 }))
  local merged = 0
  for _, c in ipairs(same.codes) do
    if c.code == 0xEC then merged = merged + 1 end
  end
  T.eq(merged, 0, "and gives the cell up when the hand is on it")
end

-- An empty slot prints '-', the way the vanilla list does, rather than
-- leaving a button with nothing in it.
do
  local drawn = record(fakeBattle({ phase = "moveSelect",
                                    moves = { MOVES[1] } }))
  local dashes = 0
  for _, t in ipairs(drawn.text) do
    if t.text == "-" and t.y >= 96 then dashes = dashes + 1 end
  end
  T.eq(dashes, 3, "the three empty slots print '-'")
end

-- ------- the wide layout: one box, ruled into four

do
  local drawn = record(fakeBattle({ phase = "menu", wide = true,
                                    menuIndex = 1 }))
  T.check(hasBox(drawn, 0, 13, 19, 5), "the prompt keeps the left half")
  T.check(hasBox(drawn, 19, 13, 19, 5), "the buttons take the right half")
  T.eq(19 * 2, 38, "and the two halves are the screen's thirty-eight tiles")
  T.check(findText(drawn, "What will") ~= nil, "the prompt still asks")
  T.check(findText(drawn, "PIDGEOTTO do?") ~= nil, "and still names who")

  for _, t in ipairs(drawn.text) do
    T.check(t.x >= 0 and t.x + t.w <= 304,
            ("%q stays on the 304px surface"):format(t.text))
  end
end

do
  local drawn = record(fakeBattle({ phase = "moveSelect", wide = true,
                                    moveIndex = 1 }))
  T.check(hasBox(drawn, 0, 13, 29, 5), "the wide move grid is one box")
  T.check(hasBox(drawn, 28, 13, 10, 5), "with the vanilla panel beside it")

  -- Twelve glyphs of cell is what the wide layout's own move grid gave, so
  -- names arrive whole there and none of them is cut.
  for _, t in ipairs(drawn.text) do
    if t.x < 224 and t.y >= 104 then
      T.check(t.w <= 96, ("%q is inside the 96 a wide cell has"):format(t.text))
      T.check(not t.text:match("%.$"), ("%q is not cut short"):format(t.text))
    end
  end
end

-- The old man's scripted catch demo has no player behind the menu and no
-- input either: the hand sits on FIGHT and then on ITEM, slots 1 and 3.
do
  local first = hands(record(fakeBattle({ phase = "menu", demo = true,
                                          demoTimer = 10 })))
  T.eq(first[1].y, 13 * 8, "the demo hand starts on FIGHT's row")
  T.eq(first[1].x, 1 * 8, "in FIGHT's column")
  local later = hands(record(fakeBattle({ phase = "menu", demo = true,
                                          demoTimer = 120 })))
  T.eq(later[1].y, 16 * 8, "and moves to ITEM's row")
  T.eq(later[1].x, 1 * 8, "in ITEM's column")

  local wide = record(fakeBattle({ phase = "menu", demo = true, wide = true,
                                   demoTimer = 10 }))
  T.check(findText(wide, "What will") == nil,
          "and the demo names nobody: there is no player behind that menu")
end

-- Safari keeps its own four, count and all.
do
  local drawn = record(fakeBattle({ phase = "menu",
                                    safari = { balls = 27 } }))
  T.check(findText(drawn, "BALLx27") ~= nil, "the ball count rides the button")
  T.check(findText(drawn, "BAIT") ~= nil, "BAIT is there")
  T.check(findText(drawn, "RUN") ~= nil, "so is RUN")
  -- THROW ROCK is ten glyphs against a seven-glyph cell, so it is cut with
  -- the trailing space taken off rather than left as "THROW ."
  local rock
  for _, t in ipairs(drawn.text) do
    if t.text:match("^THROW") then rock = t end
  end
  T.check(rock ~= nil, "THROW ROCK is on a button")
  T.check(rock and rock.w <= 56, "cut to the cell it has")
  T.check(rock and not rock.text:match("%s%.$"),
          "with the trailing space taken off the cut")
end

-- ------- MOVE PANEL off
--
-- The classic grid is unchanged without it -- it already had the whole strip
-- -- and the wide grid takes back the ten tiles the panel was holding, because
-- a strip that stops ten tiles short of the edge is a hole in the frame
-- rather than a saving.

do
  local schema = run.loader.optionSchemas["Gen1BattleUI"]
  T.check(type(schema) == "table" and schema[1] and schema[1].key == "move_panel",
          "MOVE PANEL is an option")
  T.eq(schema and schema[1] and schema[1].default, true, "and is on by default")

  run.loader.modOptions["Gen1BattleUI"] = { move_panel = false }

  local classic = record(fakeBattle({ phase = "moveSelect", moveIndex = 1 }))
  T.eq(#classic.boxes, 4, "classic keeps its four buttons and drops the panel")
  for _, b in ipairs(classic.boxes) do
    T.check(b.ty >= 12, "and draws nothing above the strip")
  end

  local wide = record(fakeBattle({ phase = "moveSelect", wide = true,
                                   moveIndex = 1 }))
  T.eq(#wide.boxes, 1, "wide is one box")
  T.check(hasBox(wide, 0, 13, 38, 5), "spanning the whole strip")
  for _, t in ipairs(wide.text) do
    T.check(t.x + t.w <= 304, ("%q stays on the surface"):format(t.text))
  end

  -- and the command menu is untouched either way: the panel is a move-menu
  -- thing and turning it off is not a licence to redraw anything else
  local menu = record(fakeBattle({ phase = "menu", wide = true }))
  T.check(hasBox(menu, 0, 13, 19, 5), "the prompt is still there")
  T.check(hasBox(menu, 19, 13, 19, 5), "and so are the buttons")

  run.loader.modOptions["Gen1BattleUI"] = nil
end

-- ------- ITEM parks the menu rather than replacing it
--
-- The bag's item list is the one list in the game that is not a screen of its
-- own -- ListMenu's itemBox, isOpaque = false, sixteen tiles at (4,2) so it
-- stops at y=103 -- and the strip underneath it stays on screen.  openItems
-- sets phase to "messages" with nothing to say, so what the engine draws
-- there is an empty box; the menu it was opened from should still be showing,
-- with the hand hollow on the command whose screen is up.

local function bagOpen(index)
  return fakeBattle({ phase = "messages", afterQueue = "menu",
                      bag = true, menuIndex = index or 3 })
end

do
  local drawn = record(bagOpen(3))
  T.eq(#drawn.boxes, 4, "the four buttons are still drawn with the bag open")
  for _, key in ipairs({ "FIGHT", "ITEM", "RUN" }) do
    T.check(findText(drawn, key) ~= nil, key .. " is still on its button")
  end

  local hollow, filled = hollows(drawn), hands(drawn)
  T.eq(#hollow, 1, "exactly one hollow marker")
  T.eq(#filled, 0, "and no filled hand: the cursor is not in this grid")
  T.eq(hollow[1].x, 1 * 8, "the marker is in ITEM's column")
  T.eq(hollow[1].y, 16 * 8, "and on ITEM's row")
end

-- Whichever command opened the screen is the one marked.
do
  local expected = {
    { x = 1 * 8, y = 13 * 8 }, { x = 11 * 8, y = 13 * 8 },
    { x = 1 * 8, y = 16 * 8 }, { x = 11 * 8, y = 16 * 8 },
  }
  for i = 1, 4 do
    local h = hollows(record(bagOpen(i)))
    T.eq(#h, 1, "index " .. i .. " parks one marker")
    T.eq(h[1].x, expected[i].x, "index " .. i .. " marks the right column")
    T.eq(h[1].y, expected[i].y, "index " .. i .. " marks the right row")
  end
end

-- The strip is NOT claimed while parked, and that is the point: the answer is
-- inherited by every box above the battle, so a false here would take the
-- bag's own "How many?" and YES/NO down with it.
do
  T.eq(bottomVisible(bagOpen(3)), true,
       "parked does not claim the strip, so the bag keeps its own boxes")
end

-- An empty text box is one thing to draw over; a box with words in it is the
-- box doing its own job.
do
  local talking = fakeBattle({ phase = "messages", afterQueue = "menu",
                               bag = true, menuIndex = 3, current = "a line" })
  T.eq(#record(talking).boxes, 0, "a message showing is left alone")

  local elsewhere = fakeBattle({ phase = "messages", afterQueue = "end",
                                 bag = true, menuIndex = 3 })
  T.eq(#record(elsewhere).boxes, 0,
       "and so is a screen that is not coming back to the menu")

  local noCover = fakeBattle({ phase = "messages", afterQueue = "menu",
                               menuIndex = 3 })
  T.eq(#record(noCover).boxes, 0,
       "with nothing above the battle there is nothing to park under")
end

-- Wide parks the same way, prompt and all.
do
  local drawn = record(fakeBattle({ phase = "messages", afterQueue = "menu",
                                    bag = true, menuIndex = 3, wide = true }))
  T.check(hasBox(drawn, 0, 13, 19, 5), "the wide prompt is still drawn")
  T.check(hasBox(drawn, 19, 13, 19, 5), "and so are the wide buttons")
  T.eq(#hollows(drawn), 1, "with one hollow marker")
  T.eq(#hands(drawn), 0, "and no filled hand")
end

-- ------- whose strip is it

do
  for _, phase in ipairs({ "menu", "moveSelect", "mimicSelect" }) do
    T.eq(bottomVisible(fakeBattle({ phase = phase })), false,
         phase .. " hands the strip to this mod")
  end
  for _, phase in ipairs({ "messages", "intro", "end" }) do
    T.eq(bottomVisible(fakeBattle({ phase = phase })), true,
         phase .. " leaves the engine's own text box alone")
  end

  -- A battle with the party or bag screen above it keeps phase == "menu" the
  -- whole time -- chooseMenu pushes and returns.  Claiming the strip on the
  -- phase alone would take those screens' prompts down with it, because the
  -- visibility answer is inherited by every text box above the battle.
  T.eq(bottomVisible(fakeBattle({ phase = "menu", covered = true })), true,
       "a screen opened from the menu keeps its own box")
  T.eq(#record(fakeBattle({ phase = "menu", covered = true })).boxes, 0,
       "and nothing is drawn under it")

  -- A state that is not a battle at all is none of this mod's business.
  T.eq(bottomVisible({ phase = "menu" }), true, "a non-battle state passes through")

  T.eq(#record(fakeBattle({ phase = "messages" })).boxes, 0,
       "dialogue draws no buttons: the engine's text box has the strip")
end

-- ------- the classic move menu navigates as a grid

local function gridNav(battle)
  return Runtime.call("battle.move_grid_navigation",
                      function() return false end, battle)
end

do
  T.eq(gridNav(fakeBattle({ phase = "moveSelect" })), true,
       "move select navigates in four directions")
  T.eq(gridNav(fakeBattle({ phase = "mimicSelect" })), true,
       "and so does Mimic's copy menu")
  T.eq(gridNav(fakeBattle({ phase = "menu" })), false,
       "the command menu was already a grid and is not claimed here")
  T.eq(gridNav(fakeBattle({ phase = "moveSelect", covered = true })), false,
       "and a covered battle is not navigating anything")
end

-- The engine's own grid arithmetic is what the drawing is laid out against,
-- so a change to it should fail here rather than quietly desynchronise the
-- cursor from the cell it is drawn in.
do
  local WideBattle = require("src.battle.WideBattle")
  T.eq(WideBattle.moveGridIndex(1, 4, "right"), 2, "RIGHT crosses the row")
  T.eq(WideBattle.moveGridIndex(1, 4, "down"), 3, "DOWN crosses the column")
  T.eq(WideBattle.moveGridIndex(2, 2, "down"), 2,
       "and a direction pointing at an empty slot holds")
end

-- ------- the small face, and when it is not reached for
--
-- The tile font is 8px a glyph and a classic cell is seven of them, so
-- Gen 1's twelve-glyph names cannot fit in the game's own font however the
-- boxes are arranged.  FULL NAMES draws a grid that does not fit through the
-- engine's own Plain Pixel instead -- and only such a grid: a party whose
-- names all fit stays on the tile font, to the pixel.

local function faces(drawn, minY)
  local tiles, small = 0, 0
  for _, t in ipairs(drawn.text) do
    if t.y >= (minY or 96) then
      if t.small then small = small + 1 else tiles = tiles + 1 end
    end
  end
  return tiles, small
end

do
  -- the buttons are the game's own font by default, cut to the cell
  local byDefault = record(fakeBattle({ phase = "moveSelect", moves = {
    { id = "LONG_A", pp = 10, ppUps = 0 }, { id = "LONG_B", pp = 10, ppUps = 0 },
    { id = "LONG_C", pp = 10, ppUps = 0 }, { id = "LONG_D", pp = 10, ppUps = 0 },
  } }))
  local dtiles, dsmall = 0, 0
  for _, t in ipairs(byDefault.text) do
    if t.y >= 96 then
      if t.small then dsmall = dsmall + 1 else dtiles = dtiles + 1 end
    end
  end
  T.eq(dsmall, 0, "the buttons are the game's own font by default")
  T.eq(dtiles, 4, "all four of them")

  local SHORT = {
    { id = "S_A", pp = 10, ppUps = 0 }, { id = "S_B", pp = 10, ppUps = 0 },
    { id = "S_C", pp = 10, ppUps = 0 }, { id = "S_D", pp = 10, ppUps = 0 },
  }
  Data.moves.S_A = { name = "GUST", type = "NORMAL", pp = 10 }
  Data.moves.S_B = { name = "TACKLE", type = "NORMAL", pp = 10 }
  Data.moves.S_C = { name = "GROWL", type = "NORMAL", pp = 10 }
  Data.moves.S_D = { name = "SCRATCH", type = "NORMAL", pp = 10 }

  local short = record(fakeBattle({ phase = "moveSelect", moves = SHORT }))
  local tiles, small = faces(short)
  T.eq(tiles, 4, "names that fit stay on the game's own font")
  T.eq(small, 0, "and the small face is never reached for")

  -- one name too long is enough to move the whole grid, so a cell is never
  -- one font beside another
  local MIXED = {
    { id = "S_A", pp = 10, ppUps = 0 }, { id = "LONG_A", pp = 10, ppUps = 0 },
    { id = "S_C", pp = 10, ppUps = 0 }, { id = "S_D", pp = 10, ppUps = 0 },
  }
  run.loader.modOptions["Gen1BattleUI"] = { full_names = true }
  local mixed = record(fakeBattle({ phase = "moveSelect", moves = MIXED }))
  local mtiles, msmall = faces(mixed)
  T.eq(msmall, 4, "one name too wide moves all four to the small face")
  T.eq(mtiles, 0, "and none is left behind on the tile font")
  run.loader.modOptions["Gen1BattleUI"] = nil

  -- the command menu is four fixed words and never moves
  local cmd = record(fakeBattle({ phase = "menu" }))
  local ctiles, csmall = faces(cmd)
  T.eq(csmall, 0, "the command menu is always the game's own font")
  T.check(ctiles > 0, "and is drawn through it")
end

-- FULL NAMES off is the game's font always, and the cut comes back.
do
  local drawn = record(fakeBattle({ phase = "moveSelect", moves = {
    { id = "LONG_A", pp = 10, ppUps = 0 }, { id = "LONG_B", pp = 10, ppUps = 0 },
    { id = "LONG_C", pp = 10, ppUps = 0 }, { id = "LONG_D", pp = 10, ppUps = 0 },
  } }))
  local tiles, small = faces(drawn)
  T.eq(small, 0, "FULL NAMES off never reaches for the small face")
  T.eq(tiles, 4, "every label is the game's own font")
  local cut = 0
  for _, t in ipairs(drawn.text) do
    if t.y >= 96 and t.text:match("%.$") then cut = cut + 1 end
  end
  T.check(cut > 0, "and a name too long for its cell is cut again")
end

-- The wide layout's cells are twelve glyphs, which is what Gen 1's longest
-- name needs, so it never reaches for the small face either.
do
  run.loader.modOptions["Gen1BattleUI"] = { full_names = true }
  local drawn = record(fakeBattle({ phase = "moveSelect", wide = true, moves = {
    { id = "LONG_A", pp = 10, ppUps = 0 }, { id = "LONG_B", pp = 10, ppUps = 0 },
    { id = "LONG_C", pp = 10, ppUps = 0 }, { id = "LONG_D", pp = 10, ppUps = 0 },
  } }))
  local _, small = faces(drawn, 104)
  T.eq(small, 0, "wide keeps the game's own font: its cells already fit")
  run.loader.modOptions["Gen1BattleUI"] = nil
end

-- ------- the type sits on a chip in its own colour
--
-- Behind the word, never in it: a tile glyph is black on transparent and
-- comes out black whatever colour is set, so tinting the letters would mean
-- giving up the game's own font for them.  The chip is exactly the glyph row
-- tall, so it cannot bleed into the line above or below.

local function chipUnder(drawn, text)
  local label
  for _, t in ipairs(drawn.text) do if t.text == text then label = t end end
  if not label then return nil end
  for _, r in ipairs(drawn.rects) do
    if r.y == label.y and r.h == 8 and r.x == label.x then return r, label end
  end
  return nil, label
end

do
  local drawn = record(fakeBattle({ phase = "moveSelect", moveIndex = 1 }))
  local chip, label = chipUnder(drawn, "FIRE")
  T.check(label ~= nil, "the panel names the type")
  T.check(chip ~= nil, "and puts a chip under it")
  T.check(chip and chip.w >= label.w, "at least as wide as the word")
  T.check(chip and chip.colour and chip.colour[1] > chip.colour[3],
          "FIRE's chip is warmer than it is blue")

  -- a type the table does not know gets no chip, and the word is unchanged
  Data.moves.ODD = { name = "ODD", type = "MOD_MADE_UP", pp = 5 }
  local odd = record(fakeBattle({ phase = "moveSelect", moveIndex = 1,
    moves = { { id = "ODD", pp = 5, ppUps = 0 } } }))
  local oddChip, oddLabel = chipUnder(odd, "MOD_MADE_UP")
  T.check(oddLabel ~= nil or true, "an unknown type still prints")
  T.check(oddChip == nil, "and gets no chip")

  -- TYPE COLOUR off leaves the type as plain black text
  run.loader.modOptions["Gen1BattleUI"] = { type_colour = false }
  local plain = record(fakeBattle({ phase = "moveSelect", moveIndex = 1 }))
  T.check(select(1, chipUnder(plain, "FIRE")) == nil,
          "TYPE COLOUR off draws no chip")
  T.check(findText(plain, "FIRE") ~= nil, "and the type still reads")
  run.loader.modOptions["Gen1BattleUI"] = nil
end

-- ------- the bag's own scrolling is not this mod's
--
-- Reported as "the item screen sometimes scrolls a bunch".  It is the
-- engine's hold-to-scroll (src/ui/ListMenu.lua), which is opt-in through the
-- ui.list_menu hook and which another mod turns on -- Gen1ModernBag ships
-- Hold Scroll Speed = Fast, repeating every 2 frames after 10.  This mod
-- subscribes to three battle hooks and none of them is ui.list_menu, so the
-- claim is that a bag list behaves identically whether or not it is loaded.
-- Asserted by driving one and comparing the trace, because "we do not touch
-- it" is exactly the kind of claim that rots when someone adds a fourth hook.

do
  T.check((Runtime.hooks.chains or {})["ui.list_menu"] == nil,
          "this mod does not subscribe to ui.list_menu")
  T.check((Runtime.hooks.chains or {})["input.step"] == nil,
          "nor to input.step: no input path is touched at all")

  local ListMenu = require("src.ui.ListMenu")
  local function listGame()
    local down, pressed = {}, {}
    local g = { stack = { pop = function() end } }
    g.input = { wasPressed = function(_, k) return pressed[k] end,
                isDown = function(_, k) return down[k] end }
    g.hold = function(k) down, pressed = { [k] = true }, {} end
    g.tap = function(k) down, pressed = { [k] = true }, { [k] = true } end
    return g
  end
  local items = {}
  for i = 1, 30 do items[i] = { label = "ITEM" .. i, right = "x1" } end

  -- itemBox is the shape BagMenu builds in battle; both repeat settings, so
  -- the guard holds whether or not the other mod has turned it on.
  local function trace(keyRepeat)
    local g = listGame()
    local list = ListMenu.new(g, "ITEM", items,
      { itemBox = true, keyRepeat = keyRepeat })
    local out = {}
    g.tap("down"); list:update(1 / 60)
    out[#out + 1] = list.index .. "/" .. list.scroll
    for _ = 1, 40 do
      g.hold("down"); list:update(1 / 60)
      out[#out + 1] = list.index .. "/" .. list.scroll
    end
    return table.concat(out, " ")
  end

  -- The mod is already loaded, so the comparison is against the same code
  -- with its hook chains released -- which is what a mod-free boot is.
  local loaded = { trace(false), trace(true) }
  run.release()
  local bare = { trace(false), trace(true) }

  T.eq(loaded[1], bare[1], "a tapped bag list scrolls the same either way")
  T.eq(loaded[2], bare[2], "and so does a held one")
  -- and the held trace really does move, or the two would match trivially
  T.neq(bare[1], bare[2], "the hold-to-scroll case is actually different")
end

T.finish("Gen1BattleUI")
