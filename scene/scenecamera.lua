local scenecamera = {}
local mt = {
    -- index data
    __index = scenecamera,
}

-- variables
scenecamera.position = nil
scenecamera.scene = nil
scenecamera.scale = 32

-- creating new camera instance
function scenecamera:create(o)
    local instance = o or {}
    instance.position = vec2.ZERO:copy()
    instance.scene = SCENE

    setmetatable(instance, mt)
    self.__index = instance
    return instance
end

function scenecamera.new()
    local instance = scenecamera:create()
    CAMERA = instance
    return instance
end

-- instance functions
function scenecamera:to_screen(x, y)
    return vec2(
       (x - 1) * self.scale - self.position.x * self.scale + love.graphics.getWidth() / 2, 
       (y - 1) * self.scale - self.position.y * self.scale + love.graphics.getHeight() / 2
    )
end

function scenecamera:to_world(x, y)
    return vec2( 
        (x - love.graphics.getWidth() / 2 + self.position.x * self.scale) / self.scale + 1, 
        (y - love.graphics.getHeight() / 2 + self.position.y * self.scale) / self.scale + 1
    )
end

function scenecamera:render()
    if(self.scene == nil) then
        return
    end
  
    -- draw scene
    local x = -self.position.x * self.scale + love.graphics.getWidth() / 2
    local y = -self.position.y * self.scale + love.graphics.getHeight() / 2
    self.scene:render(x, y, self.scale)
  
    if(LIGHT) then
        LIGHT:set_position(self.position.x, self.position.y)
    end
    
    -- draw fps and crosshair
    render.string(math.floor(1 / time.delta), 10, 10, color.new(60, 200, 60), 0.8)
    render.string("pos: ".. tostring(CAMERA.position), 10, 40, color.WHITE, 0.8)

    -- raycast debugging
    local endX, endY = love.mouse.getX(), love.mouse.getY()
    local from = self:to_world(love.graphics.getWidth() / 2, love.graphics.getHeight() / 2)
    local to = self:to_world(endX, endY)
    local raycast = self.scene:raycast(from, to, true)
    if(raycast.path) then
        for i, pos in pairs(raycast.path) do 
            local screen_pos = self:to_screen(
                math.floor(pos.x), 
                math.floor(pos.y)
            )
            local color = i == #raycast.path and color.WHITE or color.GREEN
            render.rectangle(screen_pos.x, screen_pos.y, self.scale, self.scale, color:with_alpha(150))
        end
    end

    if(raycast.hit) then
        local screen_pos = self:to_screen(
            math.floor(raycast.tile_position.x), 
            math.floor(raycast.tile_position.y)
        )

        local hit_position = self:to_screen(raycast.hit_position.x, raycast.hit_position.y)
        local from_normal = hit_position
        local to_normal = from_normal + raycast.normal * self.scale / 2
        endX, endY = hit_position.x, hit_position.y

        render.line(from_normal.x, from_normal.y, to_normal.x, to_normal.y, color.BLUE)
        
        if(love.mouse.isDown(2)) then
            if(raycast.chunk ~= nil) then
                local local_position = raycast.tile_position - vec2(raycast.chunk.x, raycast.chunk.y)
                raycast.chunk:set_tile(nil, raycast.tile_position.x, raycast.tile_position.y)

                for _, chunk in pairs(raycast.chunk:get_neighbors(local_position.x, local_position.y)) do
                    raycast.chunk:update_lightmap()
                    raycast.chunk:build()
                end
                
            elseif(raycast.body ~= nil) then
                local impulse = from:direction(to):normalize() * 1000
                raycast.body:apply_force(impulse.x, impulse.y)
            end
        end
    end

    render.line(
        love.graphics.getWidth() / 2, love.graphics.getHeight() / 2,
        endX, endY,
        color.RED
    )

    -- physics debugging
    for _, obj in pairs(self.scene.objects) do
        local screen_pos = self:to_screen(
            obj.position.x - obj.shape.pivot.x,
            obj.position.y - obj.shape.pivot.y
        )

        -- collider
        if(obj.type == COLLIDER_RECT) then
            for _, point in pairs(obj:get_vertices()) do -- render corners
                local screen_pos = self:to_screen(
                    point.x + 1,
                    point.y + 1
                )

                render.rectangle(
                    screen_pos.x - 2, screen_pos.y - 2,
                    4, 4,
                    color.WHITE
                )
            end

            love.graphics.push()
                love.graphics.translate(screen_pos.x + self.scale, screen_pos.y + self.scale)
                love.graphics.translate(obj.shape.pivot.x * self.scale, obj.shape.pivot.y * self.scale)
                love.graphics.rotate(obj.angle * math.pi / 180)
                love.graphics.translate(-obj.shape.pivot.x * self.scale, -obj.shape.pivot.y * self.scale)

                render.rectangle(
                    0, 0,
                    obj.shape.width * self.scale, obj.shape.height * self.scale, 
                    color.WHITE, "line"
                )

                local move_type = obj.move_type == MOVETYPE_DYNAMIC and "dynamic" or "static"
                render.string(tostring(obj.shape.width).. "x".. tostring(obj.shape.height).. "\n".. move_type, self.scale * 0.1, self.scale * 0.1, color.WHITE, self.scale * 0.02, 0, ALIGN.HORIZONTAL.LEFT, ALIGN.VERTICAL.TOP)
            love.graphics.pop()
        elseif(obj.type == COLLIDER_CIRCLE) then
            local radius = obj.shape.radius * self.scale 
            love.graphics.push()
                love.graphics.translate(screen_pos.x + radius / 2 + self.scale, screen_pos.y + radius / 2 + self.scale)
                love.graphics.rotate(obj.angle * math.pi / 180)

                render.circle(
                    0, 0,
                    radius, 
                    color.WHITE, "line"
                )

                render.line(
                    0, 0,
                    self.scale * (obj.shape.radius + 1), 0,
                    color.BLUE
                )

                local move_type = obj.move_type == MOVETYPE_DYNAMIC and "dynamic" or "static"
                local offset = -obj.shape.radius / 2 * self.scale 
                render.string("r: ".. tostring(obj.shape.radius).. "\n".. move_type, offset, offset, color.WHITE, self.scale * 0.02, 0, ALIGN.HORIZONTAL.LEFT, ALIGN.VERTICAL.TOP)
            love.graphics.pop()    
        end

        -- occupied bounds
        --[[local bounds = obj:get_occupied_bounds()
        local collision
        for x = bounds.minsX, bounds.maxsX do
            for y = bounds.minsY, bounds.maxsY do
                local col = color.GREEN
                if(self.scene:query_pos(x, y).tile ~= nil) then
                    col = color.RED
                    if(obj:tile_collide(x, y)) then
                        col = color.BLUE
                    end
                end

                local screen_pos = self:to_screen(
                    math.floor(x),
                    math.floor(y)
                )
                
                render.rectangle(
                    screen_pos.x, screen_pos.y,
                    self.scale, self.scale, 
                    col:with_alpha(80)
                )
            end
        end--]]

    end

    --[[for x, _ in pairs(self.scene.body_map) do
        for y, _ in pairs(self.scene.body_map[x]) do
            local bodies = self.scene.body_map[x][y]
            if(bodies) then
                local screen_pos = self:to_screen(
                    math.floor(x),
                    math.floor(y)
                )

                render.rectangle(
                    screen_pos.x, screen_pos.y,
                    self.scale, self.scale,
                    color.GREEN:with_alpha(20)
                )
            end
        end
    end--]]
end

return scenecamera