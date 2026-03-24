---- #########################################################################
---- #                                                                       #
---- # Switch role reminder for RadioMaster radio                            #
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

local name = "Switch Info"
local options = {}

local rows = {}
local ver, radio, maj, minor, rev, osname = getVersion()
if (string.sub(radio, 1, 4) == "tx15") then
    -- All switch rows in one table
    rows = {
        { "SE", "S1", "S2", "SF" },
        { "SA", "SB", "SC", "SD" },
        { "SW1", "SW2", "SW3" },
        { "SW4", "SW5", "SW6" },
    }
elseif (string.sub(radio, 1, 4) == "tx16") then
    rows = {
        { "SE", "SF", "SH", "SG" },
        { "SA", "SB", "SC", "SD" },
        { "LS", "S1", "S2", "RS" },
        { "SW1", "SW2", "SW3" },
        { "SW4", "SW5", "SW6" }
    }
else
    rows = {{ "Unsupported radio" }}
end


---------------------------------------------------------------------
-- Persistence helpers
---------------------------------------------------------------------

local function saveSwitchText(widget)
    local switch_text = widget.switch_text
    local result = "{"
    for i = 1, #switch_text do
        local v = switch_text[i]
        result = result .. string.format("%q", v)
        if i < #switch_text then
            result = result .. ", "
        end
    end
    result = result .. "}"

    local file = io.open(widget.save_file, "w")
    io.write(file, result)
    io.close(file)
end


local function loadSwitchText(widget)
    local file = io.open(widget.save_file, "r")
    if file then
        widget.switch_text = {}
        local content = io.read(file, 2048)
        io.close(file)
        -- Match everything between quotes
        for str in string.gmatch(content, '"([^"]*)"') do
            table.insert(widget.switch_text, str)
        end
    else
        -- Initialize empty
        widget.switch_text = {}
        local item = 1
        local r = 1
        while rows[r] do
            local row = rows[r]
            local i = 1
            while row[i] do
                widget.switch_text[item] = ""
                item = item + 1
                i = i + 1
            end
            r = r + 1
        end
    end
end

---------------------------------------------------------------------
-- Layout helpers
---------------------------------------------------------------------

local function getFontHeight(flags)
    local _, h = lcd.sizeText("1", flags or 0)
    return h
end

local function makeBox(widget, label, idx, boxW, boxH, rh, editMode)
    local switch_text = widget.switch_text
    local empty = not switch_text[idx] or switch_text[idx] == ""
    local bg = empty and COLOR_THEME_PRIMARY2 or COLOR_THEME_SECONDARY1
    local fg = empty and COLOR_THEME_SECONDARY1 or COLOR_THEME_PRIMARY2
    local offset = (LCD_W > 480) and 3 or 1

    if editMode then
        return {
            type = "rectangle", w = boxW-offset, h = boxH-offset, scrollBar = false,
            filled = true, rounded = 5, color = COLOR_THEME_SECONDARY1,
            children = {
                { type = "label", w=boxW-2,
                  text = label, align = CENTER, color = COLOR_THEME_PRIMARY2 },
                { type = "textEdit", x=2, y = rh, w=boxW-4,
                  value = switch_text[idx],
                  set = function(val)
                      switch_text[idx] = val
                      saveSwitchText(widget)
                  end
                },
            }
        }
    else
        return {
            type = "rectangle", w = boxW-offset, h = boxH-offset, scrollBar = false,
            filled = true, rounded = 5, color = bg,
            children = {
                { type = "label", w=boxW-2,
                  text = label, align = CENTER, color = fg },
                { type = "label", y = rh, w=boxW, h=boxH,
                  text = switch_text[idx], align = CENTER, color = fg },
            }
        }
    end
end

---------------------------------------------------------------------
-- Layout builders
---------------------------------------------------------------------

local function doLayout(widget)
    if not lvgl then return end
    lvgl.clear()

    local zw, zh = widget.zone.w, widget.zone.h
    local rh = getFontHeight(STDSIZE)
    local boxH = zh / #rows
    local layout = {}

    if (lvgl.isFullScreen()) then
        boxH = (zh - rh * 2.1) / #rows
    end

    local item = 0
    for r=1, #rows, 1 do
        local row = rows[r]
        local boxW = zw / #row
        for i=1, #row, 1 do
            item = item + 1
            local label = row[i]
            local box = makeBox(widget, label, item, boxW, boxH, rh, lvgl.isFullScreen())
            box.x, box.y = (i - 1) * boxW, (r - 1) * boxH
            table.insert(layout, box)
        end
    end

    if (lvgl.isFullScreen()) then
        local pg = lvgl.page({title="Switch Info Setup"})
        pg:build(layout)
    else
        lvgl.build(layout)
    end
end

---------------------------------------------------------------------
-- Widget lifecycle
---------------------------------------------------------------------

local function create(zone, opts)
    local info = model.getInfo()
    local modelfilename = info and info.filename
    local save_file = modelfilename
        and ("/MODELS/" .. string.sub(modelfilename, 1, -5) .. ".switches")
        or "/MODELS/default.switches"
    local widget = { zone = zone, options = opts, save_file = save_file }
    loadSwitchText(widget)
    return widget
end

local function update(widget, opts)
    widget.options = opts
    doLayout(widget)
end


local function refresh(widget, event, touchState)
    -- lvgl handles redraws; nothing to do here
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
