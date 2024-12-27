local rigidbody = {}
local mt = {
    -- index data
    __index = rigidbody,
}

-- variables
COLLIDER_RECT = 0
COLLIDER_CIRCLE = 1

MOVETYPE_DYNAMIC = 0
MOVETYPE_STATIC = 1

MIN_DENSITY = 0.5  -- g/cm^3
MAX_DENSITY = 21.4 -- 

RB_FLAGS_LOCK_ROTATION = 0
RB_FLAGS_GRAVITY = 1

RB_DEFAULT_FLAGS = {
    [RB_FLAGS_LOCK_ROTATION] = false,
    [RB_FLAGS_GRAVITY] = true
}

-- create new rigidbody
function rigidbody:create(o)
    local instance = o or {}
    setmetatable(instance, mt)
    self.__index = instance
    return instance
end

function rigidbody.new(type, pos, ...)
    local vargs = {...}
    local instance = rigidbody:create()
    instance.type = type or COLLIDER_RECT

    instance.flags = {}
    for n, v in pairs(RB_DEFAULT_FLAGS) do
        instance.flags[n] = v
    end

    instance.position = (pos or vec2.ZERO):copy()
    instance.rotation = vargs[3] or 0
    
    instance.velocity = vec2.ZERO:copy()
    instance.rotational_velocity = 0
    instance.gravity = vec2(0, 3)
    instance.force = vec2.ZERO:copy()
    
    instance.restitution = 0.5
    instance.move_type = vargs[4] or MOVETYPE_DYNAMIC
    instance.mass = vargs[5] or 1
    instance.density = mathx.clamp(vargs[6] or 1, MIN_DENSITY, MAX_DENSITY)

    if(instance.type == COLLIDER_RECT) then
        local w = vargs[1] or 1
        local h = vargs[2] or 1
        instance.shape = {
            width = w,
            height = h,
            pivot = vec2(w / 2, h / 2)
        }
    elseif(instance.type == COLLIDER_CIRCLE) then
        local r = vargs[1] or 1
        instance.shape = {
            radius = r,
            pivot = vec2(r / 2, r / 2)
        }
    else
        error("Invalid collider type for rigidbody ".. type)
    end

    instance.scene = SCENE

    return instance
end

function rigidbody.circle(position, rotation, radius, move_type, mass, density)
    return rigidbody.new(COLLIDER_CIRCLE, position, radius, nil, rotation, move_type, mass, density)
end

function rigidbody.rectangle(position, rotation, width, height, move_type, mass, density)
    return rigidbody.new(COLLIDER_RECT, position, width, height, rotation, move_type, mass, density)
end

-- helpers
local function rotate_vector(x, y, px, py, angle)
    local cos = math.cos(angle)
    local sin = math.sin(angle)

    return (x - px) * cos - (y - py) * sin + px,
           (x - px) * sin + (y - py) * cos + py
end

local function project_vertices(vertices, axis)
    local min, max
    for _, point in pairs(vertices) do
        local projected = axis.x * point.x + axis.y * point.y
        if(min == nil or projected < min) then min = projected end
        if(max == nil or projected > max) then max = projected end
    end

    return min, max
end

local function polygon_intersection(centerA, centerB, a, b)
    local depth = math.huge
    local normal = vec2.ZERO

    for _, polygon in pairs({a, b}) do
        local points = #polygon
        for i = 1, points do
            local p1 = polygon[i]
            local p2 = polygon[math.max((i + 1) % points, 1)]

            local edge = p2 - p1
            local axis = vec2(edge.y, edge.x):normalize()

            local minA, maxA = project_vertices(a, axis)
            local minB, maxB = project_vertices(b, axis)

            if(maxA < minB or maxB < minA) then
                return false
            end

            local axis_depth = math.min(maxB - minA, maxA - minB)
            if(axis_depth < depth) then
                depth = axis_depth
                normal = axis:copy()
            end
        end
    end

    -- make sure normal is correct direction
    local center_direction = centerB - centerA
    local dot_product = center_direction:dot(normal)
    if(dot_product < 0) then 
        normal = 0 - normal -- flip direction
    end

    return {
        depth = depth,
        normal = normal
    }
end

local function project_circle(center, radius, axis)
    local direction = axis:normalize()
    local direction_r = direction * radius

    local p1 = center + direction_r
    local p2 = center - direction_r

    local min, max = p1:dot(axis), p2:dot(axis)
    if(min > max) then
        local temp = max
        max = min
        min = temp
    end

    return min, max
end

local function circle_polygon_intersect(polygon_center, polygon, circle_center, circle_radius)
    local depth = math.huge
    local normal = vec2.ZERO
    local axis

    local min_distance = math.huge
    local closest_index = 0

    local minA, maxA, minB, maxB

    local points = #polygon
    for i = 1, points do
        local p1 = polygon[i]
        local p2 = polygon[math.max((i + 1) % points, 1)]

        local edge = p2 - p1
        axis = vec2(edge.y, edge.x):normalize()

        minA, maxA = project_vertices(polygon, axis)
        minB, maxB = project_circle(circle_center, circle_radius, axis)

        if(maxA < minB or maxB < minA) then
            return false
        end

        local distance = circle_center:distance(p1)
        if(distance < min_distance) then
            min_distance = distance
            closest_index = i
        end

        local axis_depth = math.min(maxB - minA, maxA - minB)
        if(axis_depth < depth) then
            depth = axis_depth
            normal = axis:copy()
        end
    end

    -- get closest point
    local closest_point = polygon[closest_index] or polygon_center
    axis = (closest_point - circle_center):normalize()

    minA, maxA = project_vertices(polygon, axis)
    minB, maxB = project_circle(circle_center, circle_radius, axis)

    if(maxA < minB or maxB < minA) then
        return false
    end

    local axis_depth = math.min(maxB - minA, maxA - minB)
    if(axis_depth < depth) then
        depth = axis_depth
        normal = axis:copy()
    end

    -- make sure normal is correct direction
    local center_direction = polygon_center - circle_center
    local dot_product = center_direction:dot(normal)
    if(dot_product < 0) then 
        normal = 0 - normal -- flip direction
    end

    return {
        depth = depth,
        normal = normal
    }
end

local function circle_intersect(centerA, radiusA, centerB, radiusB)
    local distance = centerA:distance(centerB)
    local radii = radiusA + radiusB
    if(distance >= radii) then
        return false
    end

    local normal = (centerB - centerA):normalize()
    local depth = radii - distance
    return {
        depth = depth,
        normal = normal
    }
end

-- collision functions
function rigidbody:get_center(local_space)
    if(local_space) then return vec2.ZERO:copy() end
    return self.position:copy()
end

function rigidbody:get_corners(local_space) -- rectangle x-axis corners are too big?
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
            
            if(not local_space) then
                x = self.position.x - x + (self.shape.width - self.shape.pivot.x)
                y = self.position.y - y + (self.shape.height - self.shape.pivot.y) -- this doesn't account for rotation if pivoted, fix
            end
            
            corners[i] = vec2(x, y)
        end

        return corners
    end
end

function rigidbody:get_occupied_bounds()
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
            minsX = math.floor(minX), minsY = math.floor(minY),
            maxsX = math.ceil(maxX + 0.5), maxsY = math.ceil(maxY + 0.5)
        }
    elseif(self.type == COLLIDER_CIRCLE) then
        -- find bounds by radius
        local minX, minY = self.position.x - self.shape.radius, self.position.y - self.shape.radius
        minX, minY = math.min(minX, self.position.x - 1), math.min(minY, self.position.y - 1)
        
        local maxX, maxY = self.position.x + self.shape.radius, self.position.y + self.shape.radius
        maxX, maxY = math.max(maxX, self.position.x + 1), math.max(maxY, self.position.y + 1)

        return {
            minsX = math.floor(minX) + 1, minsY = math.floor(minY) + 1,
            maxsX = math.ceil(maxX), maxsY = math.ceil(maxY)
        }
    end
end

function rigidbody:tile_collide(x, y)
    local tile_polygon = {
        vec2(x - 1, y - 1), -- top-left
        vec2(x    , y - 1), -- top-right
        vec2(x - 1, y    ), -- bottom-left
        vec2(x    , y    ) -- bottom-right
    }

    local tile_center = vec2(x + 0.5, y + 0.5)

    if(self.type == COLLIDER_RECT) then
        return polygon_intersection(self:get_center(), tile_center, self:get_corners(), tile_polygon)

    elseif(self.type == COLLIDER_CIRCLE) then
        return circle_polygon_intersect(tile_center, tile_polygon, self:get_center(), self.shape.radius)
    end
end

function rigidbody:collide(obj)
    local result

    -- self is rect
    if(self.type == COLLIDER_RECT) then

        if(obj.type == COLLIDER_RECT) then
            result = polygon_intersection(self:get_center(), obj:get_center(), self:get_corners(), obj:get_corners())
        elseif(obj.type == COLLIDER_CIRCLE) then -- THIS ONE NEEDS REVERSED NORMAL
            result = circle_polygon_intersect(self:get_center(), self:get_corners(), obj:get_center(), obj.shape.radius)
            if(result) then
                result.normal = 0 - result.normal
            end
        end

    -- self is circle
    elseif(self.type == COLLIDER_CIRCLE) then

        if(obj.type == COLLIDER_RECT) then
            result = circle_polygon_intersect(obj:get_center(), obj:get_corners(), self:get_center(), self.shape.radius)
        elseif(obj.type == COLLIDER_CIRCLE) then
            result = circle_intersect(self:get_center(), self.shape.radius, obj:get_center(), obj.shape.radius)
        end

    end

    return result
end

function rigidbody:resolve_collision(collision, other)
    if(not collision) then return end
    
    local other_velocity = (other and other.move_type == MOVETYPE_DYNAMIC) 
        and other.velocity 
        or 0

    local relative_velocity = other_velocity - self.velocity
    local e = math.min(self.restitution, other and other.restitution or 0)
    local j = -(1 + e) * relative_velocity:dot(collision.normal)
    j = j / (1 / self.mass) + (1 / (other and other.mass or 1))

    self.velocity = self.velocity - (j / self.mass * collision.normal)
    if(other) then
        other.velocity = other.velocity + (j / other.mass * collision.normal)
    end
end

function rigidbody:set_flag(key, value)
    if(RB_DEFAULT_FLAGS[key] == nil) then return end
    self.flags[key] = value
end

function rigidbody:get_flag(key)
    if(not self.flags[key]) then return false end
    return true
end

-- helper functions
function rigidbody:apply_velocity(x, y)
    self.velocity = self.velocity + vec2(x, y)
end

function rigidbody:apply_force(x, y)
    self.force = vec2(x, y)
end

function rigidbody:move(x, y)
    self.position = self.position + vec2(x, y)
end

function rigidbody:rotate(deg)
    if(self:get_flag(RB_FLAGS_LOCK_ROTATION)) then return end
    self.rotation = self.rotation + deg
end

function rigidbody:step(delta)
    -- apply gravity
    if(self.gravity and self:get_flag(RB_FLAGS_GRAVITY)) then
        --self:apply_velocity(self.gravity.x, self.gravity.y)
    end

    -- apply physics
    if(self.move_type == MOVETYPE_DYNAMIC) then

        -- acceleration
        local acceleration = self.force / self.mass * delta
        self:apply_velocity(acceleration.x, acceleration.y)

        -- apply velocities
        self:move(self.velocity.x * delta, self.velocity.y * delta)
        self:rotate(self.rotational_velocity * delta)
        
        -- reset force
        self:apply_force(0, 0)
    
    end
end

return rigidbody