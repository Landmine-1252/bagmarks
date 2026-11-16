-- All themes share the same three icon shapes and differ only in their RGB
-- tint. Preview swatches and live item overlays use the same painting function.
local _, A = ...
A.Themes = {
    Classic = { locked = { 1, .78, .25 }, junk = { .72, .36, .32 }, mail = { .9, .8, .57 } },
    Minimal = { locked = { .95, .95, .95 }, junk = { .65, .65, .65 }, mail = { .8, .8, .8 } },
    Colorful = { locked = { 1, .82, .08 }, junk = { 1, .24, .2 }, mail = { .2, .65, 1 } },
}
local paths = { locked = "Lock", junk = "Junk", mail = "Mail" }

function A.PaintIcon(texture, state, theme)
    -- An explicit theme paints settings previews without changing the selection.
    local colors = A.Themes[theme or A.db.theme][state]
    texture:SetTexture("Interface\\AddOns\\" .. A.name .. "\\Media\\" .. paths[state] .. ".tga")
    texture:SetVertexColor(colors[1], colors[2], colors[3], 1)
end

function A.CycleTheme()
    local nextTheme = { Classic = "Minimal", Minimal = "Colorful", Colorful = "Classic" }
    A.SetOption("theme", nextTheme[A.db.theme])
end
