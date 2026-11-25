-- The preview and live marks use the same art, sizes and colors.
local _, A = ...
A.IconSizes = { { "corner", "Small corner" }, { "medium", "Medium corner" }, { "full", "Full item icon" } }
A.iconSizeLabels = {}
for _, option in ipairs(A.IconSizes) do A.iconSizeLabels[option[1]] = option[2] end

function A.MediumMarkSize(extent)
    return math.min(26, math.max(1, extent - 1), math.max(16, math.floor(extent * .65 + .5)))
end
local gold, red, blue, violet = { 1, .82, .22 }, { 1, .39, .32 }, { .33, .76, 1 }, { .82, .49, 1 }
A.Themes = {
    Classic = { locked = { 1, .78, .25 }, junk = { .88, .53, .47 }, mail = { .93, .84, .65 }, disenchant = { .86, .71, .94 } },
    Minimal = { locked = { .95, .95, .95 }, junk = { .65, .65, .65 }, mail = { .8, .8, .8 }, disenchant = { .9, .9, .9 } },
    Colorful = { locked = gold, junk = red, mail = blue, disenchant = violet },
    Heraldry = { art = "Heraldry", locked = { 1, .83, .35 }, junk = { 1, .46, .39 }, mail = { .5, .74, 1 }, disenchant = violet },
    Runic = { art = "Runic", locked = { .76, .64, 1 }, junk = { 1, .46, .63 }, mail = { .45, .96, 1 }, disenchant = { 1, .84, .43 } },
    Workshop = { art = "Workshop", locked = { 1, .78, .46 }, junk = { .95, .51, .31 }, mail = { .69, .89, .88 }, disenchant = violet },
    Ledger = { art = "Ledger", locked = { .57, .96, .69 }, junk = { 1, .46, .4 }, mail = { .59, .81, 1 }, disenchant = violet },
    Nautical = { art = "Nautical", locked = { .69, .93, 1 }, junk = { 1, .67, .45 }, mail = { .47, .95, .76 }, disenchant = violet },
    Postage = { art = "Postage", locked = { 1, .85, .59 }, junk = { 1, .55, .56 }, mail = { .81, .76, 1 }, disenchant = { .55, .92, .77 } },
    Border = { texture = "Border", fullSize = true, locked = gold, junk = red, mail = blue, disenchant = violet },
    Circles = { texture = "Circles", locked = gold, junk = red, mail = blue, disenchant = violet },
    Letters = { art = "Letters", locked = gold, junk = red, mail = blue, disenchant = violet },
}
A.themeOrder = { "Classic", "Minimal", "Colorful", "Heraldry", "Runic", "Workshop", "Ledger", "Nautical", "Postage", "Border", "Circles", "Letters" }
local paths = { locked = "Lock", junk = "Junk", mail = "Mail", disenchant = "Disenchant" }

function A.MarkSize()
    return A.Themes[A.db.theme].fullSize and "full" or A.db.iconSize
end

function A.MarkAlpha(size, theme)
    return size == "full" and not A.Themes[theme].fullSize and .6 or 1
end

function A.PaintIcon(texture, state, theme)
    -- An explicit theme paints settings previews without changing the selection.
    local palette = A.Themes[theme or A.db.theme]
    local colors = palette[state]
    local file = palette.texture or (palette.art or "") .. paths[state]
    texture:SetTexture("Interface\\AddOns\\" .. A.name .. "\\Media\\" .. file .. ".tga")
    texture:SetVertexColor(colors[1], colors[2], colors[3], 1)
end

function A.CycleTheme()
    for i, name in ipairs(A.themeOrder) do
        if name == A.db.theme then A.SetOption("theme", A.themeOrder[i % #A.themeOrder + 1]); return end
    end
end
