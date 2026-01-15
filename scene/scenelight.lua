local scenelight = {}
local mt = {
    -- index data
    __index = scenelight,
}

-- constants
LIGHT_CIRCLE = 0
LIGHT_RECT = 1

-- variables
scenelight.position = nil
scenelight.scene = nil
scenelight.type = LIGHT_CIRCLE
scenelight.color = nil

-- creating new light instance
function scenelight:create(o)
    local instance = o or {}
    instance.position = vec2.ZERO:copy()
    instance.scene = SCENE

    setmetatable(instance, mt)
    self.__index = instance
    return instance
end

function scenelight.circle(radius, col)
    local instance = scenelight:create()
    instance.type = LIGHT_CIRCLE
    instance.radius = radius or 1
    instance.color = col or color.WHITE

    return instance
end

function scenelight.rectangle(mins, maxs, col)
    local instance = scenelight:create()
    instance.type = LIGHT_RECT
    instance.mins = mins or (0 - vec2.ONE)
    instance.maxs = maxs or vec2.ONE
    instance.color = col or color.WHITE

    return instance
end

-- instance functions
function scenelight:set_position(x, y)
    if(y == nil) then 
        self.position = x
    else 
        self.position = vec2(x, y)
    end
end

function scenelight:set_size(...)
    local vargs = {...}
    if(self.type == LIGHT_CIRCLE) then 
        self.radius = vargs[0] or 1
    else 
        self.mins = vargs[0] or (0 - vec2.ONE)
        self.maxs = vargs[1] or vec2.ONE
    end
end

return scenelight