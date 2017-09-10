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

-- local log = require("hs.logger").new(USERDATA_TAG, require"hs.settings".get(USERDATA_TAG .. ".logLevel") or "warning")

-- private variables and methods -----------------------------------------

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
            return setmetatable(results, { __tostring = inspect })
        else
            local propertiesList = getmetatable(item)["_propertyList"]
            if propertiesList then
                for k,v in pairs(args[1]) do
                    if k == "location" then
                        self:elementLocation(item, v)
                    elseif fnutils.contains(propertiesList, k) then
                        item[k](item, v)
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
    else
        local parentFN = self:_guitk()[key]
        if parentFN then
            return function(self, ...) return parentFN(self:_guitk(), ...) end
        end
    end
    return nil
end

-- in case I ever get the specialized managers working
for k,v in pairs(metatables) do
    if v._guitk then
        v.__core = v.__index
        v.__index = function(self, key)
            if v.__core[key] then
                return v.__core[key]
            else
                local parentFN = self:_guitk()[key]
                if parentFN then
                    return function(self, ...) return parentFN(self:_guitk(), ...) end
                end
            end
            return nil
        end
    end
end

-- Return Module Object --------------------------------------------------

return module
