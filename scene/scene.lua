local chunk = require("render/chunk")
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

    local size = 4
    for x = 0, size do
        for y = 0, size do
            instance.flat_chunks[y * (size + 1) + x] = chunk.new(x, y, instance.chunks)
        end
    end

    setmetatable(instance, mt)
    self.__index = instance
    return instance
end

function scene.new()
    local instance = scene:create()
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
    local length = math.sqrt(math.pow(to.x - from.x, 2) + math.pow(to.y - from.y, 2))
    local dirX, dirY = (to.x - from.x) / length, (to.y - from.y) / length

    local stepX, stepY
    local tMaxX, tMaxY
    local tDeltaX, tDeltaY

    local result = {
        position = {x = from.x, y = from.y},
        tile_position = {x = 0, y = 0},
        normal = {x = 0, y = 0},
        hit = false
    }

    if(capture_path) then result.path = {} end

    -- lets get the direction..
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

    if(capture_path and #result.path == 0) then
        result.path[0] = {x = math.floor(result.position.x), y = math.floor(result.position.y)}
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
            result.hit_position = {x = dirX * dist_travelled, y = dirY * dist_travelled}
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

    for _, chunk in pairs(self.flat_chunks) do
        for _, v in pairs(chunk.quads) do 
            local col = color.from32(mathx.random(0, 16000000, v.x + v.y + v.w + v.h)):with_alpha(150)
            render.rectangle(x + (v.x - 1 + chunk.x * chunk.WIDTH) * scale, y + (v.y - 1 + chunk.y * chunk.HEIGHT) * scale, v.w * scale, v.h * scale, col)
        end
    end
end

return scene