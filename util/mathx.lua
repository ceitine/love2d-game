local mathx = {}

function mathx.lerp(a, b, t)
    return a + (b - a) * t
end

function mathx.random(min, max)
    return love.math.random(min, max)
end

return mathx