local chunk = require("render/chunk")
local physicsobj = require("physics/physicsobj")
local scene = {}
local mt = {
    -- index data
    __index = scene,
}

-- variables
scene.chunks = nil
scene.flat_chunks = nil

-- create new scene
function scene:create(o)
    local instance = o or {}
    instance.chunks = {}
    instance.entities = {}
    instance.flat_chunks = {}
    instance.objects = {}

    local size = 3
    local min = math.floor(-size / 2)
    local max = math.floor(size / 2)
    for x = min, max do
        for y = min, max do
            instance.flat_chunks[y * (size + 1) + x] = chunk.new(x, y, instance)
        end
    end

    setmetatable(instance, mt)
    self.__index = instance
    return instance
end

function scene.new()
    local instance = scene:create()
    SCENE = instance
    return instance
end

-- instance functions
function scene:query_pos(x, y) -- this is in tile space!
    local result = {}
    result.position = {
        x = math.floor((x - 1) / chunk.WIDTH),
        y = math.floor((y - 1) / chunk.HEIGHT)
    }

    local chunk_row = self.chunks[result.position.x]
    result.chunk = chunk_row and chunk_row[result.position.y]

    result.tile_position = {
        x = (math.floor(x - 1) % chunk.WIDTH + chunk.WIDTH) % chunk.WIDTH + 1,
        y = (math.floor(y - 1) % chunk.HEIGHT + chunk.HEIGHT) % chunk.HEIGHT + 1
    }

    result.tile = result.chunk and result.chunk:get_tile(result.tile_position.x, result.tile_position.y)

    return result
end

function scene:raycast(from, to, capture_path) -- this is in tile space!    
    -- some initial variables
    local result = {
        position = {x = from.x, y = from.y},
        tile_position = {x = 0, y = 0},
        normal = {x = 0, y = 0},
        hit = false
    }

    local length = math.sqrt(math.pow(to.x - from.x, 2) + math.pow(to.y - from.y, 2))

    if(capture_path) then 
        result.path = { {x = math.floor(result.position.x), y = math.floor(result.position.y)} } 
    end

    -- lets get the direction..
    local dirX, dirY = (to.x - from.x) / length, (to.y - from.y) / length
    local stepX, stepY
    local tMaxX, tMaxY
    local tDeltaX, tDeltaY

    if(dirX >= 0) then
        stepX = 1.0
        tMaxX = (math.floor(result.position.x) + 1 - result.position.x) / dirX
        tDeltaX = 1.0 / dirX
    else
        stepX = -1.0
        tMaxX = (result.position.x - math.floor(result.position.x)) / -dirX
        tDeltaX = 1.0 / -dirX
    end

    if(dirY >= 0) then
        stepY = 1.0
        tMaxY = (math.floor(result.position.y) + 1 - result.position.y) / dirY
        tDeltaY = 1.0 / dirY
    else
        stepY = -1.0
        tMaxY = (result.position.y - math.floor(result.position.y)) / -dirY
        tDeltaY = 1.0 / -dirY
    end

    -- travel our ray!
    local dist_travelled = 0
    while(math.abs(dist_travelled) <= length) do
        local query = self:query_pos(
            math.floor(result.position.x), 
            math.floor(result.position.y)
        )
        
        -- we have a collision!
        if(query.chunk ~= nil and query.tile ~= nil) then
            result.chunk = query.chunk
            result.tile = query.tile
            result.tile_position = query.tile_position
            result.hit_position = {x = dirX * dist_travelled + from.x, y = dirY * dist_travelled + from.y}
            result.hit = true
            return result
        end

        -- step
        if(tMaxX < tMaxY) then
            result.position.x = result.position.x + stepX
            dist_travelled = tMaxX
            tMaxX = tMaxX + tDeltaX
            result.normal = {x = -math.floor(stepX), y = 0}
        else
            result.position.y = result.position.y + stepY
            dist_travelled = tMaxY
            tMaxY = tMaxY + tDeltaY
            result.normal = {x = 0, y = -math.floor(stepY)}
        end

        -- capture path
        if(capture_path) then 
            result.path[#result.path + 1] = {x = result.position.x, y = result.position.y}
        end
    end

    if(capture_path) then result.path[#result.path] = nil end

    return result
end

function scene:render(x, y, scale)
    -- draw chunks
    render.set_shader(chunk.shader)
    for _, chunk in pairs(self.flat_chunks) do
        chunk:render(x, y, scale)
    end
    render.set_shader()

    --[[
    for _, chunk in pairs(self.flat_chunks) do
        for _, v in pairs(chunk.quads) do 
            local col = color.from32(mathx.random(0, 16000000, v.x + v.y + v.w + v.h)):with_alpha(150)
            render.rectangle(x + (v.x - 1 + chunk.x * chunk.WIDTH) * scale, y + (v.y - 1 + chunk.y * chunk.HEIGHT) * scale, v.w * scale, v.h * scale, col)
        end
    end
    --]]
end

local spawned = false
function scene:update(dt)
    -- spawn some debug objects
    if(love.keyboard.isDown("space")) then
        if(not spawned) then
            self.objects[#self.objects + 1] = physicsobj.new(COLLIDER_RECT, {x = CAMERA.position.x, y = CAMERA.position.y}, math.random(2, 5), math.random(1, 5), 0)
            spawned = true
        end
    else 
        spawned = false
    end

    -- update all physics objects
    for _, obj in pairs(self.objects) do
        -- suck objects in towards mouse
        if(love.mouse.isDown(3)) then
            local force_strength = 0.2
            local mouse_world = CAMERA:to_world(love.mouse.getX(), love.mouse.getY())
            local direction = {
                x = mouse_world.x - obj.position.x,
                y = mouse_world.y - obj.position.y
            }
            local direction_length = math.sqrt(math.pow(direction.x, 2) + math.pow(direction.y, 2))
            direction.x = direction.x / direction_length
            direction.y = direction.y / direction_length

            obj:apply_force(direction.x * force_strength, direction.y * force_strength)
        end

        
        obj:step(dt)
    end
end

return scene