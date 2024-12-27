local vec2 = {}
local epsilon = 0.0001
local mt = {
    -- index data
    __index = vec2,

    -- tostring override
    __tostring = function(self)
        return string.format("X: %d, Y: %d", self.x, self.y)
    end,

    -- arithmetics
    __add = function(a, b) return vec2.add(a, b) end,
    __sub = function(a, b) return vec2.sub(a, b) end,
    __mul = function(a, b) return vec2.mul(a, b) end,
    __div = function(a, b) return vec2.div(a, b) end,

    -- allow for the vec2 to be called as a method.
    __call = function(self, x, y)
        return vec2.new(x, y)
    end,
}

-- creating new vec2 instance
function vec2.new(x, y)
    local instance = setmetatable({}, mt)
    instance.x = x or 0
    instance.y = y or 0
    return instance
end

-- arithmetics
local function validate_args(left, right) -- left & right
    local left = type(left) == "number" and vec2.new(left, left) or left
    local right = type(right) == "number" and vec2.new(right, right) or right
    return left, right
end

function vec2.add(left, right)
    local left, right = validate_args(left, right)
    return vec2.new(left.x + right.x, left.y + right.y)
end

function vec2.sub(left, right)
    local left, right = validate_args(left, right)
    return vec2.new(left.x - right.x, left.y - right.y)
end

function vec2.mul(left, right)
    local left, right = validate_args(left, right)
    return vec2.new(left.x * right.x, left.y * right.y)
end

function vec2.div(left, right)
    local left, right = validate_args(left, right)
    return vec2.new(left.x / math.max(right.x, epsilon), left.y / math.max(right.y, epsilon))
end

-- helpers
function vec2:dot(other)
    return self.x * other.x + self.y * other.y
end

function vec2:copy()
    return vec2.new(self.x, self.y)
end

function vec2:distance(b)
    return math.sqrt(math.pow(self.x - b.x, 2) + math.pow(self.y - b.y, 2))
end

function vec2:direction(to)
    local dist = self:distance(to)
    return vec2.new((to.x - self.x) / dist, (to.y - self.y) / dist)
end

function vec2:floor()
    return vec2.new(math.floor(self.x), math.floor(self.y))
end

function vec2:length()
    return math.sqrt(math.pow(self.x, 2) + math.pow(self.y, 2))
end

function vec2:normalize()
    local len = math.max(self:length(), epsilon)
    local x = self.x / len
    local y = self.y / len
    return vec2.new(x, y)
end

function vec2:with_x(x)
    local vec = vec2.new()
    vec.x = x or 0
    vec.y = self.y
    return vec
end

function vec2:with_y(y)
    local vec = vec2.new()
    vec.x = self.x
    vec.y = y or 0
    return vec
end

-- math utility
function vec2.random(min, max, seed)
    local x = mathx.random(min.x, max.x, seed)
    local y = mathx.random(min.y, max.y, seed)
    return vec2.new(x, y)
end

function vec2:lerp(b, t, clamp)
    local vec = vec2.new()
    vec.x = mathx.lerp(self.x, b.x, t, clamp)
    vec.y = mathx.lerp(self.y, b.y, t, clamp)
    return vec
end

-- some constants
vec2.ZERO = vec2.new(0, 0)
vec2.ONE = vec2.new(1, 1)
vec2.RIGHT = vec2.new(1, 0)
vec2.LEFT = vec2.new(-1, 0)
vec2.UP = vec2.new(0, -1)
vec2.DOWN = vec2.new(0, 1)

return setmetatable(vec2, mt)