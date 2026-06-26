--- TNS|Graupner HoTT|TNE
---- #########################################################################
---- #                                                                       #
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

--###############################################################################
-- Multi buffer for HoTT description
-- To start operation:
--   Write "HoTT" at address 0..3
--   Write 0xFF at address 4 will request the buffer to be cleared
--   Write 0x0F at address 5
-- Read buffer from address 6 access the RX text for 168 bytes, 21 caracters
--    by 8 lines
-- Write at address 5 sends an order to the RX: 0xXF=start, 0xX7=prev page,
--    0xXE=next page, 0xX9=enter, 0xXD=next or 0xXB=prev with X being the sensor
--    to request data from 8=RX only, 9=Vario, A=GPS, B=Cust, C=ESC, D=GAM, E=EAM
-- Write at address 4 the value 0xFF will request the buffer to be cleared
-- !! Before exiting the script must write 0 at address 0 for normal operation !!
--###############################################################################

HoTT_Sensor = 0
Timer_128 = 100

local sensor_name = { "", "+Vario", "+GPS", "+Cust", "+ESC", "+GAM", "+EAM" }

local function HoTT_Release()
  multiBuffer( 0, 0 )
end

local function HoTT_Send(button)
  multiBuffer( 5, 0x80+(HoTT_Sensor*16) + button)
end

local function HoTT_Sensor_Inc()
  local detected_sensors=multiBuffer( 4 )
  local a
  if detected_sensors ~= 0xFF then
    repeat
        HoTT_Sensor=(HoTT_Sensor+1)%7	-- Switch to next sensor
        if HoTT_Sensor ~= 0 then
          a = math.floor(detected_sensors/ (2^(HoTT_Sensor-1))) -- shift right
        end
    until HoTT_Sensor==0 or a % 2 == 1
    HoTT_Send( 0x0F )
  end
end

-- The HoTT RX text menu is a fixed grid of 21 columns by 8 lines.
local HOTT_COLS = 21
local HOTT_ROWS = 8

-- Draw the menu grid on a colour display, scaled to the available area so it
-- fills the screen on every resolution (480x272, 480x320, 800x480, ...).
-- Each cell is drawn individually so the cursor highlight (high bit set on a
-- character) can be rendered per character.
local function HoTT_Draw_Grid_Color()
  local margin = math.floor(LCD_W / 40)
  local titleH, font
  if LCD_W >= 700 then
    titleH = 50
    font = MIDSIZE
  else
    titleH = 30
    font = 0
  end

  -- Title bar
  lcd.drawFilledRectangle(0, 0, LCD_W, titleH, COLOR_THEME_SECONDARY1)
  lcd.drawText(margin, (titleH - 20) / 2 + 1,
               "Graupner HoTT: config RX" .. sensor_name[HoTT_Sensor + 1] ..
               " - Menu cycles sensors", COLOR_THEME_PRIMARY2 + font)

  if multiBuffer(4) == 0xFF then
    lcd.drawText(margin, titleH + margin, "No HoTT telemetry...",
                 BLINK + COLOR_THEME_PRIMARY1 + font)
    return
  end

  local gridTop = titleH + margin
  local cellW = (LCD_W - 2 * margin) / HOTT_COLS
  local cellH = (LCD_H - gridTop - margin) / HOTT_ROWS

  for line = 0, HOTT_ROWS - 1 do
    for i = 0, HOTT_COLS - 1 do
      local value = multiBuffer(line * HOTT_COLS + 6 + i)
      local x = margin + math.floor(i * cellW)
      local y = gridTop + math.floor(line * cellH)
      if value > 0x80 then
        value = value - 0x80
        lcd.drawText(x, y, string.char(value), font + INVERS)
      else
        lcd.drawText(x, y, string.char(value), font + COLOR_THEME_PRIMARY1)
      end
    end
  end
end

-- Draw the menu grid on a monochrome display (128x64 or 212x64). The cell size
-- is derived from the screen width so the 212px wide radios use the extra room.
local function HoTT_Draw_Grid_BW()
  if multiBuffer(4) == 0xFF then
    lcd.drawText(2, 17, "No HoTT telemetry...", SMLSIZE)
    return
  end

  if Timer_128 ~= 0 then
    --Intro page
    Timer_128 = Timer_128 - 1
    lcd.drawScreenTitle("Graupner HoTT", 0, 0)
    lcd.drawText(2, 17, "Configuration of RX" .. sensor_name[HoTT_Sensor + 1], SMLSIZE)
    lcd.drawText(2, 37, "Press menu to cycle sensors", SMLSIZE)
    return
  end

  --Menu page
  local cellW = math.floor(LCD_W / HOTT_COLS)
  for line = 0, HOTT_ROWS - 1 do
    for i = 0, HOTT_COLS - 1 do
      local value = multiBuffer(line * HOTT_COLS + 6 + i)
      local x = 2 + i * cellW
      local y = 1 + 8 * line
      if value > 0x80 then
        value = value - 0x80
        lcd.drawText(x, y, string.char(value), SMLSIZE + INVERS)
      else
        lcd.drawText(x, y, string.char(value), SMLSIZE)
      end
    end
  end
end

local function HoTT_Draw_LCD()
  lcd.clear()

  if LCD_W >= 320 then
    HoTT_Draw_Grid_Color()
  else
    HoTT_Draw_Grid_BW()
  end
end

-- Init
local function HoTT_Init()
  --Set protocol to talk to
  multiBuffer( 0, string.byte('H') )
  --test if value has been written
  if multiBuffer( 0 ) ~=  string.byte('H') then
    error("Not enough memory!")
    return 2
  end
  multiBuffer( 1, string.byte('o') )
  multiBuffer( 2, string.byte('T') )
  multiBuffer( 3, string.byte('T') )
  --Request init of the RX buffer
  multiBuffer( 4, 0xFF )
  --Request RX to send the config menu
  HoTT_Send( 0x0F )
  HoTT_Sensor = 0;
  HoTT_Detected_Sensors=0;
  Timer_128 = 100
end

-- Main
local function HoTT_Run(event)
  if event == nil then
    error("Cannot be run as a model script!")
    return 2
  elseif event == EVT_VIRTUAL_EXIT then
    HoTT_Release()
    return 2
  else
    if event == EVT_VIRTUAL_PREV_PAGE then
      killEvents(event)
      HoTT_Send( 0x07 )
    elseif event == EVT_VIRTUAL_ENTER then
      HoTT_Send( 0x09 )
    elseif event == EVT_VIRTUAL_PREV then
      HoTT_Send( 0x0B )
    elseif event == EVT_VIRTUAL_NEXT then
      HoTT_Send( 0x0D )
    elseif event == EVT_VIRTUAL_NEXT_PAGE then
      HoTT_Send( 0x0E )
    elseif event == EVT_VIRTUAL_MENU then
      Timer_128 = 100
      HoTT_Sensor_Inc()
    else
      HoTT_Send( 0x0F )
    end
    HoTT_Draw_LCD()
    return 0
  end
end

return { init=HoTT_Init, run=HoTT_Run }
