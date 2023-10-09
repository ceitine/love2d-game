local stringx = {}

local function format_string(value)
    return type(value) == "string" and "\"".. value.. "\"" or tostring(value)
end

function stringx.table(tbl, indents, iterations)
    local result = "{\n"
    iterations = iterations or 100 
    indents = indents or 1

    -- go through table values
    for key, value in pairs(tbl) do
        if iterations == 0 then
            break
        end

        if(key ~= "_G") then -- lol
            -- append key
            result = result.. string.rep("\t", indents).. "[".. format_string(key).. "] = "

            -- append value
            local t = type(value)
            if(t == "table") then
                result = result.. stringx.table(value, indents + 1, iterations)
            else
                result = result.. tostring(format_string(value))
            end

            -- append new line
            result = result.. ",\n"
            
            iterations = iterations - 1
        end
    end

    -- return result
    return result.. string.rep("\t", indents - 1).. "}"
end

return stringx