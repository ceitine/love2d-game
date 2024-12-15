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
    instance.position = {x = 0, y = 0}
    instance.scene = nil
    setmetatable(instance, mt)
    self.__index = instance
    return instance
end

function scenecamera.new()
    local instance = scenecamera:create()
    return instance
end

-- instance functions
function scenecamera:to_screen(x, y)
    return {
        x = (x - 1) * self.scale + self.position.x * self.scale + love.graphics.getWidth() / 2, 
        y = (y - 1) * self.scale + self.position.y * self.scale + love.graphics.getHeight() / 2
    }
end

function scenecamera:to_world(x, y)
    return { 
        x = (x - love.graphics.getWidth() / 2 - self.position.x * self.scale) / self.scale + 1, 
        y = (y - love.graphics.getHeight() / 2 - self.position.y * self.scale) / self.scale + 1
    }
end

function scenecamera:render()
    if(self.scene == nil) then
        return
    end
    
    -- draw scene
    local x = self.position.x * self.scale + love.graphics.getWidth() / 2
    local y = self.position.y * self.scale + love.graphics.getHeight() / 2
    self.scene:render(x, y, self.scale)

    -- draw fps and crosshair
    render.string(math.floor(1 / time.delta), 0, 0, color.new(60, 200, 60), 0.8)

    -- raycast
    local endX, endY = love.mouse.getX(), love.mouse.getY()
    local from = self:to_world(love.graphics.getWidth() / 2, love.graphics.getHeight() / 2)
    local to = self:to_world(endX, endY)
    local raycast = self.scene:raycast(from, to, true)
    for _, pos in pairs(raycast.path) do 
        local world_pos = self:to_screen(
            math.floor(pos.x), 
            math.floor(pos.y)
        )

        render.rectangle(world_pos.x, world_pos.y, self.scale, self.scale, color.GREEN)
    end

    -- debug render
    if(raycast.hit) then
        local world_pos = self:to_screen(
            math.floor(raycast.position.x), 
            math.floor(raycast.position.y)
        )

        render.rectangle(world_pos.x, world_pos.y, self.scale, self.scale, color.WHITE)

        local hit_pos = self:to_screen(
            raycast.hit_position.x + from.x,
            raycast.hit_position.y + from.y
        )

        endX, endY = hit_pos.x, hit_pos.y
    
        if(love.mouse.isDown(2)) then
            raycast.chunk:set_tile(nil, raycast.tile_position.x, raycast.tile_position.y)
            raycast.chunk:build()
        end
    end

    render.line(
        love.graphics.getWidth() / 2, love.graphics.getHeight() / 2,
        endX, endY,
        color.RED
    )
end

return scenecamera