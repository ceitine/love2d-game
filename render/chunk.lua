tile = require("render/tile")
textureatlas = require("render/textureatlas")
vertexbuffer = require("render/vertexbuffer")

local all = {}
local chunk = {}
chunk.all = all
chunk.lightmap = nil
chunk.tiles = nil
chunk.x = 0
chunk.y = 0
chunk.tile_count = 0

local mt = {
    -- index data
    __index = chunk,
}

-- defaults, note: the limit for these is the max value of an 8-bit integer
local WIDTH, HEIGHT = 32, 32
TEXTURE_ATLAS = TEXTURE_ATLAS or textureatlas.new("assets/atlas.png", 8)

chunk.WIDTH = WIDTH
chunk.HEIGHT = HEIGHT

-- shader
local vtx_format = {
    {"VertexPosition", "float", 2},
    {"VertexTexCoord", "float", 3}
}

chunk.shader = chunk.shader or love.graphics.newShader("shaders/chunk.glsl")

-- greedy meshing
local function tile_match(left, right)
    return left ~= nil and right ~= nil
       and left.texture_index == right.texture_index
end

local function try_spread_x(chunk, can_spread, tested, start, size, start_tile)
    local y_limit = start.y + size.y - 1
    for y = start.y, y_limit do
        if(not can_spread.x) then
            break
        end

        local new_x = start.x + size.x 
        local tile = chunk:get_tile(new_x, y)
        if(tested[new_x] == nil) then
            tested[new_x] = {}
        end
        
        if(new_x > WIDTH or tested[new_x][y] or not tile_match(start_tile, tile)) then
            can_spread.x = false
        end
    end

    if(can_spread.x) then
        for y = start.y, y_limit do
            local new_x = start.x + size.x
            tested[new_x][y] = true

            if(chunk:get_tile(new_x, y) == nil) then
                return false
            end
        end

        size.x = size.x + 1
    end

    return can_spread.x
end

local function try_spread_y(chunk, can_spread, tested, start, size, start_tile)
    local x_limit = start.x + size.x - 1
    for x = start.x, x_limit do
        if(not can_spread.y) then
            break
        end

        local new_y = start.y + size.y 
        local tile = chunk:get_tile(x, new_y)
        if(new_y > HEIGHT or tested[x][new_y] or not tile_match(start_tile, tile)) then
            can_spread.y = false
        end
    end

    if(can_spread.y) then
        for x = start.x, x_limit do
            local new_y = start.y + size.y
            tested[x][new_y] = true

            if(chunk:get_tile(x, new_y) == nil) then
                return false
            end
        end

        size.y = size.y + 1
    end

    return can_spread.y
end

-- functions
local function set_chunk_at(x, y, chunk, all)
    -- append new row
    if(all[x] == nil) then
        all[x] = {}
    end

    -- append chunk
    all[x][y] = chunk
end

local function get_chunk_at(x, y)
    if(all[x] == nil) then return nil end
    return all[x][y]
end

function chunk:create(o)
    local instance = o or {}
    setmetatable(instance, mt)
    self.__index = instance
    return instance
end

function chunk.new(x, y, scene)
    local instance = chunk:create()
    instance.x = x or 0
    instance.y = y or 0
    instance.all = (scene and scene.chunks) or chunk.all
    instance.scene = scene
    instance.tiles = {}
    
    for x = 1, WIDTH do
        for y = 1, HEIGHT do
            local noise = love.math.noise(x / WIDTH + instance.x, y / HEIGHT + instance.y)
            if(noise < 0.3) then 
                local index = noise > 0.1 and 1 or 0
                instance:set_tile(tile.new(index), x, y)
            end
        end
    end
    
    set_chunk_at(x, y, instance, instance.all)

    return instance
end

function chunk:set_tile(tile, x, y)
    -- append new row
    if(self.tiles[y] == nil and tile ~= nil) then
        self.tiles[y] = {}
    end

    -- append tile
    self.tiles[y][x] = tile
    self.tile_count = self.tile_count + (tile ~= nil and 1 or -1)
end

function chunk:get_tile(x, y)
    -- check if within bounds
    if(self.tiles[y] == nil) then
        return nil
    end

    -- return tile
    return self.tiles[y][x]
end

function chunk:get_neighbors(x, y, includeSelf)
    --[[ directions
        vec2(1, 0),
        vec2(-1, 0),
        vec2(0, 1 ),
        vec2(0, -1),
    ]]

    local neighbors = {}
    if(includeSelf or includeSelf == nil) then
        neighbors[#neighbors + 1] = self
    end

    if(x == WIDTH) then 
        local neighbor = get_chunk_at(self.x + 1, self.y)
        if(neighbor) then
            neighbors[#neighbors + 1] = neighbor
        end
    elseif(x == 0) then
        local neighbor = get_chunk_at(self.x - 1, self.y)
        if(neighbor) then
            neighbors[#neighbors + 1] = neighbor
        end
    end

    if(y == HEIGHT) then 
        local neighbor = get_chunk_at(self.x, self.y + 1)
        if(neighbor) then
            neighbors[#neighbors + 1] = neighbor
        end
    elseif(y == 0) then
        local neighbor = get_chunk_at(self.x, self.y - 1)
        if(neighbor) then
            neighbors[#neighbors + 1] = neighbor
        end
    end
    
    return neighbors
end

function chunk:init_lightmap()
    self.lightmap = self.lightmap or {}
    for x = 1, WIDTH do
        self.lightmap[x] = self.lightmap[x] or {}

        for y = 1, HEIGHT do
            self.lightmap[x][y] = color.BLACK
        end
    end
end

function chunk:propagate_light_from_source(source_pos, max_distance, light_color)
    local queue = {}
    local visited = {}
    
    local start_x = source_pos.x - self.x * WIDTH
    local start_y = source_pos.y - self.y * HEIGHT
    
    if(start_x < -max_distance or start_x > WIDTH + max_distance or
       start_y < -max_distance or start_y > HEIGHT + max_distance) then return end

    table.insert(queue, {x = start_x, y = start_y, distance = 0})
    
    while(#queue > 0) do
        local current = table.remove(queue, 1)
        local cx, cy, distance = current.x, current.y, current.distance
        
        local key = cx .. "," .. cy
        if(visited[key]) then
            goto continue
        end

        visited[key] = true
        
        if(distance > max_distance) then
            goto continue
        end
        
        local in_chunk = cx >= 1 and cx <= WIDTH and cy >= 1 and cy <= HEIGHT
        if(in_chunk) then
            local tile = self:get_tile(cx, cy)
            if tile ~= nil then
                -- solid tile blocks light
                goto continue
            end
            
            local attenuation = 1.0 - (distance / max_distance)
            local attenuated_color = color.new(
                math.floor(light_color.r * attenuation),
                math.floor(light_color.g * attenuation),
                math.floor(light_color.b * attenuation),
                math.floor(light_color.a * attenuation)
            )

            local existing = self.lightmap[cx][cy]
            self.lightmap[cx][cy] = color.new(
                math.min(255, existing.r + attenuated_color.r),
                math.min(255, existing.g + attenuated_color.g),
                math.min(255, existing.b + attenuated_color.b),
                math.max(existing.a, attenuated_color.a)
            )
        end
        
        if(distance < max_distance) then
            local neighbors = {
                {x = cx + 1, y = cy},
                {x = cx - 1, y = cy},
                {x = cx, y = cy + 1},
                {x = cx, y = cy - 1}
            }
            
            for _, neighbor in ipairs(neighbors) do
                local nx, ny = neighbor.x, neighbor.y
                local nkey = nx .. "," .. ny
                
                if(not visited[nkey]) then
                    if(nx > -2 and nx < WIDTH + 2 and ny > -2 and ny < HEIGHT + 2) then
                        table.insert(queue, {
                            x = nx,
                            y = ny,
                            distance = distance + 1
                        })
                    end
                end
            end
        end
        
        ::continue::
    end
end

function chunk:update_lightmap()
    self:init_lightmap()
    
    local lights = self.scene:get_chunk_lights(self.x, self.y)
    if(lights == nil) then return end

    for _, light in ipairs(lights) do
        local max_distance = light:get_distance()
        self:propagate_light_from_source(light.position, max_distance, light.color)
    end

    self.lighting_dirty = true
end

function chunk:fetch_light(x, y)
    if(not self.lightmap or not self.lightmap[x]) then 
        return color.BLACK
    end
    return self.lightmap[x][y] or color.BLACK
end

function chunk:build()
    -- discard old mesh
    if(self.mesh ~= nil) then
        self.mesh:release()
        self.mesh = nil
    end

    local buffer = vertexbuffer.new()
    local function add_quad(x, y, width, height, start_tile) -- todo: something still fucked here?
        -- pack data and append vertices
        --[[ local width_data = bit.lshift(bit.band(width, 0x7F), 18)
        local height_data = bit.lshift(bit.band(height, 0x7F), 25)
        
        local top_left = bit.bor(
            bit.lshift(bit.band(x - 1, 0x7F), 4),
            bit.lshift(bit.band(y - 1, 0x7F), 11),
            width_data, height_data
        )

        local top_right = bit.bor(
            bit.lshift(bit.band(x - 1 + width, 0x7F), 4),
            bit.lshift(bit.band(y - 1, 0x7F), 11),
            width_data, height_data
        )

        local bottom_left = bit.bor(
            bit.lshift(bit.band(x - 1, 0x7F), 4),
            bit.lshift(bit.band(y - 1 + height, 0x7F), 11),
            width_data, height_data
        )

        local bottom_right = bit.bor(
            bit.lshift(bit.band(x - 1 + width, 0x7F), 4),
            bit.lshift(bit.band(y - 1 + height, 0x7F), 11),
            width_data, height_data
        )
        
        local texture_index = bit.lshift(bit.band(start_tile.texture_index, 0xFF), 24) -- 8 bits should be enough

        -- add to our vertexbuffer
        -- local light_data = self:fetch_lights(x, y)
        buffer:add_quad(
            {top_left, bit.bor(texture_index, bit.lshift(bit.band(0, 0x3), 22), 0)}, -- top left
            {top_right, bit.bor(texture_index, bit.lshift(bit.band(1, 0x3), 22), 0)}, -- top right
            {bottom_left, bit.bor(texture_index, bit.lshift(bit.band(2, 0x3), 22), 0)}, -- bottom left
            {bottom_right, bit.bor(texture_index, bit.lshift(bit.band(3, 0x3), 22), 0)} -- bottom right
        ) --]]

        -- self.quads[#self.quads + 1] = {x = x, y = y, w = width, h = height}

        -- add quad to buffer
        local light_color = self:fetch_light(x, y)
        local texture_index = start_tile.texture_index
        buffer:add_quad( 
            {x, y, 0, 0, texture_index},
            {x + width, y, width, 0, texture_index},
            {x, y + height, 0, height, texture_index},
            {x + width, y + height, width, height, texture_index}
        )
    end

    -- go through whole tile map
    local tested = {}
    for x = 1, WIDTH do
        if(tested[x] == nil) then
            tested[x] = {}
        end

        for y = 1, HEIGHT do
            local tile = self:get_tile(x, y) 
            --[[if(tile ~= nil) then    
                add_quad(x, y, 1, 1, tile)
            end--]]
            -- greedy meshing      
            if(tile ~= nil and not tested[x][y]) then
                tested[x][y] = true
                
                local start = {
                    x = x,
                    y = y
                }

                local size = {
                    x = 1,
                    y = 1
                }

                local can_spread = {
                    x = true,
                    y = true
                }

                -- check how far we can expand our tile
                while(can_spread.x or can_spread.y) do
                    can_spread.x = try_spread_x(self, can_spread, tested, start, size, tile)
                    can_spread.y = try_spread_y(self, can_spread, tested, start, size, tile)
                end

                -- create new quad
                add_quad(start.x, start.y, size.x, size.y, tile)
            end
        end
    end

    -- create mesh
    if(#buffer.indices == 0) then return end

    self.mesh = love.graphics.newMesh(vtx_format, buffer.vertices, "triangles")
    self.mesh:setVertexMap(buffer.indices)
    self.vertex_count = #buffer.vertices
end

function chunk:render(x, y, scale)
    if(self.mesh == nil) then 
        return
    end

    -- relative positioning
    local scale = scale or SCALE
    local ox = self.x * scale * WIDTH - scale + (x or 0)
    local oy = self.y * scale * HEIGHT - scale + (y or 0)

    -- draw our chunk
    chunk.shader:send("world_scale", scale)
    chunk.shader:send("tile_atlas", TEXTURE_ATLAS.image)

    love.graphics.draw(self.mesh, ox, oy)
end

return chunk