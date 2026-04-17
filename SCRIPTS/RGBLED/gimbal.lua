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
local rh, lv, lh, rv
local lhs, lvs, hs, rvs
local lv_dir = -1
local prev_rh, prev_lv, prev_lh, prev_rv = 10000, 10000, 10000, 10000
local delta_rh, delta_lv, delta_lh, delta_rv
local angles = { 348, 24, 60, 96, 132, 168, 204, 240, 276, 312 }

-- Configuration constants for delta thresholds
local DELTA_MIN_MOVEMENT = 3      -- Minimum delta to allow LED updates

-- Base LED color when stick centered (uncomment one color option below)
local BASE_R, BASE_G, BASE_B = 0, 0, 0     -- Off

-- Maximum LED scale when stick at extreme end
local MAX_R, MAX_G, MAX_B = 0, 0, 1.0   -- Blue

local function getValues()
  -- Get current values
  lh = getValue(lhs) or 0
  rh = (getValue(rhs) or 0) * -1
  lv = (getValue(lvs) or 0) * lv_dir
  rv = getValue(rvs) or 0
end

local function init()
  -- get stick names based on mode
  local radioMode = getStickMode()
  if radioMode < 3 then
    lhs = "rud"
    rhs = "ail"
  else
    lhs = "ail"
    rhs = "rud"
  end
  if radioMode == 1 or radioMode == 3 then
    lvs = "ele"
    rvs = "thr"
  else
    lvs = "thr"
    rvs = "ele"
  end
  -- invert left vertical for TX16S Mk3
  if LCD_W == 800 then lv_dir = 1 end
  -- Initialize all values to current stick positions
  getValues()
end

local function calculateDeltas()
  -- Calculate delta values for all controls
  delta_rh = math.abs(rh - prev_rh)
  delta_rv = math.abs(rv - prev_rv)
  delta_lh = math.abs(lh - prev_lh)
  delta_lv = math.abs(lv - prev_lv)
end

local function shouldUpdate(dh, dv)
  -- Check if any control has moved enough to warrant LED updates
  return math.max(dh, dv) >= DELTA_MIN_MOVEMENT
end

local function setLed(ring, h, v)
  local magnitude = math.sqrt(h^2 + v^2)

  local angle = math.atan2(v, h)
  angle = (math.deg(angle) + 360) % 360
  local center_index = math.floor(angle / 36 + 0.5) % 10

  local base_intensity = math.min(255, 250 * magnitude)

  ring = ring * 10 - 1

  for i = 1, 10 do
    local da = math.abs((angle - angles[i] + 180) % 360 - 180)
    local distance = da / 36
    if distance < 1.5 and magnitude >= 0.1 then
      local factor = math.exp(-0.5 * (distance ^ 2))
      local intensity = math.floor(base_intensity * factor)
      setRGBLedColor(i+ring, MAX_R*intensity, MAX_G*intensity, MAX_B*intensity)
    else
      setRGBLedColor(i+ring, BASE_R, BASE_G, BASE_B)
    end
  end
end

local function run()
  -- Get current values
  getValues()

  -- Calculate deltas
  calculateDeltas()

  local update = false

  -- Only update LEDs if there's significant movement
  if shouldUpdate(delta_rh, delta_rv) then
    -- Apply LED patterns (enhanced with delta feedback)
    setLed(0, rh/1024, rv/1024)

    update = true

    -- Store previous values
    prev_rh, prev_rv = rh or 0, rv or 0
  end

  -- Only update LEDs if there's significant movement
  if shouldUpdate(delta_lh, delta_lv) then
    -- Apply LED patterns (enhanced with delta feedback)
    setLed(1, lh/1024, lv/1024)

    update = true

    -- Store previous values
    prev_lv, prev_lh = lv or 0, lh or 0
  end

  if update then
    applyRGBLedColors()
  end
end

local function background()
  -- Called periodically while the Special Function switch is off
end

return { run=run, background=background, init=init }
