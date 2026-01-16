local mathx = {}
local DEG2RAD = 0.0174532925
local RAD2DEG = 57.2957795

function mathx.deg2rad(a)
    return a * DEG2RAD
end

function mathx.rad2deg(a)
    return a * RAD2DEG
end

function mathx.lerp(a, b, delta, clamp)
    clamp = clamp or true
    delta = delta or 0
    
    if(clamp) then 
        delta = math.max(math.min(delta, 1), 0)
    end

    return a + (b - a) * delta
end

function mathx.remap(value, min, max, newMin, newMax, clamp)
    local delta = (value - min) / (max - min); 
    if(clamp) then
        delta = mathx.clamp(delta, 0, 1)
    end

    local remapped = newMin + delta * (newMax - newMin);
    return remapped
end

function mathx.random(min, max, seed)
    if(seed ~= nil) then
        love.math.setRandomSeed(tonumber(seed) or time.now)
    end
    return love.math.random(min, max)
end

function mathx.clamp(value, min, max)
    return math.max(math.min(value, max), min)
end

function mathx.nearly(a, b, epsilon)
    local epsilon = epsilon or 0.0001
    local result = math.abs(a - b) < epsilon
    return result
end

return mathx