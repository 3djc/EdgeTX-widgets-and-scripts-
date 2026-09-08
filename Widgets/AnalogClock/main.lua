---- #########################################################################
---- #                                                                       #
---- # Analog clock widget for EdgeTX colour LCD radios (LVGL)               #
---- # Copyright (C) EdgeTX                                                  #
---- #                                                                       #
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

-- Draws a round analog clock that fills the whole widget zone (and the whole
-- screen in fullscreen). The hands are lvgl lines whose "pts" parameter is a
-- function, so LVGL re-evaluates them on every refresh cycle: the layout is
-- built once in update(), never per frame.

local name = "Analog Clock"

local options = {
    { "Seconds",  BOOL,  1 },    -- show the sweeping second hand
    { "Numerals", BOOL,  1 },    -- show the hour numerals
    { "Accent",   COLOR, RED },  -- second hand + hub colour
}

-- Face colours follow the active theme so the clock fits any screen
local FACE = COLOR_THEME_PRIMARY2   -- dial background
local INK  = COLOR_THEME_PRIMARY1   -- bezel, ticks, numerals, hour/min hands

---------------------------------------------------------------------
-- Time source
---------------------------------------------------------------------

-- getDateTime() is read at most once per 10 ms tick: the three hand
-- callbacks fired within the same refresh all share one reading.
local clock = { tick = -1, dt = nil }

local function now()
    local t = getTime()
    if t ~= clock.tick or not clock.dt then
        clock.tick = t
        clock.dt = getDateTime()
    end
    return clock.dt
end

local function hourAngle()
    local t = now()
    return ((t.hour % 12) + t.min / 60 + t.sec / 3600) * 30
end

local function minuteAngle()
    local t = now()
    return (t.min + t.sec / 60) * 6
end

local function secondAngle()
    return now().sec * 6
end

---------------------------------------------------------------------
-- Geometry helpers
---------------------------------------------------------------------

-- Angle in degrees clockwise from 12 o'clock. A negative radius returns the
-- point on the opposite side of the centre, which is how hand tails are made.
local function polar(cx, cy, r, deg)
    local a = math.rad(deg)
    return cx + r * math.sin(a), cy - r * math.cos(a)
end

-- lvgl line points are read with luaL_checkunsigned, so they must be
-- non-negative integers.
local function pt(x, y)
    local ix = math.floor(x + 0.5)
    local iy = math.floor(y + 0.5)
    if ix < 0 then ix = 0 end
    if iy < 0 then iy = 0 end
    return { ix, iy }
end

local function tickSpec(cx, cy, deg, rInner, rOuter, thickness, color)
    local x1, y1 = polar(cx, cy, rInner, deg)
    local x2, y2 = polar(cx, cy, rOuter, deg)
    return {
        type = "line", color = color, thickness = thickness, rounded = true,
        pts = { pt(x1, y1), pt(x2, y2) },
    }
end

local function handSpec(cx, cy, tail, len, thickness, color, angleFn)
    return {
        type = "line", color = color, thickness = thickness, rounded = true,
        pts = function()
            local deg = angleFn()
            local x1, y1 = polar(cx, cy, -tail, deg)
            local x2, y2 = polar(cx, cy, len, deg)
            return { pt(x1, y1), pt(x2, y2) }
        end,
    }
end

local function pickFont(r)
    if r >= 140 then return DBLSIZE end
    if r >= 90 then return MIDSIZE end
    if r >= 50 then return STDSIZE end
    return SMLSIZE
end

---------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------

local function doLayout(widget)
    if not lvgl then return end
    lvgl.clear()

    local opts = widget.options or {}
    local showSeconds = (opts.Seconds or 0) ~= 0
    local showNumerals = (opts.Numerals or 0) ~= 0
    -- COLOR_THEME_PRIMARY1 encodes as flag value 0, so only nil means "unset"
    local accent = opts.Accent
    if accent == nil then accent = RED end

    local zw, zh = widget.zone.w, widget.zone.h
    local cx, cy = zw / 2, zh / 2
    local r = math.floor(math.min(zw, zh) / 2) - 1
    if r < 6 then r = 6 end

    local bezel = math.max(2, math.floor(r * 0.05))
    local tickOuter = r - bezel - math.max(1, math.floor(r * 0.03))
    local hourInner = tickOuter - math.max(3, math.floor(r * 0.12))
    local minInner = tickOuter - math.max(2, math.floor(r * 0.05))
    local hub = math.max(3, math.floor(r * 0.055))

    local layout = {}

    -- Dial and bezel
    table.insert(layout, {
        type = "circle", x = cx, y = cy, radius = r,
        color = FACE, filled = true,
    })
    table.insert(layout, {
        type = "circle", x = cx, y = cy, radius = r,
        color = INK, filled = false, thickness = bezel,
    })

    -- Minute ticks, only where they stay legible
    if r >= 55 then
        for i = 0, 59 do
            if i % 5 ~= 0 then
                table.insert(layout, tickSpec(cx, cy, i * 6, minInner, tickOuter,
                                              math.max(1, math.floor(r * 0.02)), INK))
            end
        end
    end

    -- Hour ticks
    for i = 0, 11 do
        table.insert(layout, tickSpec(cx, cy, i * 30, hourInner, tickOuter,
                                      math.max(2, math.floor(r * 0.055)), INK))
    end

    -- Numerals, inside the hour ticks
    if showNumerals then
        local font = pickFont(r)
        local tw12, th = lcd.sizeText("12", font)
        local numR = hourInner - th * 0.55 - 2
        -- Skip the numerals on dials too small to carry them in proportion
        if numR > th * 0.5 + hub and th <= r * 0.30 then
            -- Print all twelve only where they fit around the ring without
            -- crowding, otherwise fall back to the cardinal hours
            local step = (2 * math.pi * numR / 12 >= tw12 * 1.5) and 1 or 3
            for i = 1, 12 do
                if i % step == 0 then
                    local txt = tostring(i)
                    local tw = lcd.sizeText(txt, font)
                    local bw = tw + 4
                    local px, py = polar(cx, cy, numR, i * 30)
                    table.insert(layout, {
                        type = "label", text = txt, font = font, color = INK,
                        x = math.floor(px - bw / 2), y = math.floor(py - th / 2),
                        w = bw, align = CENTER,
                    })
                end
            end
        end
    end

    -- Hands, drawn back to front
    table.insert(layout, handSpec(cx, cy, r * 0.13, r * 0.52,
                                  math.max(3, math.floor(r * 0.075)), INK, hourAngle))
    table.insert(layout, handSpec(cx, cy, r * 0.15, r * 0.75,
                                  math.max(2, math.floor(r * 0.05)), INK, minuteAngle))
    if showSeconds then
        table.insert(layout, handSpec(cx, cy, r * 0.22, tickOuter,
                                      math.max(1, math.floor(r * 0.022)), accent, secondAngle))
    end

    -- Centre hub caps the hand pivots
    table.insert(layout, {
        type = "circle", x = cx, y = cy, radius = hub,
        color = INK, filled = true,
    })
    if showSeconds and hub > 3 then
        table.insert(layout, {
            type = "circle", x = cx, y = cy, radius = math.max(1, math.floor(hub * 0.45)),
            color = accent, filled = true,
        })
    end

    lvgl.build(layout)
end

---------------------------------------------------------------------
-- Widget lifecycle
---------------------------------------------------------------------

local function create(zone, opts)
    return { zone = zone, options = opts }
end

local function update(widget, opts)
    widget.options = opts
    doLayout(widget)
end

local function refresh(widget, event, touchState)
    -- Hand positions come from the lvgl "pts" callbacks; nothing to do here
end

local function background(widget)
    -- no background processing needed
end

return {
    name = name,
    options = options,
    create = create,
    update = update,
    refresh = refresh,
    background = background,
    useLvgl = true,
}
