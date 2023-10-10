local tile = {}
local mt = {
    -- index data
    __index = tile,
}

-- variables
tile.texture_index = 1

-- creating new tile instance
function tile:create(o)
    local instance = o or {}
    setmetatable(instance, mt)
    self.__index = instance
    return instance
end

function tile.new(texture_index)
    local instance = tile:create()
    instance.texture_index = texture_index or 1
    return instance
end

return tile