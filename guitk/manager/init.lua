--- === hs._asm.guitk.manager ===
---
--- Element placement managers for use with `hs._asm.guitk` windows.

local USERDATA_TAG = "hs._asm.guitk.manager"
local module       = require(USERDATA_TAG .. ".internal")
local managerMT    = hs.getObjectMetatable(USERDATA_TAG)

local fnutils = require("hs.fnutils")
local inspect = require("hs.inspect")

-- in case I ever get the specialized managers working
local metatables = {}
local basePath = package.searchpath(USERDATA_TAG, package.path)
if basePath then
    basePath = basePath:match("^(.+)/init.lua$")
    local fs = require("hs.fs")
    for file in fs.dir(basePath) do
        if file:match("%.so$") then
            local name = file:match("^(.*)%.so$")
            if name ~= "internal" then
                module[name] = require(USERDATA_TAG .. "." .. name)
                metatables[name] = hs.getObjectMetatable(USERDATA_TAG .. "." .. name)
            end
        end
    end

    if fs.attributes(basePath .. "/docs.json") then
        require"hs.doc".registerJSONFile(basePath .. "/docs.json")
    end
else
    return error("unable to determine basepath for " .. USERDATA_TAG, 2)
end

local log = require("hs.logger").new(USERDATA_TAG, require"hs.settings".get(USERDATA_TAG .. ".logLevel") or "warning")

-- private variables and methods -----------------------------------------

-- can't use inspect directly because the tables are dynamically generated
local dump_table = function(value)
    local keyWidth = 0
    for k,v in pairs(value) do
        local currentWidth = #tostring(k)
        if type(k) == "number" then currentWidth = currentWidth + 2 end
        if currentWidth > keyWidth then keyWidth = currentWidth end
    end
    local result = "{\n"
    for k,v in fnutils.sortByKeys(value) do
        local displayValue = v
        if type(v) == "table" then
            displayValue = (inspect(v):gsub("%s+", " "))
        elseif type(v) == "string" then
            displayValue = "\"" .. v .. "\""
        end
        local displayKey = k
        if type(k) == "number" then
            displayKey = "[" .. tostring(k) .. "]"
        end
        result = result .. string.format("  %-" .. tostring(keyWidth) .. "s = %s,\n", tostring(displayKey), tostring(displayValue))
    end
    result = result .. "}"
    return result
end

local wrappedElementMT = {
    __e = setmetatable({}, { __mode = "k" })
}

wrappedElementMT.__index = function(_, key)
    local obj = wrappedElementMT.__e[_]
    local properties = obj.manager:elementProperties(obj.item)
    return properties[key]
end

wrappedElementMT.__newindex = function(_, key, value)
    local obj = wrappedElementMT.__e[_]
    obj.manager:elementProperties(obj.item, { [key] = value })
end

wrappedElementMT.__pairs = function(_)
    local obj = wrappedElementMT.__e[_]
    local propertiesList = getmetatable(obj.item)["_propertyList"] or {}
    if #propertiesList > 0 then table.insert(propertiesList, "location") end

    return function(__, k)
        local nextK, v = table.remove(propertiesList), nil
        if nextK then
            if nextK == "location" then
                v = obj.manager:elementLocation(obj.item)
            else
                v = obj.item[nextK](obj.item)
            end
        end
        return k, v
    end, _, nil

end

-- wrappedElementMT.__len -- for now we don't have any elements that might act in an array like capacity

wrappedElementMT.__tostring = function(_)
    local obj = wrappedElementMT.__e[_]
    local properties = obj.manager:elementProperties(obj.item)
    return dump_table(properties)
end

local wrappedElementWithMT = function(manager, item)
    local newItem = {}
    wrappedElementMT.__e[newItem] = { manager = manager, item = item }
    return setmetatable(newItem, wrappedElementMT)
end

-- Public interface ------------------------------------------------------

managerMT.elementProperties = function(self, item, ...)
    local args = table.pack(...)
    if args.n == 0 or (args.n == 1 and type(args[1]) == "table") then
        if args.n == 0 then
            local results = {}
            local propertiesList = getmetatable(item)["_propertyList"]
            if propertiesList then
                for i,v in ipairs(propertiesList) do results[v] = item[v](item) end
            end
            results["location"] = self:elementLocation(item)
            results.__self = item
            results.__type = getmetatable(item).__type
            results.__fittingSize = self:elementFittingSize(item)
            return setmetatable(results, { __tostring = function(o) return dump_table(o) end })
        else
            local propertiesList = getmetatable(item)["_propertyList"]
            if propertiesList then
                for k,v in pairs(args[1]) do
                    if k == "location" then
                        self:elementLocation(item, v)
                    elseif fnutils.contains(propertiesList, k) then
                        item[k](item, v)
                    else
                        log.wf("%s property %s for element %s; ignoring", (k:match("^__") and "unsettable" or "invalid"), k, tostring(self))
                    end
                end
            end
            return self
        end
    else
        error("expected table of properties for argument 2", 2)
    end
end

-- pass through method requests that aren't defined for the manager to the guitk object itself
managerMT.__core = managerMT.__index
managerMT.__index = function(self, key)
    if managerMT.__core[key] then
        return managerMT.__core[key]
    elseif math.type(key) == "integer" then
        local elements = self:elements()
        local item = elements[key]
        if item then return wrappedElementWithMT(self, item) end
    else
        local parentFN = self:_nextResponder()[key]
        if parentFN then
            return function(self, ...) return parentFN(self:_nextResponder(), ...) end
        end
    end
    return nil
end

managerMT.__len = function(self)
    return #self:elements()
end

-- in case I ever get the specialized managers working
for k,v in pairs(metatables) do
    if v._nextResponder then
        v.__core = v.__index
        v.__index = function(self, key)
            if v.__core[key] then
                return v.__core[key]
            else
                local parentFN = self:_nextResponder()[key]
                if parentFN then
                    return function(self, ...) return parentFN(self:_nextResponder(), ...) end
                end
            end
            return nil
        end
    end
end

-- Return Module Object --------------------------------------------------

return module
