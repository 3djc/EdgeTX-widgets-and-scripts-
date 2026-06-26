--- TNS|Graupner HoTT model locator|TNE
---- #########################################################################
---- #                                                                       #
---- # Copyright (C) EdgeTX                                                  #
---- #                                                                       #
---- # Telemetry Widget script for FrSky Horus/Radio Master TX16s            #
---- # Copyright (C) EdgeTX                                                  #
-----#                                                                       #
---- # License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html               #
---- #                                                                       #
---- # This program is free software; you can redistribute it and/or modify  #
---- # it under the terms of the GNU General Public License version 2 as     #
---- # published by the Free Software Foundation.                            #
---- #                                                                       #
---- # This program is distributed in the hope that it will be useful        #
---- # but WITHOUT ANY WARRANTY; without even the implied warranty of        #
---- # MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
---- # GNU General Public License for more details.                          #
---- #                                                                       #
---- #########################################################################

-- Fix by 3djc for recent radio and EdgeTX

-- Model Locator by RSSI
-- Offer Shmuely (based on code from Scott Bauer 6/21/2015)
-- Date: 2021
-- ver: 0.1

-- MHA (based on code from Offer Shmuely)
-- Date: 2022
-- ver: 0.11
-- changes: made version for Graupner HoTT. Uses real Rssi data scaled -15db to -115db to 100..0

-- This widget help to find a lost/crashed model based on the RSSI (if still available)
-- The widget produce audio representation (variometer style) of the RSSI from the lost model
-- The widget also  display the RSSI in a visible colorized bar (0-100%)

-- There are two way to use it
-- 1. The simple way:
--    walk toward the quad/plane that crashed,
--    as you get closer to your model the beeps will become more frequent with higher pitch (and a visual bar graph as well)
--    until you get close enough to find it visually

-- 2. the more accurate way:
--    turn the antenna straight away (i.e. to point from you, straight away)
--    try to find the weakest signal! (not the highest), i.e. the lowest RSSI you can find, this is the direction to the model.
--    now walk to the side (not toward the model), find again the weakest signal, this is also the direction to your model
--    triangulate the two lines, and it will be :-)

local delayMillis = 100
local nextPlayTime = getTime()
local img = Bitmap.open("/SCRIPTS/TOOLS/Model Locator (by RSSI).png")

--------------------------------------------------------------
local function log(s)
  --return;
  print("locator: " .. s)
end
--------------------------------------------------------------


-- init_func is called once when model is loaded
local function init()
  return 0
end

-- bg_func is called periodically when screen is not visible
local function bg()
  return 0
end

-- This function returns green at gvalue, red at rvalue and graduate in between
local function getRangeColor(value, red_value, green_value)
  local range = math.abs(green_value - red_value)
  if range == 0 then
    return lcd.RGB(0, 0xdf, 0)
  end
  if value == nil then
    return lcd.RGB(0, 0xdf, 0)
  end

  if green_value > red_value then
    if value > green_value then
      return lcd.RGB(0, 0xdf, 0)
    end
    if value < red_value then
      return lcd.RGB(0xdf, 0, 0)
    end
    g = math.floor(0xdf * (value - red_value) / range)
    r = 0xdf - g
    return lcd.RGB(r, g, 0)
  else
    if value > green_value then
      return lcd.RGB(0, 0xdf, 0)
    end
    if value < red_value then
      return lcd.RGB(0xdf, 0, 0)
    end
    r = math.floor(0xdf * (value - green_value) / range)
    g = 0xdf - r
    return lcd.RGB(r, g, 0)
  end
end

local function main(event)

  lcd.clear()

  -- Scale all coordinates from the original 480x272 layout so the script
  -- fills the screen on any colour resolution (480x272, 480x320, 800x480, ...)
  local scaleX = LCD_W / 480
  local scaleY = LCD_H / 272

	-- fetch uplink rssi (HoTT sensor Rssi)
	local rssi = getValue("Rssi")

	-- calculate a percentage for the color bar (range -115db to -15db)
	local rssiP = rssi

	if(rssi ~= 0) then							-- rssi < 0 -> telemtry data received
		if(rssi >= -15) then					-- -15db to -1db => 100%
			rssiP = 100
		else
			if(rssi >=  -115) then			-- between -115db and -15db => 0% to 100%
				rssiP = 100+rssi+15
			else
				rssiP = 0									-- less than -115 => 0%
			end
		end
	end

  lcd.drawBitmap(img, math.floor(250 * scaleX), math.floor(50 * scaleY), math.floor(40 * scaleX))

  -- Title
  lcd.drawText(3, 3, "Graupner HoTT Rssi Model Locator", COLOR_THEME_PRIMARY1)
  myColor = getRangeColor(rssi, 0, 100)
  lcd.setColor(CUSTOM_COLOR, myColor)

  -- draw current value
	local dx = 0
	if rssi < -99 then
		dx = math.floor(-33 * scaleX)
	end

	if rssi == 0 then
		lcd.drawText(math.floor(115 * scaleX), math.floor(73 * scaleY), "no telemetry", DBLSIZE + CUSTOM_COLOR)
	else
	  lcd.drawNumber(math.floor(180 * scaleX) + dx, math.floor(30 * scaleY), rssi, XXLSIZE + CUSTOM_COLOR)
		lcd.drawText(math.floor(275 * scaleX), math.floor(73 * scaleY), "db", CUSTOM_COLOR)
	end

  -- draw main bar
  lcd.setColor(CUSTOM_COLOR, YELLOW) -- RED / YELLOW
  local xMin = 0
  local yBase = LCD_H - math.max(1, math.floor(2 * scaleY))
  local xMax = LCD_W
  local h = 0
  local step = math.max(1, math.floor(20 * scaleX))
  local barW = math.max(1, math.floor(15 * scaleX))
  local hInc = math.max(1, math.floor(10 * scaleY))
  local edgeX = math.floor(40 * scaleX)
  local rssiAsX = (rssiP * xMax) / 100

  for xx = xMin, rssiAsX, step do
    lcd.setColor(CUSTOM_COLOR, getRangeColor(xx, xMin, xMax - edgeX))
    h = h + hInc
    lcd.drawFilledRectangle(xx, yBase - h, barW, h, CUSTOM_COLOR)
  end

  -- beep
  if getTime() >= nextPlayTime then
    playFile("/SCRIPTS/TOOLS/Model Locator (by RSSI).wav")
    nextPlayTime = getTime() + delayMillis - rssiP
  end

  return 0
end

return {init = init,run = main,background = bg}

