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

RB_FLAGS_LOCK_angle = 0
RB_FLAGS_GRAVITY = 1

RB_DEFAULT_FLAGS = {
    [RB_FLAGS_LOCK_angle] = false,
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
    instance.angle = vargs[3] or 0
    
    instance.velocity = vec2.ZERO:copy()
    instance.angular_velocity = 0
    instance.gravity = vec2(0, 9.81)
    instance.force = vec2.ZERO:copy()
    
    instance.move_type = vargs[4] or MOVETYPE_DYNAMIC

    instance.restitution = 0.5
    instance.density = mathx.clamp(vargs[6] or 1, MIN_DENSITY, MAX_DENSITY)
    instance.mass = vargs[5] or 1
    instance.inv_mass = instance.move_type == MOVETYPE_STATIC 
        and 0 
        or 1 / instance.mass

    if(instance.type == COLLIDER_RECT) then
        local w = vargs[1] or 1
        local h = vargs[2] or 1
        instance.shape = {
            width = w,
            height = h,
            pivot = vec2(w / 2, h / 2)
        }

        instance.inertia = vargs[6] or 
            (1 / 12) * instance.mass * (w * w + h * h)
    elseif(instance.type == COLLIDER_CIRCLE) then
        local r = vargs[1] or 1
        instance.shape = {
            radius = r,
            pivot = vec2(r / 2, r / 2)
        }

        instance.inertia = vargs[6] or 
            (1 / 2) * instance.mass * r * r
    else
        error("Invalid collider type for rigidbody ".. type)
    end

    instance.inv_inertia = instance.move_type == MOVETYPE_STATIC 
        and 0
        or 1 / instance.inertia

    instance.scene = SCENE

    return instance
end

function rigidbody.circle(position, angle, radius, move_type, mass, density)
    return rigidbody.new(COLLIDER_CIRCLE, position, radius, nil, angle, move_type, mass, density)
end

function rigidbody.rectangle(position, angle, width, height, move_type, mass, density)
    return rigidbody.new(COLLIDER_RECT, position, width, height, angle, move_type, mass, density)
end

-- helpers
local function circle_contact_point(centerA, radiusA, centerB, radiusB)
    local ab = centerB - centerA
    local dir = ab:normalize()
    return centerA + dir * radiusA
end

local function point_segment_distance(p, a, b)
    local contact, distance_squared
    
    local ab = b - a
    local ap = p - a

    local proj = ap:dot(ab)
    local ab_len_sqr = ab:length_squared()
    local d = proj / ab_len_sqr

    if(d <= 0) then
        contact = a
    elseif(d >= 1) then
        contact = b
    else
        contact = a + ab * d
    end

    distance_squared = p:distance_squared(contact)

    return contact, distance_squared
end

local function polygon_circle_contact_point(circle_center, circle_radius, polygon_center, polygon)
    local points = #polygon
    local min_dist_sq = math.huge
    local contact_point = vec2.ZERO:copy()

    for i = 1, points do
        local va = polygon[i]
        local vb = polygon[math.max((i + 1) % points, 1)]

        local contact, dist_sq = point_segment_distance(circle_center, va, vb)
        if(dist_sq < min_dist_sq) then
            min_dist_sq = dist_sq
            contact_point = contact
        end
    end

    return contact_point
end

local function polygon_contact_points(polygonA, polygonB)
    local contact1, contact2, contact_count = 
        vec2.ZERO:copy(),
        vec2.ZERO:copy(),
        0

    local min_dist_sq = math.huge

    local pointsA, pointsB = #polygonA, #polygonB
    for i = 1, pointsA do
        local p = polygonA[i]

        for j = 1, pointsB do
            local va = polygonB[j]
            local vb = polygonB[math.max((j + 1) % pointsB, 1)]

            local contact, dist_sq = point_segment_distance(p, va, vb)
            if(mathx.nearly(dist_sq, min_dist_sq)) then
                if(not contact:nearly(contact1)) then
                    contact2 = contact
                    contact_count = 2
                end
            elseif(dist_sq < min_dist_sq) then
                min_dist_sq = dist_sq
                contact_count = 1
                contact1 = contact
            end
        end
    end

    for i = 1, pointsB do
        local p = polygonB[i]

        for j = 1, pointsA do
            local va = polygonA[j]
            local vb = polygonA[math.max((j + 1) % pointsA, 1)]

            local contact, dist_sq = point_segment_distance(p, va, vb)
            if(mathx.nearly(dist_sq, min_dist_sq)) then
                if(not contact:nearly(contact1)) then
                    contact2 = contact
                    contact_count = 2
                end
            elseif(dist_sq < min_dist_sq) then
                min_dist_sq = dist_sq
                contact_count = 1
                contact1 = contact
            end
        end
    end

    return contact1, contact2, contact_count
end

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

function rigidbody:get_vertices(local_space) -- rectangle x-axis corners are too big?
    local rad = self.angle * math.pi / 180

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
                y = self.position.y - y + (self.shape.height - self.shape.pivot.y) -- this doesn't account for angle if pivoted, fix
            end
            
            corners[i] = vec2(x, y)
        end

        return corners
    end
end

function rigidbody:get_occupied_bounds()
    if(self.type == COLLIDER_RECT) then
        -- find all corners of rectangle
        local corners = self:get_vertices()

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
        return polygon_intersection(self:get_center(), tile_center, self:get_vertices(), tile_polygon)

    elseif(self.type == COLLIDER_CIRCLE) then
        return circle_polygon_intersect(tile_center, tile_polygon, self:get_center(), self.shape.radius)
    end
end

function rigidbody:find_contact_points(obj, tile_data)
    local contact1, contact2, contact_count = 
        vec2.ZERO:copy(),
        vec2.ZERO:copy(),
        0

    -- self is rect
    if(self.type == COLLIDER_RECT) then

        if(tile_data) then
            local tile_polygon = {
                vec2(tile_data.x - 1, tile_data.y - 1), -- top-left
                vec2(tile_data.x    , tile_data.y - 1), -- top-right
                vec2(tile_data.x - 1, tile_data.y    ), -- bottom-left
                vec2(tile_data.x    , tile_data.y    ) -- bottom-right
            }

            contact1, contact2, contact_count = polygon_contact_points(self:get_vertices(), tile_polygon)
        elseif(obj.type == COLLIDER_CIRCLE) then
            contact1 = polygon_circle_contact_point(obj:get_center(), obj.shape.radius, self:get_center(), self:get_vertices())
            contact_count = 1
        elseif(obj.type == COLLIDER_RECT) then
            contact1, contact2, contact_count = polygon_contact_points(self:get_vertices(), obj:get_vertices())
        end

    -- self is circle
    elseif(self.type == COLLIDER_CIRCLE) then

        if(tile_data) then
            local tile_polygon = {
                vec2(tile_data.x - 1, tile_data.y - 1), -- top-left
                vec2(tile_data.x    , tile_data.y - 1), -- top-right
                vec2(tile_data.x - 1, tile_data.y    ), -- bottom-left
                vec2(tile_data.x    , tile_data.y    ) -- bottom-right
            }

            local tile_center = vec2(tile_data.x + 0.5, tile_data.y + 0.5)

            contact1 = polygon_circle_contact_point(self:get_center(), self.shape.radius, tile_center, tile_polygon)
            contact_count = 1
        elseif(obj.type == COLLIDER_CIRCLE) then
            contact1 = circle_contact_point(self:get_center(), self.shape.radius, obj:get_center(), obj.shape.radius)
            contact_count = 1
        elseif(obj.type == COLLIDER_RECT) then
            contact1 = polygon_circle_contact_point(self:get_center(), self.shape.radius, obj:get_center(), obj:get_vertices())
            contact_count = 1
        end

    end

    return contact1, contact2, contact_count
end

function aabb_intersects(a, b)
    -- local a = self:get_occupied_bounds()
    -- local b = obj:get_occupied_bounds()
    
    if(a.maxsX < b.minsX or b.maxsX < a.minsX 
    or a.maxsY < b.minsY or b.maxsY < a.minsY) then
        return false
    end

    return true
end

function rigidbody:collide(obj)
    local result

    -- self is rect
    if(self.type == COLLIDER_RECT) then

        if(obj.type == COLLIDER_RECT) then
            result = polygon_intersection(self:get_center(), obj:get_center(), self:get_vertices(), obj:get_vertices())
        elseif(obj.type == COLLIDER_CIRCLE) then -- THIS ONE NEEDS REVERSED NORMAL
            result = circle_polygon_intersect(self:get_center(), self:get_vertices(), obj:get_center(), obj.shape.radius)
            if(result) then
                result.normal = 0 - result.normal
            end
        end

    -- self is circle
    elseif(self.type == COLLIDER_CIRCLE) then

        if(obj.type == COLLIDER_RECT) then
            result = circle_polygon_intersect(obj:get_center(), obj:get_vertices(), self:get_center(), self.shape.radius)
        elseif(obj.type == COLLIDER_CIRCLE) then
            result = circle_intersect(self:get_center(), self.shape.radius, obj:get_center(), obj.shape.radius)
        end

    end

    -- ensure normalized depth
    if(result) then
        result.depth = mathx.clamp(result.depth, 0, 1)
    end

    return result
end

function rigidbody:resolve_collision_basic(manifold)
    if(not manifold) then return end

    local other = manifold.bodyB
    local collision = manifold.collision
    
    -- get non nil values for other physics collider
    local other_velocity = (other and other.move_type == MOVETYPE_DYNAMIC) 
        and other.velocity 
        or 0

    local other_inv_mass = other and other:get_inv_mass() or 1
    local relative_velocity = other_velocity - self.velocity

    -- if bodies inside of eachother and already moving away from eachother
    local velocity_dot = relative_velocity:dot(collision.normal)
    if(velocity_dot > 0) then
        return
    end

    -- apply forces
    local epsilon = 0.0001
    local e = math.min(self.restitution, other and other.restitution or 0)
    local j = -(1 + e) * velocity_dot
    j = j / math.max(self:get_inv_mass() + other_inv_mass, epsilon)

    local impulse = j * collision.normal

    self.velocity = self.velocity - impulse * self:get_inv_mass()
    if(other) then
        other.velocity = other.velocity + impulse * other_inv_mass
    end
end

function rigidbody:resolve_collision_with_rotation(manifold)
    if(not manifold) then return end

    local other = manifold.bodyB
    local collision = manifold.collision
    local e = math.min(self.restitution, other and other.restitution or 0)
    
    -- get non nil values for other physics collider
    local other_velocity = (other and other.move_type == MOVETYPE_DYNAMIC) 
        and other.velocity 
        or 0

    local other_inv_inertia = other and other:get_inv_inertia() or 0

    local other_inv_mass = other and other:get_inv_mass() or 1

    -- handle contact points
    local contacts = {manifold.contact1, manifold.contact2}
    local impulses = {}
    local ra_list, rb_list = {}, {}

    for i = 1, manifold.contact_count do
        local point = contacts[i]

        local ra = point - self:get_center()
        local rb = point - (other and other:get_center() or 0)
        ra_list[i] = ra
        rb_list[i] = rb

        local ra_perp = vec2(ra.y, ra.x)
        local rb_perp = vec2(rb.y, rb.x)

        local angular_velocityA = ra_perp * self.angular_velocity
        local angular_velocityB = rb_perp * (other and other.angular_velocity or 1)

        local relative_velocity = (other_velocity + angular_velocityB) 
            - (self.velocity + angular_velocityA)
            
        local contact_velocity_mag = relative_velocity:dot(collision.normal)
        if(contact_velocity_mag <= 0) then
            local epsilon = 0.0001

            local ra_perp_dotN = ra_perp:dot(collision.normal)
            local rb_perp_dotN = rb_perp:dot(collision.normal)

            local denom = self:get_inv_mass() + other_inv_mass 
                + (ra_perp_dotN * ra_perp_dotN) * self:get_inv_inertia()
                + (rb_perp_dotN * rb_perp_dotN) * other_inv_inertia

            local j = -(1 + e) * contact_velocity_mag
            j = j / math.max(denom, epsilon)
            j = j / manifold.contact_count

            local impulse = j * collision.normal
            impulses[i] = impulse
        end
    end

    for i = 1, manifold.contact_count do
        local impulse = impulses[i]

        if(impulse) then
            local ra = ra_list[i]
            local rb = rb_list[i]
            
            self.velocity = self.velocity - impulse * self:get_inv_mass()
            self.angular_velocity = self.angular_velocity - ra:cross(impulse) * self:get_inv_inertia()
            if(other) then
                other.velocity = other.velocity + impulse * other_inv_mass
                other.angular_velocity = other.angular_velocity + rb:cross(impulse) * other_inv_inertia
            end
        end
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

function rigidbody:set_mass(value)
    local value = value or 1
    self.mass = value
    self.inv_mass = 1 / value
end

function rigidbody:get_inv_mass()
    if(self.move_type == MOVETYPE_STATIC) then
        return 0
    end

    return self.inv_mass
end

function rigidbody:get_inv_inertia()
    if(self.move_type == MOVETYPE_STATIC) then
        return 0
    end

    return self.inv_inertia
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
    self.angle = self.angle + deg
end

function rigidbody:move_to(x, y)
    self.position = vec2(x, y)
end

function rigidbody:rotate_to(deg)
    self.angle = deg
end

function rigidbody:step(delta)
    if(self.move_type == MOVETYPE_STATIC) then
        return
    end

    -- apply gravity
    if(self.gravity and self:get_flag(RB_FLAGS_GRAVITY)) then
        self:apply_velocity(self.gravity.x * delta, self.gravity.y * delta)
    end

    -- acceleration
    local acceleration = self.force / self.mass * delta
    self:apply_velocity(acceleration.x, acceleration.y)

    -- apply velocities
    self:move(self.velocity.x * delta, self.velocity.y * delta)

    if(not self:get_flag(RB_FLAGS_LOCK_angle)) then
        self:rotate(self.angular_velocity * delta)
    end

    -- reset force
    self:apply_force(0, 0)
end

return rigidbody