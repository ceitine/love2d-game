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

-- helpers
function color:with_red(red)
    self.r = red or 255
    return self
end

function color:with_green(green)
    self.g = green or 255
    return self
end

function color:with_blue(blue)
    self.b = blue or 255
    return self
end

function color:with_alpha(alpha)
    self.a = alpha or 255
    return self
end

-- math utility
function color.random(alpha, seed)
    return color.new(mathx.random(0, 255, seed), mathx.random(0, 255, seed + 1), mathx.random(0, 255, seed + 2), alpha and mathx.random(0, 255, seed + 3) or 255)
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
color.WHITE = color.new(255, 255, 255, 255)
color.BLACK = color.new(0, 0, 0, 255)
color.TRANSPARENT = color.new(0, 0, 0, 0)

return setmetatable(color, mt)