tile = require("render/tile")
textureatlas = require("render/textureatlas")

local all = {}
local chunk = {}
chunk.all = all
chunk.tiles = {}
chunk.x = 0
chunk.y = 0
chunk.tile_count = 0

local mt = {
    -- index data
    __index = chunk,
}

-- defaults, note: the limit for these is the max value of an 8-bit integer
local WIDTH = 32
local HEIGHT = 32

-- shader
local vtx_format = {
    {"VertexPosition", "float", 2},
}

local shader = love.graphics.newShader("shaders/chunk.glsl")
local atlas = textureatlas.new("assets/atlas.png", 32)
shader:send("tex", atlas.image)

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
local function set_chunk_at(x, y, chunk)
    -- append new row
    if(chunk.all[y] == nil) then
        chunk.all[y] = {}
    end

    -- append chunk
    chunk.all[y][x] = chunk
end

function chunk.new(x, y)
    local instance = setmetatable({}, mt)
    instance.x = x or 0
    instance.y = y or 0

    instance:set_tile(tile.new(0), 1, 1)
    for x = 1, WIDTH do
        for y = 1, HEIGHT do
            if (x>=WIDTH/2) then
                instance:set_tile(tile.new(0), x, y)
            else
                instance:set_tile(tile.new(mathx.random(0, 1)), x, y)
            end
        end
    end

    instance:build()
    
    set_chunk_at(x, y, instance)

    return instance
end

function chunk:set_tile(tile, x, y)
    -- check if within bounds
    if(x < 1 or x > WIDTH or y < 1 or y > HEIGHT) then
        return
    end

    -- append new row
    if(self.tiles[y] == nil) then
        self.tiles[y] = {}
    end

    -- append tile
    self.tiles[y][x] = tile
    self.tile_count = self.tile_count + (tile ~= nil and 1 or -1)
end

function chunk:get_tile(x, y)
    -- check if within bounds
    if(x < 1 or x > WIDTH or y < 1 or y > HEIGHT or self.tiles[y] == nil) then
        return nil
    end

    -- return tile
    return self.tiles[y][x]
end

function chunk:build()
    local vertices = {}
    local function add_quad(x, y, width, height, start_tile)
        local offset = #vertices + 1

        -- pack data and append vertices
        local x = bit.band(x, 0xFF)
        local y = bit.lshift(bit.band(y, 0xFF), 8)
        local w = bit.lshift(bit.band(width, 0xFF), 16)
        local h = bit.lshift(bit.band(height, 0xFF), 24)
        local data = bit.bor(h, w, y, x)

        local texture_index = bit.lshift(bit.band(start_tile.texture_index, 0xFFF), 20)

        local top_left = bit.bor(texture_index, bit.lshift(bit.band(0, 0x7), 17))
        local top_right = bit.bor(texture_index, bit.lshift(bit.band(1, 0x7), 17))
        local bottom_left = bit.bor(texture_index, bit.lshift(bit.band(2, 0x7), 17))
        local bottom_right = bit.bor(texture_index, bit.lshift(bit.band(3, 0x7), 17))

        vertices[offset] = {data, top_left}
        vertices[offset + 1] = {data, top_right}
        vertices[offset + 2] = {data, bottom_left}
        vertices[offset + 3] = {data, top_right}
        vertices[offset + 4] = {data, bottom_left}
        vertices[offset + 5] = {data, bottom_right}
    end

    local tested = {}
    for x = 1, WIDTH do
        if(tested[x] == nil) then
            tested[x] = {}
        end

        for y = 1, HEIGHT do
            local tile = self:get_tile(x, y)            
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

    self.mesh = love.graphics.newMesh(vtx_format, vertices, "triangles")
    self.vertex_count = #vertices
end

function chunk:render(x, y, scale)
    if(self.mesh == nil) then 
        return
    end

    -- relative positioning
    local scale = scale or SCALE
    shader:send("scale", scale)

    local ox = self.x * scale * WIDTH - scale + (x or 0)
    local oy = self.y * scale * HEIGHT - scale + (y or 0)

    -- draw our chunk
    render.set_shader(shader)
    love.graphics.draw(self.mesh, ox, oy)
end

return chunk