--- === hs._asm.guitk.manager ===
---
--- Element placement managers for use with `hs._asm.guitk` windows.

local USERDATA_TAG = "hs._asm.guitk.manager"
local module = {}
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

-- pass through method requests that aren't defined for the manager to the guitk object itself
for k,v in pairs(metatables) do
    if v._guitk then
        v.__core = v.__index
        v.__index = function(self, key) return v.__core[key] or (self:_guitk() or {})[key] end
    end
end

-- Return Module Object --------------------------------------------------

return module
