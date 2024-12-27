-- math, utility, rendering includes
require("util/constants")

mathx = require("util/mathx")
vec2 = require("util/vec2")
hook = require("util/hook")
stringx = require("util/stringx")
color = require("render/color")
render = require("render/render")
time = require("util/time")
scenecamera = require("scene/scenecamera")
scene = require("scene/scene")

-- love
love.load = function()
    hook.call(HOOK_LOAD)
end

love.update = function(dt)
    time.delta = dt
    time.now = time.now + dt

    hook.call(HOOK_UPDATE, dt)
end

love.draw = function()
    hook.call(HOOK_DRAW)
end

love.wheelmoved = function(x, y)
    hook.call(HOOK_WHEELMOVED, x, y)
end

-- testing :D
local world = scene.new()
local camera = scenecamera.new()
camera.scene = world

hook.register("world_render", HOOK_DRAW, function() if(camera) then camera:render() end end)

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
local camera_settings = {
    scale_option = center_index,

    target = {
        x = 0,
        y = 0
    },

    drag = nil,
}

hook.register("scene_update", "update", function(dt)
    -- update scene
    world:update(dt)

    -- some camera movement :D
    local target = scale_options[camera_settings.scale_option]
    camera.scale = mathx.lerp(camera.scale, target, time.delta * 8)

    camera.position.x = mathx.lerp(camera.position.x, camera_settings.target.x, time.delta * 8)
    camera.position.y = mathx.lerp(camera.position.y, camera_settings.target.y, time.delta * 8)

    if(love.mouse.isDown(1)) then
        if(camera_settings.drag == nil) then
            camera_settings.drag = {
                x = love.mouse.getX(),
                y = love.mouse.getY(),
                old = {x = camera.position.x * camera.scale, y = camera.position.y * camera.scale, scale = camera.scale},
            }
        end

        local scale = 1 / camera_settings.drag.old.scale
        local dx = camera_settings.drag.x - love.mouse.getX()
        local dy = camera_settings.drag.y - love.mouse.getY()

        camera_settings.target.x = camera_settings.drag.old.x * scale + dx * scale
        camera_settings.target.y = camera_settings.drag.old.y * scale + dy * scale
    else
        camera_settings.drag = nil

        local speed = 15
        local wishX = love.keyboard.isDown("d") 
            and 1
            or love.keyboard.isDown("a") 
                and -1
                or 0

        local wishY = love.keyboard.isDown("w") 
            and -1
            or love.keyboard.isDown("s") 
                and 1
                or 0

        if(wishX ~= 0) then
            camera_settings.target.x = camera_settings.target.x + wishX * dt * speed
        end

        if(wishY ~= 0) then
            camera_settings.target.y = camera_settings.target.y + wishY * dt * speed
        end
    end
end)

hook.register("camera_wheel", "wheelmoved", function(x, y)
    camera_settings.scale_option = math.min(math.max(camera_settings.scale_option + y, 1), #scale_options)
end)
