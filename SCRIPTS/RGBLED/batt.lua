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

-- Telemetry percent sensor name
local SENSOR_NAME = "%bat"

-- Battery level thresholds
local GREEN_THRESHOLD = 90   -- >= 90% pure green
local RED_THRESHOLD = 30     -- <= 30% pure red
local BLINK_THRESHOLD = 20   -- < 20% blinking red

-- Blink timing (in run cycles)
local BLINK_INTERVAL = 5
local blinkCounter = 0
local blinkOn = true

local function setAllLeds(r, g, b)
  for i = 0, 19 do
    setRGBLedColor(i, r, g, b)
  end
end

local function init()
end

local function run()
  local bat = getValue(SENSOR_NAME)

  if bat == nil then
    setAllLeds(0, 0, 0)
    applyRGBLedColors()
    return
  end

  if bat < BLINK_THRESHOLD then
    -- Blinking red below 20%
    blinkCounter = blinkCounter + 1
    if blinkCounter >= BLINK_INTERVAL then
      blinkCounter = 0
      blinkOn = not blinkOn
    end
    if blinkOn then
      setAllLeds(255, 0, 0)
    else
      setAllLeds(0, 0, 0)
    end
  elseif bat <= RED_THRESHOLD then
    -- Solid red at or below 30%
    setAllLeds(255, 0, 0)
  elseif bat >= GREEN_THRESHOLD then
    -- Pure green at 90% or above
    setAllLeds(0, 255, 0)
  else
    -- Gradual transition from red to green between 30% and 90%
    -- t=0 at RED_THRESHOLD, t=1 at GREEN_THRESHOLD
    local t = (bat - RED_THRESHOLD) / (GREEN_THRESHOLD - RED_THRESHOLD)
    local r = math.floor(255 * (1 - t))
    local g = math.floor(255 * t)
    setAllLeds(r, g, 0)
  end

  applyRGBLedColors()
end

local function background()
  -- Called periodically while the Special Function switch is off
end

return { run=run, background=background, init=init }
