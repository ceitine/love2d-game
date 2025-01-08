local entity = {}
local mt = {
    -- index data
    __index = entity,
}

-- creating new tile instance
function entity:create(o)
    local instance = o or {}
    instance.scene = SCENE
    if(not instance.scene) then
        return 
    end
    
    instance.id = instance.scene:register_entity(instance)
    instance.components = {}

    setmetatable(instance, mt)
    self.__index = instance
    return instance
end

function entity.new()
    local instance = entity:create()
    return instance
end

-- instance functions
function entity:destroy()
    if(self.scene == nil) then return end
    self.scene:remove_entity(self.id)
end

function entity:add_component(component, data)
    local _type = type(component)
    local id = #self.components + 1

    -- create component from name
    if(_type == "string") then
        local name = component
        local component = {} -- todo: create component from name, assign data
        
        component.id = id
        component.entity = self

        return component
    end

    -- add component instance
    if(_type ~= "table") then return end
    
    self.components[id] = component
    component.id = id
    component.entity = self

    return component
end

function entity:remove_component(component)
    for _, comp in pairs(self.components) do
        if(comp == component) then
            
    end
end

function entity:has_component(name)
    return false
end

return tile