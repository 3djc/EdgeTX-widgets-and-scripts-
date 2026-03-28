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
-- Cells Values - BW 128x64 telemetry script
-- Equivalent of the CellsValues color LCD widget for BW displays (128x64).
-- Place this file in /SCRIPTS/TELEMETRY/ on the SD card.
--
-- Layout (2-column, each column 64px wide):
--   [n] V.VV [=====   ]   [n] V.VV [=====   ]
--   ...
--   XX%  T:VV.VVV  D:D.DD
--
-- [ENTER] toggles between LiPo and LiPo-HV chemistry.
-- [EXIT]  leaves the telemetry page.
--
-- When the delta between the lowest and highest cell exceeds 0.1V,
-- the delta value is displayed inverted as a warning.
--

local T            = {}
local cellsT       = {}
local deltawarning = false
local battchemistry = 1    -- 1 = LiPo,  2 = LiPo-HV;  toggle with [ENTER]

local COL_W  = 64          -- half of the 128px screen width
local ROW_H  = 9           -- pixel height per cell row  (SMLSIZE ~7px + 2px gap)
local BAR_H  = 5           -- height of the percentage bar
local BAR_X  = 29          -- bar start offset within a column (after num + voltage)
local BAR_W  = COL_W - BAR_X - 1   -- bar width (fits remaining column pixels)

-- ── Sensor helpers ──────────────────────────────────────────────────────────

local function getCellsSensor()
    local val = getValue("Cels")
    T = (type(val) == "table") and val or {}
end

local function getCellCount()
    return (type(T) == "table") and #T or 0
end

local function getCellMinMax()
    if type(T) ~= "table" or #T == 0 then return 0, 0 end
    local min, max = T[1], T[1]
    for i = 2, #T do
        if T[i] < min then min = T[i] end
        if T[i] > max then max = T[i] end
    end
    return min, max
end

local function getCellTotal()
    if type(T) ~= "table" then return 0 end
    local sum = 0
    for i = 1, #T do sum = sum + T[i] end
    return sum
end

-- ── Percentage lookup (same discharge curves as the color widget) ────────────

local function getCellPercent(cellvalue)
    if not cellvalue or cellvalue <= 0 or #cellsT == 0 then return 0 end
    local lastpercentage = 0
    for i = 1, #cellsT do
        for j = 1, #cellsT[i] do
            if cellvalue >= cellsT[i][j][1] then
                lastpercentage = cellsT[i][j][2]
            else
                return lastpercentage
            end
        end
    end
    return 100
end

local function getCellTotalPercent()
    local count = getCellCount()
    if count == 0 then return 0 end
    return getCellPercent(getCellTotal() / count)
end

-- ── Discharge tables ─────────────────────────────────────────────────────────

local function buildCellsTable()
    if battchemistry == 2 then
        -- LiPo HV (4.35 V max)
        cellsT = {
            { {3.000,  0}},
            { {3.093,  1}, {3.196,  2}, {3.301,  3}, {3.401,  4}, {3.477,  5}, {3.544,  6}, {3.601,  7}, {3.637,  8}, {3.664,  9}, {3.679, 10} },
            { {3.683, 11}, {3.689, 12}, {3.692, 13}, {3.705, 14}, {3.710, 15}, {3.713, 16}, {3.715, 17}, {3.720, 18}, {3.731, 19}, {3.735, 20} },
            { {3.744, 21}, {3.753, 22}, {3.756, 23}, {3.758, 24}, {3.762, 25}, {3.767, 26}, {3.774, 27}, {3.780, 28}, {3.783, 29}, {3.786, 30} },
            { {3.789, 31}, {3.794, 32}, {3.797, 33}, {3.800, 34}, {3.802, 35}, {3.805, 36}, {3.808, 37}, {3.811, 38}, {3.815, 39}, {3.828, 40} },
            { {3.832, 41}, {3.836, 42}, {3.841, 43}, {3.846, 44}, {3.850, 45}, {3.855, 46}, {3.859, 47}, {3.864, 48}, {3.868, 49}, {3.873, 50} },
            { {3.877, 51}, {3.881, 52}, {3.885, 53}, {3.890, 54}, {3.895, 55}, {3.900, 56}, {3.907, 57}, {3.917, 58}, {3.924, 59}, {3.929, 60} },
            { {3.936, 61}, {3.942, 62}, {3.949, 63}, {3.957, 64}, {3.964, 65}, {3.971, 66}, {3.984, 67}, {3.990, 68}, {3.998, 69}, {4.006, 70} },
            { {4.015, 71}, {4.024, 72}, {4.032, 73}, {4.042, 74}, {4.050, 75}, {4.060, 76}, {4.069, 77}, {4.078, 78}, {4.088, 79}, {4.098, 80} },
            { {4.109, 81}, {4.119, 82}, {4.130, 83}, {4.141, 84}, {4.154, 85}, {4.169, 86}, {4.184, 87}, {4.197, 88}, {4.211, 89}, {4.220, 90} },
            { {4.229, 91}, {4.237, 92}, {4.246, 93}, {4.254, 94}, {4.264, 95}, {4.278, 96}, {4.302, 97}, {4.320, 98}, {4.339, 99}, {4.350,100} },
        }
    else
        -- LiPo standard (4.20 V max)
        cellsT = {
            { {3.000,  0}},
            { {3.093,  1}, {3.196,  2}, {3.301,  3}, {3.401,  4}, {3.477,  5}, {3.544,  6}, {3.601,  7}, {3.637,  8}, {3.664,  9}, {3.679, 10} },
            { {3.683, 11}, {3.689, 12}, {3.692, 13}, {3.705, 14}, {3.710, 15}, {3.713, 16}, {3.715, 17}, {3.720, 18}, {3.731, 19}, {3.735, 20} },
            { {3.744, 21}, {3.753, 22}, {3.756, 23}, {3.758, 24}, {3.762, 25}, {3.767, 26}, {3.774, 27}, {3.780, 28}, {3.783, 29}, {3.786, 30} },
            { {3.789, 31}, {3.794, 32}, {3.797, 33}, {3.800, 34}, {3.802, 35}, {3.805, 36}, {3.808, 37}, {3.811, 38}, {3.815, 39}, {3.818, 40} },
            { {3.822, 41}, {3.825, 42}, {3.829, 43}, {3.833, 44}, {3.836, 45}, {3.840, 46}, {3.843, 47}, {3.847, 48}, {3.850, 49}, {3.854, 50} },
            { {3.857, 51}, {3.860, 52}, {3.863, 53}, {3.866, 54}, {3.870, 55}, {3.874, 56}, {3.879, 57}, {3.888, 58}, {3.893, 59}, {3.897, 60} },
            { {3.902, 61}, {3.906, 62}, {3.911, 63}, {3.918, 64}, {3.923, 65}, {3.928, 66}, {3.939, 67}, {3.943, 68}, {3.949, 69}, {3.955, 70} },
            { {3.961, 71}, {3.968, 72}, {3.974, 73}, {3.981, 74}, {3.987, 75}, {3.994, 76}, {4.001, 77}, {4.007, 78}, {4.014, 79}, {4.021, 80} },
            { {4.029, 81}, {4.036, 82}, {4.044, 83}, {4.052, 84}, {4.062, 85}, {4.074, 86}, {4.085, 87}, {4.095, 88}, {4.105, 89}, {4.111, 90} },
            { {4.116, 91}, {4.120, 92}, {4.125, 93}, {4.129, 94}, {4.135, 95}, {4.145, 96}, {4.176, 97}, {4.179, 98}, {4.193, 99}, {4.200,100} },
        }
    end
end

-- ── Script entry points ───────────────────────────────────────────────────────

local function init()
    buildCellsTable()
end

local function run(event)
    if event == EVT_VIRTUAL_EXIT then
        return 2
    end

    -- [ENTER] toggles LiPo / LiPo-HV
    if event == EVT_VIRTUAL_ENTER then
        battchemistry = (battchemistry == 1) and 2 or 1
        buildCellsTable()
    end

    getCellsSensor()
    lcd.clear()

    local count = getCellCount()

    if count == 0 then
        lcd.drawText(2, 28, "No Cells sensor", SMLSIZE)
        return 0
    end

    -- ── Cell rows (2-column layout, max 8 cells = 4 rows) ───────────────────
    for c = 1, math.min(count, 8) do
        local col = (c - 1) % 2       -- 0 = left,  1 = right
        local row = (c - 1) // 2      -- 0 … 3
        local x   = col * COL_W
        local y   = row * ROW_H

        -- Cell index
        lcd.drawText(x, y, c, SMLSIZE)

        -- Cell voltage  e.g. "4.18"
        lcd.drawText(x + 7, y, string.format("%1.2f", T[c]), SMLSIZE)

        -- Percentage bar
        local pct  = getCellPercent(T[c])
        local bx   = x + BAR_X
        local by   = y + 2
        lcd.drawRectangle(bx, by, BAR_W, BAR_H)
        local fill = math.max(0, math.floor((BAR_W - 2) * pct / 100))
        if fill > 0 then
            lcd.drawFilledRectangle(bx + 1, by + 1, fill, BAR_H - 2)
        end
    end

    -- ── Summary row ─────────────────────────────────────────────────────────
    local rows      = math.ceil(math.min(count, 8) / 2)
    local sy        = rows * ROW_H + 1

    local totalPct  = getCellTotalPercent()
    local total     = getCellTotal()
    local cmin, cmax = getCellMinMax()
    local delta     = cmax - cmin
    deltawarning    = delta > 0.1

    -- Total voltage and delta on the summary row
    lcd.drawText(0,  sy, string.format("T:%2.2fV", total), SMLSIZE)
    local dflags = deltawarning and (SMLSIZE + INVERS) or SMLSIZE
    lcd.drawText(55, sy, string.format("D:%1.2f", delta), dflags)

    -- ── Chemistry indicator (end of summary row) ─────────────────────────────
    local chemStr = (battchemistry == 2) and "HV" or "LP"
    lcd.drawText(LCD_W - 13, sy, chemStr, SMLSIZE + INVERS)

    -- ── Total percentage: large, centred at the bottom ───────────────────────
    -- MIDSIZE character width is approx 9px on BW displays
    local pctStr = string.format("%d%%", totalPct)
    local pctX   = math.max(0, (LCD_W - #pctStr * 9) // 2)
    lcd.drawText(pctX, LCD_H - 12, pctStr, MIDSIZE)

    -- ── Virtual % telemetry sensor (same as the color widget) ────────────────
    setTelemetryValue(0x0310, 0, 1, totalPct, 13, 0, "%bat")

    return 0
end

return { init = init, run = run }
