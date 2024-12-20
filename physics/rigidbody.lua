local rigidbody = {}
local mt = {
    -- index data
    __index = rigidbody,
}

-- variables
COLLIDER_RECT = "rect"
COLLIDER_CIRCLE = "circle"

rigidbody.scene = nil
rigidbody.type = nil
rigidbody.position = nil
rigidbody.rotation = 0
rigidbody.velocity = nil
rigidbody.gravity = nil

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
    instance.position = (pos or vec2.ZERO):copy()
    instance.rotation = vargs[3] or 0
    instance.velocity = vec2.ZERO:copy()
    instance.rotational_velocity = 0
    instance.gravity = vec2(0, 3)
    instance.force = vec2.ZERO:copy()
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
            local i2 = i % points + 1
            local p1 = polygon[i]
            local p2 = polygon[i2]

            local edge = vec2(p2.x - p1.x, p2.y - p1.y)
            local axis = vec2(edge.y, edge.x)

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

    -- normalize values
    local length = normal:length()
    depth = depth / length
    normal = normal / length

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

    local p1 = (center - 1) + direction_r
    local p2 = (center - 1) - direction_r

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
        local i2 = i % points + 1
        local p1 = polygon[i]
        local p2 = polygon[i2]

        local edge = vec2(p2.x - p1.x, p2.y - p1.y)
        axis = vec2(edge.y, edge.x)

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
    axis = closest_point - circle_center

    minA, maxA = project_vertices(polygon, axis)
    minB, maxB = project_circle(circle_center, circle_radius, axis)

    if(maxA < minB or maxB < minA) then
        return false
    end

    local axis_depth = math.min(maxB - minA, maxA - minB)
    if(depth == nil or axis_depth < depth) then
        depth = axis_depth
        normal = axis:copy()
    end

    -- normalize values
    local len = normal:length()
    depth = depth / len
    normal = normal / len

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

    local normal = (centerA - centerB):normalize()
    local depth = radii - distance
    return {
        depth = depth,
        normal = normal
    }
end

-- collision functions
function rigidbody:get_center()
    return self.position:copy()
end

function rigidbody:get_corners()
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
            x = self.position.x - x + (self.shape.width - self.shape.pivot.x)
            y = self.position.y - y + (self.shape.height - self.shape.pivot.y) -- this doesn't account for rotation if pivoted, fix

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
            minsX = math.floor(minX) + 1, minsY = math.floor(minY) + 1,
            maxsX = math.ceil(maxX), maxsY = math.ceil(maxY)
        }
    elseif(self.type == COLLIDER_CIRCLE) then
        -- find bounds by radius
        local minX, minY = self.position.x - self.shape.radius, self.position.y - self.shape.radius
        minX, minY = math.min(minX, self.position.x - 1), math.min(minY, self.position.y - 1)
        
        local maxX, maxY = self.position.x + self.shape.radius, self.position.y + self.shape.radius
        maxX, maxY = math.max(maxX, self.position.x + 1), math.max(maxY, self.position.y + 1)

        return {
            minsX = math.floor(minX), minsY = math.floor(minY),
            maxsX = math.floor(maxX), maxsY = math.floor(maxY)
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
    -- self is rect
    if(self.type == COLLIDER_RECT) then

        if(obj.type == COLLIDER_RECT) then
            return polygon_intersection(self:get_center(), obj:get_center(), self:get_corners(), obj:get_corners())
        elseif(obj.type == COLLIDER_CIRCLE) then
            return circle_polygon_intersect(self:get_center(), self:get_corners(), obj:get_center(), obj.shape.radius)
        end

    -- self is circle
    elseif(self.type == COLLIDER_CIRCLE) then

        if(obj.type == COLLIDER_RECT) then
            return circle_polygon_intersect(obj:get_center(), obj:get_corners(), self:get_center(), self.shape.radius)
        elseif(obj.type == COLLIDER_CIRCLE) then
            return circle_intersect(self:get_center(), self.shape.radius, obj:get_center(), obj.shape.radius)
        end

    end
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
    self.rotation = self.rotation + deg
end

function rigidbody:step(delta)
    -- resolve collisions
    for _, other in pairs(self.scene.objects) do
        if(other ~= self) then
            collision = self:collide(other)
            if(collision) then
                self:move(collision.normal.x * collision.depth / 2, collision.normal.y * collision.depth / 2)           
                other:move(-collision.normal.x * collision.depth / 2, -collision.normal.y * collision.depth / 2)  
            end
        end
    end

    -- tilemap collisions
    local bounds = self:get_occupied_bounds()
    for x = bounds.minsX, bounds.maxsX do
        for y = bounds.minsY, bounds.maxsY do
            
            if(self.scene:query_pos(x, y).tile ~= nil) then
                collision = self:tile_collide(x, y)
                if(collision) then         
                    self:move(-collision.normal.x * collision.depth, -collision.normal.y * collision.depth)               
                end
            end

        end
    end

    -- apply gravity
    if(self.gravity) then
        --self:apply_velocity(self.gravity.x, self.gravity.y)
    end

    -- apply physics
    self:apply_velocity(self.force.x, self.force.y)
    self:move(self.velocity.x * delta, self.velocity.y * delta)
    self:rotate(self.rotational_velocity * delta)
    self:apply_force(0, 0)
end

return rigidbody