local scenelight = {}
local mt = {
    -- index data
    __index = scenelight,
}

-- constants
LIGHT_CIRCLE = 0
LIGHT_RECT = 1

LIGHT_MODE_STATIC = 0
LIGHT_MODE_DYNAMIC = 1

-- creating new light instance
function scenelight:create(o)
    local instance = o or {}
    instance.position = vec2.ZERO:copy()
    instance.scene = SCENE
    instance.type = LIGHT_CIRCLE

    setmetatable(instance, mt)
    self.__index = instance
    return instance
end

function scenelight.circle(pos, radius, col, mode)
    local instance = scenelight:create()
    instance.position =  pos or instance.position
    instance.type = LIGHT_CIRCLE
    instance.radius = radius or 1
    instance.color = col or color.WHITE
    instance.mode = mode or LIGHT_MODE_DYNAMIC

    instance:update()

    return instance
end

function scenelight.rectangle(pos, mins, maxs, col, mode)
    local instance = scenelight:create()
    instance.position = pos or instance.position
    instance.type = LIGHT_RECT
    instance.mins = mins or (0 - vec2.ONE)
    instance.maxs = maxs or vec2.ONE
    instance.color = col or color.WHITE
    instance.mode = mode or LIGHT_MODE_DYNAMIC

    instance:update()

    return instance
end

-- instance functions
function scenelight:render(x, y, scale)
    render.setcol(self.color)

    if(self.type == LIGHT_CIRCLE) then
        
    elseif(self.type == LIGHT_RECT) then
        
    end
end

function scenelight:get_distance()
    if(self.type == LIGHT_CIRCLE) then
        return self.radius or 1
    elseif(self.type == LIGHT_RECT) then
        local width = math.abs(self.maxs.x - self.mins.x)
        local height = math.abs(self.maxs.y - self.mins.y)
        return math.max(width, height) or 1
    end

    return 1
end

function scenelight:set_position(x, y)
    if(y == nil) then 
        self.position = x
    else 
        self.position = vec2(x, y)
    end

    self:update()
end

function scenelight:set_size(...)
    local vargs = {...}
    if(self.type == LIGHT_CIRCLE) then 
        self.radius = vargs[0] or 1
    else 
        self.mins = vargs[0] or (0 - vec2.ONE)
        self.maxs = vargs[1] or vec2.ONE
    end

    self:update()
end

function scenelight:update()
    if(self.scene == nil) then return end

    if(self.mode == LIGHT_MODE_STATIC) then
        self.scene:unregister_light(self)
    end
    
    self.scene:register_light(self)
end

return scenelight