local mathx = {}

function mathx.lerp(a, b, delta, clamp)
    clamp = clamp or true
    delta = delta or 0
    
    if(clamp) then 
        delta = math.max(math.min(delta, 1), 0)
    end

    return a + (b - a) * delta
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