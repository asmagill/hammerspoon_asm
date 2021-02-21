local iokit = require("hs._asm.iokit")

local module = {}

module.bruteForceSearch = function(what, plane)
    plane = plane or "IOService"

    local answers = {}

    local searchSpace = iokit.root():childrenInPlane(plane)

    while (#searchSpace > 0) do
        local item = table.remove(searchSpace, 1)
        for _,v in ipairs(item:childrenInPlane(plane) or {}) do
            table.insert(searchSpace, v)
        end
        local add = false
        for _,v in pairs(item:properties() or {}) do
            if type(v) == type(what) then
                if type(v) == "string" then
                    add = v:match(what) and true or false
                else
                    add = (v == what)
                end
            end
            if add then
                table.insert(answers, { item, item:name() })
                break
            end
        end
    end

    return answers
end

return module
