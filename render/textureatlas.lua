local textureatlas = {}
local mt = {
    -- index data
    __index = tile,
}

-- variables
textureatlas.image = nil
textureatlas.size = nil

-- create new texture atlas
function textureatlas.new(path, size)
    local instance = setmetatable({}, mt)
    instance.size = size or 32

    local data = love.image.newImageData(path)
    local slices = {}
    for x = 1, data:getWidth() / instance.size do
        slices[x] = love.image.newImageData(instance.size, instance.size)
        slices[x]:paste(data, 0, 0, (x - 1) * instance.size, 0, instance.size, instance.size)
    end

    instance.image = love.graphics.newArrayImage(slices)
    instance.image:setFilter("nearest", "nearest")
    instance.image:setWrap("repeat", "repeat", "clampzero")

    return instance
end

function textureatlas:test_draw(index)
    love.graphics.drawLayer(self.image, index, 0, 0)
end

return textureatlas