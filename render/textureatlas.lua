local textureatlas = {}
local mt = {
    -- index data
    __index = textureatlas,
}

-- variables
textureatlas.image = nil
textureatlas.size = nil
textureatlas.count = 0

-- create new texture atlas
function textureatlas:create(o)
    local instance = o or {}
    setmetatable(instance, mt)
    self.__index = instance
    return instance
end

function textureatlas.new(path, size)
    local instance = textureatlas:create()
    instance.size = size or 32

    local data = love.image.newImageData(path)
    local slices = {}
    for x = 1, data:getWidth() / instance.size do
        slices[x] = love.image.newImageData(instance.size, instance.size)
        slices[x]:paste(data, 0, 0, (x - 1) * instance.size, 0, instance.size, instance.size)

        instance.count = instance.count + 1
    end

    instance.image = love.graphics.newArrayImage(slices)
    instance.image:setFilter("nearest", "nearest")
    instance.image:setWrap("repeat", "repeat", "clampzero")

    return instance
end

return textureatlas