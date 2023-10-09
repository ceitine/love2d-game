local color = {}
local mt = {
    -- index data
    __index = color,

    -- tostring override
    __tostring = function(self)
        return string.format("R: %d, G: %d, B: %d, A: %d", self.r, self.g, self.b, self.a)
    end,

    -- allow for the color to be called as a method.
    __call = function(self, r, g, b, a)
        return color.new(r, g, b, a)
    end,
}

-- creating new color instance
function color.new(r, g, b, a)
    local instance = setmetatable({}, mt)
    instance.r = r or 255
    instance.g = g or 255
    instance.b = b or 255
    instance.a = a or 255

    return instance
end

-- math utility
function color.random(alpha)
    return color.new(math.random(0, 255), math.random(0, 255), math.random(0, 255), alpha and math.random(0, 255) or 255)
end

function color.from32(integer)
    local r = bit.rshift(bit.band(integer, 0xFF000000), 24)
    local g = bit.rshift(bit.band(integer, 0xFF0000), 16)
    local b = bit.rshift(bit.band(integer, 0xFF00), 8)
    local a = bit.band(integer, 0xFF)
    
    return color.new(r, g, b, a)
end

function color:to32()
    local value = bit.lshift(self.r, 24) 
        + bit.lshift(self.g, 16)
        + bit.lshift(self.b, 8)
        + self.a
    return value
end

function color:lerp(b, t)
    self.r = mathx.lerp(self.r, b.r, t)
    self.g = mathx.lerp(self.g, b.g, t)
    self.b = mathx.lerp(self.b, b.b, t)
    self.a = mathx.lerp(self.a, b.a, t)

    return self
end

-- some constants
color.WHITE = color.new()
color.BLACK = color.new(0, 0, 0, 255)
color.TRANSPARENT = color.new(0, 0, 0, 0)

return setmetatable(color, mt)