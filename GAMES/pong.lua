--
-- Copyright (C) EdgeTX
--
-- Based on code named
--   opentx - https://github.com/opentx/opentx
--   th9x - http://code.google.com/p/th9x
--   er9x - http://code.google.com/p/er9x
--   gruvin9x - http://code.google.com/p/gruvin9x
--
-- License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License version 2 as
-- published by the Free Software Foundation.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- Pong game for EdgeTX colorlcd – LVGL version
-- Player 1 (left paddle):  left gimbal vertical  (thr)
-- Player 2 (right paddle): right gimbal vertical (ele)
-- ENTER: start / pause / resume   EXIT: quit

local toolName = "TNS|PONG|TNE"

-- ── Colors ───────────────────────────────────────────────────────────────────
local C_BG   = lcd.RGB(10,  10,  20)
local C_P1   = lcd.RGB(0,   200, 255)
local C_P2   = lcd.RGB(255, 100, 0)
local C_BALL = lcd.RGB(255, 255, 80)
local C_NET  = lcd.RGB(50,  50,  60)
local C_FG   = lcd.RGB(240, 240, 240)
local C_GOLD = lcd.RGB(255, 215, 0)
local C_WIN  = lcd.RGB(0,   230, 100)
local C_DIM  = lcd.RGB(20,  20,  30)

-- ── Constants ────────────────────────────────────────────────────────────────
local PAD_W     = 8
local PAD_H     = 40
local PAD_ROUND = 4       -- paddle corner radius (px)
local BALL_R    = 5       -- ball radius (px)
local WIN_SCORE = 7
local STICK_MAX = 1024    -- EdgeTX raw stick range

-- Paddle X positions (computed in init)
local PAD_X1, PAD_X2

-- ── Game state ───────────────────────────────────────────────────────────────
-- States: "title", "playing", "paused", "scored", "gameover"
local state     = "title"
local prevState = ""

local p1y, p2y            -- paddle top-edge Y
local bx, by, bvx, bvy   -- ball center + velocity
local score1, score2
local winner
local scoredTimer = 0

-- ── LVGL handles (only valid while the game layout is live) ──────────────────
local pad1Obj, pad2Obj, ballObj

-- ── Gimbal sources ───────────────────────────────────────────────────────────
local srcP1, srcP2

-- ── Helpers ──────────────────────────────────────────────────────────────────
local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function randomSign()
  return (math.random(0, 1) == 0) and 1 or -1
end

-- Map raw stick value (−1024 … +1024) to paddle Y.
-- Stick up (negative) → top of screen; stick down → bottom.
local function stickToPaddleY(raw)
  local norm = (-raw + STICK_MAX) / (2 * STICK_MAX)
  return norm * (LCD_H - PAD_H)
end

local function resetBall(towards)
  bx  = LCD_W / 2
  by  = LCD_H / 2
  bvx = 7 * (towards or randomSign())
  bvy = 7 * randomSign()
end

local function resetGame()
  p1y    = LCD_H / 2 - PAD_H / 2
  p2y    = LCD_H / 2 - PAD_H / 2
  score1 = 0
  score2 = 0
  resetBall(1)
end

-- ── Ball physics ─────────────────────────────────────────────────────────────
local function updateBall()
  bx = bx + bvx
  by = by + bvy

  -- Top / bottom wall
  if by - BALL_R < 0 then
    by  = BALL_R
    bvy = math.abs(bvy)
  elseif by + BALL_R > LCD_H then
    by  = LCD_H - BALL_R
    bvy = -math.abs(bvy)
  end

  -- Left paddle
  if bvx < 0 and
     bx - BALL_R <= PAD_X1 + PAD_W and
     bx + BALL_R >= PAD_X1 and
     by + BALL_R >= p1y and by - BALL_R <= p1y + PAD_H then
    bx  = PAD_X1 + PAD_W + BALL_R
    bvx = math.abs(bvx) * 1.08
    bvy = bvy + (by - (p1y + PAD_H / 2)) * 0.1
  end

  -- Right paddle
  if bvx > 0 and
     bx + BALL_R >= PAD_X2 and
     bx - BALL_R <= PAD_X2 + PAD_W and
     by + BALL_R >= p2y and by - BALL_R <= p2y + PAD_H then
    bx  = PAD_X2 - BALL_R
    bvx = -math.abs(bvx) * 1.08
    bvy = bvy + (by - (p2y + PAD_H / 2)) * 0.1
  end

  -- Cap speed
  local maxspeed = 20
  if math.abs(bvx) > maxspeed then bvx = maxspeed * (bvx > 0 and 1 or -1) end
  if math.abs(bvy) > maxspeed then bvy = maxspeed * (bvy > 0 and 1 or -1) end

  -- Scoring
  if bx + BALL_R < 0 then
    score2 = score2 + 1
    if score2 >= WIN_SCORE then
      winner = 2; state = "gameover"
    else
      state = "scored"; scoredTimer = 0; resetBall(-1)
    end
  elseif bx - BALL_R > LCD_W then
    score1 = score1 + 1
    if score1 >= WIN_SCORE then
      winner = 1; state = "gameover"
    else
      state = "scored"; scoredTimer = 0; resetBall(1)
    end
  end
end

-- ── LVGL builders ────────────────────────────────────────────────────────────
local function buildNet()
  local nx = math.floor(LCD_W / 2) - 1
  local y  = 4
  while y < LCD_H do
    lvgl.rectangle({x=nx, y=y, w=2, h=10, color=C_NET, filled=true})
    y = y + 16
  end
end

local function buildOverlay(line1, line2, color)
  local bw = math.floor(LCD_W * 0.56)
  local bh = 62
  local ox  = math.floor((LCD_W - bw) / 2)
  local oy  = math.floor((LCD_H - bh) / 2)
  lvgl.rectangle({x=ox, y=oy, w=bw, h=bh, color=C_DIM,  filled=true,  rounded=8})
  lvgl.rectangle({x=ox, y=oy, w=bw, h=bh, color=color,  filled=false, rounded=8, thickness=2})
  lvgl.label({x=math.floor(LCD_W/2), y=oy+10, text=line1, color=color, align=CENTER, font=MIDSIZE})
  lvgl.label({x=math.floor(LCD_W/2), y=oy+38, text=line2, color=C_FG,  align=CENTER, font=SMLSIZE})
end

-- Build the in-game layer and return persistent object handles via upvalues.
-- Optionally adds an overlay on top (for paused / scored / gameover).
local function buildGameView(withOverlay, ov1, ov2, ovColor)
  lvgl.rectangle({x=0, y=0, w=LCD_W, h=LCD_H, color=C_BG, filled=true})
  buildNet()

  -- Score labels (static text – rebuilt on every state change when score changes)
  local cw = math.floor(LCD_W / 4)
  lvgl.label({x=cw,         y=4, text=tostring(score1), color=C_P1, align=CENTER, font=DBLSIZE})
  lvgl.label({x=LCD_W - cw, y=4, text=tostring(score2), color=C_P2, align=CENTER, font=DBLSIZE})

  -- Paddles – store references for per-frame position updates
  pad1Obj = lvgl.rectangle({
    x=PAD_X1, y=math.floor(p1y), w=PAD_W, h=PAD_H,
    color=C_P1, filled=true, rounded=PAD_ROUND
  })
  pad2Obj = lvgl.rectangle({
    x=PAD_X2, y=math.floor(p2y), w=PAD_W, h=PAD_H,
    color=C_P2, filled=true, rounded=PAD_ROUND
  })

  -- Ball – circle widget; x,y are CENTER coordinates
  ballObj = lvgl.circle({
    x=math.floor(bx), y=math.floor(by),
    radius=BALL_R, color=C_BALL, filled=true
  })

  if withOverlay then
    buildOverlay(ov1, ov2, ovColor)
  end
end

-- Top-level UI rebuild – called once per state transition.
local function buildUI()
  if not lvgl then return end

  lvgl.clear()
  pad1Obj = nil; pad2Obj = nil; ballObj = nil

  if state == "title" then
    local _, hXXL = lcd.sizeText("A", XXLSIZE)
    local _, hSML = lcd.sizeText("A", SMLSIZE)
    local pad     = math.floor(hSML * 0.6)   -- gap between lines
    -- Stack items with measured heights; centre the block vertically
    local blockH  = hXXL + pad + hSML + pad + hSML
    local top     = math.floor((LCD_H - blockH) / 2)
    local y1 = top
    local y2 = y1 + hXXL + pad
    local y3 = y2 + hSML + pad

    lvgl.rectangle({x=0, y=0, w=LCD_W, h=LCD_H, color=C_BG, filled=true})
    lvgl.label({x=0, y=y1, w=LCD_W,
                text="PONG", color=C_GOLD, align=CENTER, font=XXLSIZE})
    lvgl.label({x=0, y=y2, w=LCD_W,
                text="P1: left gimbal   P2: right gimbal",
                color=C_FG, align=CENTER, font=SMLSIZE})
    lvgl.label({x=0, y=y3, w=LCD_W,
                text="First to "..WIN_SCORE.." wins",
                color=C_FG, align=CENTER, font=SMLSIZE})
    lvgl.label({x=0, y=LCD_H - hSML - 8, w=LCD_W,
                text="Press ENTER to start",
                color=C_WIN, align=CENTER, font=SMLSIZE})

  elseif state == "playing" then
    buildGameView(false)

  elseif state == "paused" then
    buildGameView(true, "PAUSED", "ENTER to resume", C_GOLD)

  elseif state == "scored" then
    local msg = (score1 > score2) and "P1 scores!" or "P2 scores!"
    buildGameView(true, msg, "Get ready...", C_WIN)

  elseif state == "gameover" then
    buildGameView(true, "Player "..winner.." wins!", "ENTER: again   EXIT: quit", C_WIN)
  end
end

-- ── Init ─────────────────────────────────────────────────────────────────────
local function init()
  math.randomseed(getTime())
  PAD_X1 = PAD_W + 4
  PAD_X2 = LCD_W - PAD_W - 4 - PAD_W
  -- Modes 1 & 3: left-Y = ele, right-Y = thr
  -- Modes 2 & 4: left-Y = thr, right-Y = ele
  local mode  = getStickMode()
  local leftY  = (mode == 1 or mode == 3) and "ele" or "thr"
  local rightY = (mode == 1 or mode == 3) and "thr" or "ele"
  local f1 = getFieldInfo(leftY)
  local f2 = getFieldInfo(rightY)
  srcP1 = f1 and f1.id or nil
  srcP2 = f2 and f2.id or nil
  resetGame()
end

-- ── run() ─────────────────────────────────────────────────────────────────────
local function run(event)
  if event == nil then
    error("Cannot be run as a model script!")
    return 2
  end

  if event == EVT_VIRTUAL_EXIT then return 2 end

  -- Rebuild LVGL layout on every state transition
  if state ~= prevState then
    buildUI()
    prevState = state
  end

  -- Per-state logic ────────────────────────────────────────────────────────
  if state == "title" then
    if event == EVT_VIRTUAL_ENTER then
      resetGame()
      state = "playing"
    end

  elseif state == "playing" then
    -- Read gimbals → paddle positions
    if srcP1 then p1y = stickToPaddleY(getValue(srcP1)) end
    if srcP2 then p2y = stickToPaddleY(getValue(srcP2)) end
    p1y = clamp(p1y, 0, LCD_H - PAD_H)
    p2y = clamp(p2y, 0, LCD_H - PAD_H)

    -- Physics (may change state to "scored" / "gameover")
    updateBall()

    -- Update LVGL widget positions
    if pad1Obj then pad1Obj:set({y = math.floor(p1y)}) end
    if pad2Obj then pad2Obj:set({y = math.floor(p2y)}) end
    -- Circle x,y are CENTER coordinates
    if ballObj then ballObj:set({x = math.floor(bx), y = math.floor(by)}) end

    if event == EVT_VIRTUAL_ENTER or event == EVT_VIRTUAL_MENU then
      state = "paused"
    end

  elseif state == "paused" then
    if event == EVT_VIRTUAL_ENTER then
      state = "playing"
    end

  elseif state == "scored" then
    scoredTimer = scoredTimer + 1
    if scoredTimer >= 60 then   -- ~1 s at 60 fps
      scoredTimer = 0
      state = "playing"
    end

  elseif state == "gameover" then
    if event == EVT_VIRTUAL_ENTER then
      resetGame()
      state = "playing"
    end
  end

  return 0
end

return { init = init, run = run }
