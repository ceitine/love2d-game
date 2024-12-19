local physicsobj = {}
local mt = {
    -- index data
    __index = physicsobj,
}

-- variables
COLLIDER_RECT = "rect"
COLLIDER_CIRCLE = "circle"

physicsobj.scene = nil
physicsobj.type = nil
physicsobj.position = nil
physicsobj.rotation = 0
physicsobj.velocity = nil
physicsobj.gravity = nil

-- create new physicsobj
function physicsobj:create(o)
    local instance = o or {}
    setmetatable(instance, mt)
    self.__index = instance
    return instance
end

function physicsobj.new(type, pos, ...)
    local vargs = {...}
    local instance = physicsobj:create()
    instance.type = type or COLLIDER_RECT
    instance.position = (pos or vec2.ZERO):copy()
    instance.rotation = vargs[3] or 0
    instance.velocity = vec2.ZERO:copy()
    instance.rotational_velocity = 0
    instance.gravity = vec2.new(0, 3)
    instance.force = vec2.ZERO:copy()
    if(instance.type == COLLIDER_RECT) then
        local w = vargs[1] or 1
        local h = vargs[2] or 1
        instance.shape = {
            width = w,
            height = h,
            pivot = vec2.new(w / 2, h / 2)
        }
    else
        error("Invalid collider type for PhysicsObj ".. type)
    end

    instance.scene = SCENE

    return instance
end

-- helpers
local function rotate_vector(x, y, px, py, angle)
    local cos = math.cos(angle)
    local sin = math.sin(angle)

    return (x - px) * cos - (y - py) * sin + px,
           (x - px) * sin + (y - py) * cos + py
end

local function arithmetic_mean(points)
    local sumX, sumY = 0, 0
    local point_count = #points
    for i = 1, point_count do
        sumX = sumX + points[i].x
        sumY = sumY + points[i].y
    end

    return vec2.new(
        sumX / point_count,
        sumY / point_count
    )
end

local function polygon_intersection(a, b)
    local depth = math.huge
    local direction = nil

    for _, polygon in pairs({a, b}) do
        local points = #polygon
        for i = 1, points do
            local i2 = i % points + 1
            local p1 = polygon[i]
            local p2 = polygon[i2]

            local normal = vec2.new(p2.y - p1.y, p2.x - p1.x)
            local minA, maxA
            for _, point in pairs(a) do
                local projected = normal.x * point.x + normal.y * point.y
                if(minA == nil or projected < minA) then minA = projected end
                if(maxA == nil or projected > maxA) then maxA = projected end
            end

            local minB, maxB
            for _, point in pairs(b) do
                local projected = normal.x * point.x + normal.y * point.y
                if(minB == nil or projected < minB) then minB = projected end
                if(maxB == nil or projected > maxB) then maxB = projected end
            end

            if(maxA < minB or maxB < minA) then
                return false
            end

            local axis_depth = math.min(maxB - minA, maxA - minB)
            if(axis_depth < depth) then
                depth = axis_depth
                direction = normal:copy()
            end
        end
    end

    -- normalize values
    local length = direction:length()
    depth = depth / length -- ?
    direction = direction / length

    -- make sure normal is correct direction
    local centerA = arithmetic_mean(a)
    local centerB = arithmetic_mean(b)
    local center_direction = centerB - centerA

    local dot_product = center_direction:dot(direction)
    if(dot_product < 0) then 
        direction = 0 - direction -- flip direction
    end

    return {
        depth = depth,
        normal = direction
    }
end

-- instance functions
function physicsobj:get_corners()
    local rad = self.rotation * math.pi / 180

    if(self.type == COLLIDER_RECT) then
        -- find all corners of rectangle
        local corners = {
            {x = 0, y = 0}, -- top-left
            {x = self.shape.width, y = 0}, -- top-right
            {x = 0, y = self.shape.height}, -- bottom-left
            {x = self.shape.width, y = self.shape.height} -- bottom-right
        }

        for i, corner in pairs(corners) do
            local x, y = rotate_vector(corner.x, corner.y, self.shape.pivot.x, self.shape.pivot.y, rad)
            corners[i].x = self.position.x - x + (self.shape.width - self.shape.pivot.x)
            corners[i].y = self.position.y - y + (self.shape.height - self.shape.pivot.y) -- this doesn't account for rotation if pivoted, fix
        end

        return corners
    end
end

function physicsobj:tile_collision(x, y)
    local polygon = self:get_corners()
    local tile_polygon = {
        {x = x - 1, y = y - 1}, -- top-left
        {x = x    , y = y - 1}, -- top-right
        {x = x - 1, y = y    }, -- bottom-left
        {x = x    , y = y    } -- bottom-right
    }

    return polygon_intersection(polygon, tile_polygon)
end

function physicsobj:get_occupied_bounds()
    if(self.type == COLLIDER_RECT) then
        -- find all corners of rectangle
        local corners = self:get_corners()

        -- find bounds of corners
        local minX, minY = math.min(corners[1].x, corners[2].x), math.min(corners[1].y, corners[2].y)
        minX, minY = math.min(minX, corners[3].x), math.min(minY, corners[3].y)
        minX, minY = math.min(minX, corners[4].x), math.min(minY, corners[4].y)

        local maxX, maxY = math.max(corners[1].x, corners[2].x), math.max(corners[1].y, corners[2].y)
        maxX, maxY = math.max(maxX, corners[3].x), math.max(maxY, corners[3].y)
        maxX, maxY = math.max(maxX, corners[4].x), math.max(maxY, corners[4].y)

        return {
            minsX = math.floor(minX) + 1, minsY = math.floor(minY) + 1,
            maxsX = math.ceil(maxX), maxsY = math.ceil(maxY)
        }
    end
end

function physicsobj:apply_velocity(x, y)
    self.velocity = self.velocity + vec2.new(x, y)
end

function physicsobj:apply_force(x, y)
    self.force = vec2.new(x, y)
end

function physicsobj:move(x, y)
    self.position = self.position + vec2.new(x, y)
end

function physicsobj:rotate(deg)
    self.rotation = self.rotation + deg
end

function physicsobj:step(delta)
    -- apply gravity
    if(self.gravity) then
        -- self:apply_velocity(self.gravity.x, self.gravity.y)
    end

    -- apply physics
    self:apply_velocity(self.force.x, self.force.y)
    self:move(self.velocity.x * delta, self.velocity.y * delta)
    self:rotate(self.rotational_velocity * delta)
    self:apply_force(0, 0)

    -- resolve collisions
    if(self.type == COLLIDER_RECT) then
        
        local bounds = self:get_occupied_bounds()
        for x = bounds.minsX, bounds.maxsX do
            for y = bounds.minsY, bounds.maxsY do
                
                if(self.scene:query_pos(x, y).tile ~= nil) then
                    collision = self:tile_collision(x, y)
                    if(collision) then         
                        self:move(-collision.normal.x * collision.depth, -collision.normal.y * collision.depth)               
                    end
                end

            end
        end

    end
end

return physicsobj