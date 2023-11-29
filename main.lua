-- math, utility, rendering includes
mathx = require("util/mathx")
hook = require("util/hook")
stringx = require("util/stringx")
color = require("render/color")
render = require("render/render")
time = require("util/time")

-- love
love.load = function()
    hook.call("load")
end

love.update = function(dt)
    time.delta = dt
    time.now = time.now + dt

    hook.call("update", dt)
end

love.draw = function()
    hook.call("draw")
end

love.wheelmoved = function(x, y)
    hook.call("wheelmoved", x, y)
end

-- testing :D
chunk = require("render/chunk")

local chunks = {}
local size = 4
for x = 0, size do
    for y = 0, size do
        chunks[y * (size + 1) + x] = chunk.new(x, y)
    end
end

local scale_options = {
    8,
    12,
    14,
    16,
    20,
    26,
    32
}

local center_index = math.ceil(#scale_options / 2)
local center = scale_options[center_index]

local camera = {
    x = 0,
    y = 0,
    
    scale = center,
    scale_option = center_index,

    target = {
        x = 0,
        y = 0
    },

    drag = nil,
}

hook.register("", "draw", function()
    render.setcol(color.WHITE)
    for _, chunk in pairs(chunks) do
        local x = camera.x * camera.scale + love.graphics.getWidth() / 2
        local y = camera.y * camera.scale + love.graphics.getHeight() / 2
        chunk:render(x, y, camera.scale)
    end
    render.set_shader()

    render.string(math.floor(1 / time.delta), 0, 0, color.new(60, 200, 60), 0.8)
    render.rectangle(love.graphics.getWidth() / 2 - 1, love.graphics.getHeight() / 2 - 1, 2, 2, color.WHITE)
end)

hook.register("", "update", function(dt)
    local target = scale_options[camera.scale_option]
    camera.scale = mathx.lerp(camera.scale, target, time.delta * 8)

    camera.x = mathx.lerp(camera.x, camera.target.x, time.delta * 8)
    camera.y = mathx.lerp(camera.y, camera.target.y, time.delta * 8)

    if(love.mouse.isDown(1)) then
        if(camera.drag == nil) then
            camera.drag = {
                x = love.mouse.getX(),
                y = love.mouse.getY(),
                old = {x = camera.x * camera.scale, y = camera.y * camera.scale},
            }
        end

        local scale = 1 / camera.scale
        local dx = love.mouse.getX() - camera.drag.x
        local dy = love.mouse.getY() - camera.drag.y

        camera.target.x = camera.drag.old.x * scale + dx * scale
        camera.target.y = camera.drag.old.y * scale + dy * scale
    else
        camera.drag = nil
    end
end)

hook.register("", "wheelmoved", function(x, y)
    camera.scale_option = math.min(math.max(camera.scale_option + y, 1), #scale_options)
end)