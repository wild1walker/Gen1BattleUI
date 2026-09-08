-- The level-up burst's true-colour marks: three rectangles per particle, and
-- they are exactly the pixels it draws.
--
-- This used to mark every pixel: twenty-four per particle, eight particles,
-- ONE HUNDRED AND NINETY-TWO rects in one frame -- against the theme's cap of
-- forty (Gen1WildUI runtime/theme.lua, ART_CAP).  Everything past the fortieth
-- got no ART_PAGE zone and came back unthemed, which on a level-up is the EXP
-- bar's own mark and the caught indicator's: the two things a player is
-- looking at, reported broken together.
--
-- A circle of this size is three rectangles, and the whole of this file is the
-- arithmetic that says so -- asserted rather than described, because a claim
-- one column wide of the truth marks pixels the burst never draws (which
-- re-blit raw, unpaletted) or leaves pixels it does draw unmarked (which get
-- quantised back into four shades).  Neither is visible in a diff.
--
-- Run:  luajit tests/burstmark_test.lua

package.path = "./?.lua;" .. package.path

local passed, failed = 0, 0
local function ok(condition, description)
  if condition then
    passed = passed + 1
  else
    failed = failed + 1
    io.write("  FAIL  ", description, "\n")
  end
end
local function eq(actual, expected, description)
  local same = actual == expected
  if not same then
    description = ("%s (got %s, wanted %s)")
      :format(description, tostring(actual), tostring(expected))
  end
  ok(same, description)
end

-- xpbar.lua by SEARCH: the bundle stages this mod under the engine tree, where
-- a bare relative name is somebody else's file.
local SOURCE do
  for _, candidate in ipairs({ "xpbar.lua", "../xpbar.lua",
                               "modules/Gen1BattleUI/xpbar.lua" }) do
    local handle = io.open(candidate)
    if handle then
      local text = handle:read("*a")
      handle:close()
      if text:find("EXP_BURST_TILE_ROWS", 1, true) then SOURCE = text break end
    end
  end
end
ok(SOURCE ~= nil, "this mod's own xpbar.lua is found")
if not SOURCE then
  io.write(("burstmark: %d passed, %d failed\n"):format(passed, failed))
  os.exit(1)
end

-- ---- the shape it draws, read out of the file rather than restated here

local ROWS = {}
do
  local block = SOURCE:match("EXP_BURST_TILE_ROWS = {(.-)}")
  ok(block ~= nil, "the particle's tile rows are where they were")
  for row in (block or ""):gmatch('"([ox]+)"') do ROWS[#ROWS + 1] = row end
end
eq(#ROWS, 8, "eight rows of eight, which is one tile")

local drawn, drawnCount = {}, 0
for py, row in ipairs(ROWS) do
  for px = 1, #row do
    if row:sub(px, px) == "x" then
      drawn[px .. "," .. py] = true
      drawnCount = drawnCount + 1
    end
  end
end
eq(drawnCount, 24, "twenty-four pixels to a particle")

-- ---- the claims it makes, also read out of the file

local CLAIMS = {}
for col, rowFrom, cols, rows in
    SOURCE:gmatch("claim%((%d+),%s*(%d+),%s*(%d+),%s*(%d+)%)") do
  CLAIMS[#CLAIMS + 1] = { col = tonumber(col), row = tonumber(rowFrom),
                          cols = tonumber(cols), rows = tonumber(rows) }
end
eq(#CLAIMS, 3, "three rectangles, where there were twenty-four")

local claimed, claimedArea = {}, 0
for _, c in ipairs(CLAIMS) do
  claimedArea = claimedArea + c.cols * c.rows
  for dx = 0, c.cols - 1 do
    for dy = 0, c.rows - 1 do
      claimed[(c.col + dx) .. "," .. (c.row + dy)] = true
    end
  end
end

-- ---- and they are the same set

do
  io.write("every pixel the burst draws is claimed, and nothing else is\n")

  local unmarked, overclaimed = {}, {}
  for key in pairs(drawn) do
    if not claimed[key] then unmarked[#unmarked + 1] = key end
  end
  for key in pairs(claimed) do
    if not drawn[key] then overclaimed[#overclaimed + 1] = key end
  end
  table.sort(unmarked)
  table.sort(overclaimed)

  eq(#unmarked, 0, "no drawn pixel is left out of the marks ("
    .. table.concat(unmarked, " ") .. ")")
  eq(#overclaimed, 0, "and no undrawn pixel is claimed by them ("
    .. table.concat(overclaimed, " ") .. ")")
  ok(claimedArea >= drawnCount,
    "the three rectangles overlap rather than tile, which is what lets them "
    .. "describe a circle at all")
end

-- ---- the budget, which is why any of this was done

do
  io.write("and the frame's art budget survives a level-up\n")
  local PARTICLES = 8
  eq(#CLAIMS * PARTICLES, 24, "eight particles cost twenty-four rects")
  local ART_CAP = 40
  ok(#CLAIMS * PARTICLES < ART_CAP,
    "which fits under the theme's cap of " .. ART_CAP
    .. ", where twenty-four pixels each did not")
  -- With the bar's own mark and the caught indicator's seven beside it.
  ok(#CLAIMS * PARTICLES + 1 + 7 < ART_CAP,
    "with room for the EXP bar's own mark and the caught indicator's seven")
end

io.write(("\nburstmark: %d passed, %d failed\n"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
