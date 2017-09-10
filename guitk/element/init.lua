--- === hs._asm.guitk.element ===
---
--- Elements which can be used with `hs._asm.guitk.manager` objects for display `hs._asm.guitk` windows.

local USERDATA_TAG = "hs._asm.guitk.element"
local module       = {}

local fnutils = require("hs.fnutils")
local inspect = require("hs.inspect")

local metatables = {}
local basePath = package.searchpath(USERDATA_TAG, package.path)
if basePath then
    basePath = basePath:match("^(.+)/init.lua$")
    local fs = require("hs.fs")
    for file in fs.dir(basePath) do
        if file:match("%.so$") then
            local name = file:match("^(.*)%.so$")
            module[name] = require(USERDATA_TAG .. "." .. name)
            metatables[name] = hs.getObjectMetatable(USERDATA_TAG .. "." .. name)
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

for k,v in pairs(metatables) do
    if v._propertyList and not v.properties then
        v.properties = function(self, ...)
            local args = table.pack(...)
            if args.n == 0 or (args.n == 1 and type(args[1]) == "table") then
                if args.n == 0 then
                    local results = {}
                    local propertiesList = v._propertyList
                    if propertiesList then
                        for i2,v2 in ipairs(propertiesList) do results[v2] = self[v2](self) end
                    end
                    return setmetatable(results, { __tostring = inspect })
                else
                    local propertiesList = getmetatable(self)["_propertyList"]
                    if propertiesList then
                        for k2,v2 in pairs(args[1]) do
                            if fnutils.contains(propertiesList, k2) then
                                self[k2](self, v2)
                            end
                        end
                    end
                    return self
                end
            else
                error("expected table of properties for argument 1", 2)
            end
        end
    end
end

-- Return Module Object --------------------------------------------------

return module
