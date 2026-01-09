align = require("render/align")

local render = {}
render.DEFAULT_FONT = love.graphics.newImageFont("assets/font.png", " abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,!?-+/():;%&`'*#=[]\"äöÄÖ")
render.DEFAULT_FONT:setFilter("nearest", "nearest")

function render.setcol(col)
    love.graphics.setColor(col.r / 255, col.g / 255, col.b / 255, col.a / 255)
end

function render.line(x1, y1, x2, y2, col)
    render.setcol(col or color.WHITE)
    love.graphics.line(x1, y1, x2, y2)
end

function render.string(text, x, y, col, scale, rotation, align_horizontal, align_vertical)
    -- null check some variables
    col = col or color.WHITE
    scale = scale or 1
    rotation = rotation or 0
    text = tostring(text)

    -- draw
    render.setcol(col)
    local origin = align.calc_text(text, render.DEFAULT_FONT, align_horizontal or ALIGN.HORIZONTAL.LEFT, align_vertical or ALIGN.VERTICAL.TOP)
    love.graphics.print(
        text, 
        x + origin.x, y + origin.y, 
        math.rad(rotation), 
        scale, scale, 
        origin.x,
        origin.y
    )
end

function render.get_text_size(text, font)
    font = font or render.DEFAULT_FONT
    return {
        x = font:getWidth(text),
        y = font:getHeight(text)
    }
end

function render.rectangle(x, y, w, h, col, mode)
    render.setcol(col or color.WHITE)
    love.graphics.rectangle(mode or "fill", x, y, w, h)
end

function render.circle(x, y, radius, col, mode)
    render.setcol(col or color.WHITE)
    love.graphics.circle(mode or "fill", x, y, radius)
end

function render.set_shader(shader)
    love.graphics.setShader(shader)
end

-- set font
hook.register("render_load", HOOK_LOAD, love.graphics.setFont(render.DEFAULT_FONT))

return render