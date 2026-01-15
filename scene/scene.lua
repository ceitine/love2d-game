local chunk = require("render/chunk")
local rigidbody = require("physics/rigidbody")
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
    instance.contact_pairs = {}
    instance.accumulator = 0
    instance.body_map = {}
    instance.lightmap = {}

    setmetatable(instance, mt)
    self.__index = instance
    return instance
end

function scene.new()
    local instance = scene:create()
    SCENE = instance

    local size = 10
    local min = math.floor(-size / 2)
    local max = math.floor(size / 2)
    for x = min, max do
        for y = min, max do
            instance.flat_chunks[y * (size + 1) + x] = chunk.new(x, y, instance)
        end
    end

    instance:refresh_chunks()

    return instance
end

-- instance functions
function scene:refresh_chunks()
    for _, chunk in pairs(self.flat_chunks) do 
        chunk:update_lightmap()
        chunk:build()
    end
end

function scene:query_pos(x, y) -- this is in tile space!
    local result = {}
    result.position = vec2(
        math.floor((x - 1) / chunk.WIDTH),
        math.floor((y - 1) / chunk.HEIGHT)
    )

    local chunk_row = self.chunks[result.position.x]
    result.chunk = chunk_row and chunk_row[result.position.y]

    result.tile_position = vec2(
        (math.floor(x - 1) % chunk.WIDTH + chunk.WIDTH) % chunk.WIDTH + 1,
        (math.floor(y - 1) % chunk.HEIGHT + chunk.HEIGHT) % chunk.HEIGHT + 1
    )

    result.tile = result.chunk and result.chunk:get_tile(result.tile_position.x, result.tile_position.y)

    return result
end

-- todo: register occupied bounds to a global tile physics table so we can query fast to see if a rigidbody is nearby
function scene:raycast(from, to, capture_path) -- this is in tile space!    
    -- some initial variables
    local position = from:copy()
    local result = {
        tile_position = vec2.ZERO,
        normal = vec2.ZERO,
        hit = false,
        distance = 0
    }

    local length = from:distance(to)
    if(capture_path) then 
        result.path = { position:floor() } 
    end

    if(length == 0) then
        return result
    end

    -- lets get the direction..
    local dir = from:direction(to)
    local dirX, dirY = dir.x, dir.y
    local stepX, stepY
    local tMaxX, tMaxY
    local tDeltaX, tDeltaY

    if(dirX >= 0) then
        stepX = 1.0
        tMaxX = (math.floor(position.x) + 1 - position.x) / dirX
        tDeltaX = 1.0 / dirX
    else
        stepX = -1.0
        tMaxX = (position.x - math.floor(position.x)) / -dirX
        tDeltaX = 1.0 / -dirX
    end

    if(dirY >= 0) then
        stepY = 1.0
        tMaxY = (math.floor(position.y) + 1 - position.y) / dirY
        tDeltaY = 1.0 / dirY
    else
        stepY = -1.0
        tMaxY = (position.y - math.floor(position.y)) / -dirY
        tDeltaY = 1.0 / -dirY
    end

    -- travel our ray!
    while(result.distance <= length) do
        local tile_x = math.floor(position.x)
        local tile_y = math.floor(position.y)
        local query = self:query_pos(tile_x, tile_y)

        -- we have a tile collision!
        if(query.chunk ~= nil and query.tile ~= nil) then
            result.chunk = query.chunk
            result.tile = query.tile
            result.hit_position = vec2(dirX * result.distance + from.x, dirY * result.distance + from.y)
            result.hit = true
            result.tile_position = query.tile_position

            return result
        end

        -- check for body collision
        local bodies = self:get_bodies_at(tile_x, tile_y)
        if(bodies) then
            for _, body in pairs(bodies) do
                local center = body:get_center()
                local body_cast = body:raycast(from - center, to - center)
                if(body_cast and body_cast.hit) then
                    result.body = body
                    result.hit_position = center + body_cast.hit_position
                    result.normal = body_cast.normal
                    result.hit = true

                    return result
                end
            end
        end

        -- step
        if(tMaxX < tMaxY) then
            position.x = position.x + stepX
            result.distance = math.abs(tMaxX)
            tMaxX = tMaxX + tDeltaX
            result.normal = vec2(-math.floor(stepX), 0)
        else
            position.y = position.y + stepY
            result.distance = math.abs(tMaxY)
            tMaxY = tMaxY + tDeltaY
            result.normal = vec2(0, -math.floor(stepY))
        end

        -- capture path
        if(capture_path) then 
            result.path[#result.path + 1] = position:copy()
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

    --[[for _, chunk in pairs(self.flat_chunks) do
        for _, v in pairs(chunk.quads) do 
            local col = color.from32(mathx.random(0, 16000000, v.x + v.y + v.w + v.h)):with_alpha(150)
            render.rectangle(x + (v.x - 1 + chunk.x * chunk.WIDTH) * scale, y + (v.y - 1 + chunk.y * chunk.HEIGHT) * scale, v.w * scale, v.h * scale, col)
        end
    end--]]
end

local function aabb_intersects(a, b)
    if(a.maxsX < b.minsX or b.maxsX < a.minsX 
    or a.maxsY < b.minsY or b.maxsY < a.minsY) then
        return false
    end

    return true
end

local function capture_bounds(self, x, y, body)
    if(not self.body_map[x]) then self.body_map[x] = {} end
    if(not self.body_map[x][y]) then self.body_map[x][y] = {} end

    local count = #self.body_map[x][y] + 1
    self.body_map[x][y][count] = body
end

function scene:get_bodies_at(x, y)
    if(self.body_map[x] and self.body_map[x][y]) then
        return self.body_map[x][y]
    end

    return nil
end

function scene:broad_phase(should_capture_bounds)
    local count = #self.objects

    -- step collisions
    for i = 1, count do
        local bodyA = self.objects[i]

        -- tilemap collisions and map bounds
        local bounds = bodyA:get_occupied_bounds()
        local isDynamic = bodyA.move_type ~= MOVETYPE_STATIC
        if(should_capture_bounds or isDynamic) then
            for x = bounds.minsX, bounds.maxsX do
                for y = bounds.minsY, bounds.maxsY do
                        
                    if(isDynamic and self:query_pos(x, y).tile ~= nil) then
                        self.contact_pairs[#self.contact_pairs + 1] = {
                            bodyA = bodyA,
                            tile_position = vec2(x, y)
                        }
                    end

                    if(should_capture_bounds) then
                        capture_bounds(self, x, y, bodyA)
                    end

                end
            end
        end

        -- resolve collisions
        for j = i + 1, count do
            local bodyB = self.objects[j]
            local both_static = bodyA.move_type == MOVETYPE_STATIC and bodyB.move_type == MOVETYPE_STATIC

            if(not both_static and aabb_intersects(bounds, bodyB:get_occupied_bounds())) then
                self.contact_pairs[#self.contact_pairs + 1] = {
                    bodyA = bodyA,
                    bodyB = bodyB
                }
            end
        end
    end
end

function scene:narrow_phase()
    for i = 1, #self.contact_pairs do
        local pair = self.contact_pairs[i]
        local bodyA = pair.bodyA
        local bodyB = pair.bodyB
        local tile_position = pair.tile_position

        -- collider vs collider
        local manifold
        if(bodyB) then
            local collision = bodyA:collide(bodyB)
            if(collision) then
                bodyA:separate_bodies(bodyB, collision)
                local contact1, contact2, contact_count = bodyA:find_contact_points(bodyB)
                manifold = {
                    bodyA = bodyA,
                    bodyB = bodyB,

                    collision = collision,

                    contact1 = contact1,
                    contact2 = contact2,
                    contact_count = contact_count
                }
            end
        elseif(tile_position) then
            local collision = bodyA:tile_collide(tile_position.x, tile_position.y)
            if(collision) then
                bodyA:separate_bodies(nil, collision) 
                
                local contact1, contact2, contact_count = bodyA:find_contact_points(nil, tile_position)
                manifold = {
                    bodyA = bodyA,
                    tile_position = tile_position,

                    collision = collision,

                    contact1 = contact1,
                    contact2 = contact2,
                    contact_count = contact_count,

                    static_friction = 0.6,
                    dynamic_friction = 0.45
                }
            end
        end

        bodyA:resolve_collision_complex(manifold)

        self.contact_pairs[i] = nil
    end
end

function scene:step_bodies(delta)
    local count = #self.objects
        
    -- step individual bodies
    for i = 1, count do 
        local body = self.objects[i]
                
        -- movement step
        if(love.mouse.isDown(3)) then
            local force_strength = 1
            local mouse_world = CAMERA:to_world(love.mouse.getX(), love.mouse.getY())
            local direction = body.position:direction(mouse_world)
            body:apply_force(direction.x * force_strength, direction.y * force_strength)
        end

        body:step(delta)
    end
end

local spawned = false
function scene:update(dt)
    -- spawn some debug objects
    local spawnCircle, spawnRect = love.keyboard.isDown("e"), love.keyboard.isDown("q")
    if(spawnCircle or spawnRect) then
        if(not spawned) then
            self.objects[#self.objects + 1] = spawnRect 
                and rigidbody.new(COLLIDER_RECT, CAMERA.position, math.random(2, 5), math.random(1, 5), 0)
                or rigidbody.new(COLLIDER_CIRCLE, CAMERA.position, math.random(2, 15) / 5)
            
            self.objects[#self.objects].move_type = mathx.random(0, 5) == 0 and MOVETYPE_STATIC or MOVETYPE_DYNAMIC
            spawned = true
        end
    else 
        spawned = false
    end

    -- update rigidbodies
    local FIXED_TIME = 1 / PHYSICS_TARGET_UPDATES
    local DELTA_TIME = FIXED_TIME / PHYSICS_ITERATIONS

    self.accumulator = math.min(self.accumulator + dt, PHYSICS_MAX_ACCUMULATOR)
    while self.accumulator >= FIXED_TIME do
        for i = 1, PHYSICS_ITERATIONS do
            if(i == PHYSICS_ITERATIONS) then self.body_map = {} end

            self:step_bodies(DELTA_TIME)
            self:broad_phase(i == PHYSICS_ITERATIONS)
            self:narrow_phase()
        end

        self.accumulator = self.accumulator - FIXED_TIME
    end
end

function scene:remove_entity(entity)
    if(not entity or not self.entities[entity.id]) then return end
    table.remove(self.entities, entity.id)
    entity = nil
end

function scene:register_entity(entity)
    local id = #self.entities + 1
    if(not entity) then return end
    self.entities[id] = entity
    return id
end

return scene