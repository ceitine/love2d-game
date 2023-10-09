local align = {}
ALIGN = {
    HORIZONTAL = {
        LEFT = 1,
        CENTER = 2,
        RIGHT = 3,
    },

    VERTICAL = {
        TOP = 1,
        MIDDLE = 2,
        BOTTOM = 3,
    }
}

function align.calc_text(string, font, x, y, scale)
    -- alignment lookups
    local horizontal = {
        [ALIGN.HORIZONTAL.LEFT] = function()
            return 0
        end,

        [ALIGN.HORIZONTAL.CENTER] = function()
            return font:getWidth(string) / 2
        end,

        [ALIGN.HORIZONTAL.RIGHT] = function()
            return font:getWidth(string)
        end,
    }

    local vertical = {
        [ALIGN.VERTICAL.TOP] = function()
            return 0
        end,

        [ALIGN.VERTICAL.MIDDLE] = function()
            return font:getHeight(string) / 2
        end,

        [ALIGN.VERTICAL.BOTTOM] = function()
            return font:getHeight(string)
        end,
    }   

    -- safe variables
    scale = scale or 1
    x = x or ALIGN.VERTICAL.LEFT
    y = y or ALIGN.HORIZONTAL.TOP
    if(horizontal[x] == nil or vertical[y] == nil) then
        return {x = 0, y = 0}
    end

    return {
        x = horizontal[x]() * scale,
        y = vertical[y]() * scale
    }
end

return align