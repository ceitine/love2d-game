local vertexbuffer = {}
local mt = {
    -- index data
    __index = vertexbuffer
}
vertexbuffer.vertices = {}
vertexbuffer.indices = {}

function vertexbuffer:create(o)
    local instance = o or {}
    setmetatable(instance, mt)
    self.__index = instance
    return instance
end

function vertexbuffer.new()
    local instance = vertexbuffer:create()
    return instance
end

function vertexbuffer:add_index(i)
    self.indices[#self.indices + 1] = i
end

function vertexbuffer:add_vertex(v)
    local index = #self.vertices + 1
    self.vertices[index] = v
    return index
end

function vertexbuffer:add_triangle(i1, i2, i3)
    self:add_index(i1)
    self:add_index(i2)
    self:add_index(i3)
end

function vertexbuffer:add_quad(v1, v2, v3, v4)
    -- add vertices
    local i1 = self:add_vertex(v1)
    local i2 = self:add_vertex(v2)
    local i3 = self:add_vertex(v3)
    local i4 = self:add_vertex(v4)

    -- add indices in the form of triangles
    self:add_triangle(i1, i2, i3)
    self:add_triangle(i3, i2, i4)
end

return vertexbuffer