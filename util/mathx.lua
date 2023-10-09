local mathx = {}

function mathx.lerp(a, b, t)
    return a + (b - a) * t
end

return mathx