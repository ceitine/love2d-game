local hook = {}
local cache = {}

function hook.register(identifier, event, callback)
    if(cache[event] == nil) then
        cache[event] = {}
    end

    if(type(callback) ~= "function") then
        return
    end

    cache[event][identifier] = callback
end

function hook.unregister(identifier, event)
    if(cache[event] == nil or cache[event][identifier] == nil) then
        return
    end

    cache[event][identifier] = nil
end

function hook.call(event, ...)
    if(cache[event] == nil) then
        return
    end

    for identifier, v in pairs(cache[event]) do
        v(...)
    end
end

return hook