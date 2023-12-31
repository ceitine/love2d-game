local mathx = {}

function mathx.lerp(a, b, t)
    return a + (b - a) * t
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

return mathx