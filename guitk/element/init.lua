--- === hs._asm.guitk.element ===
---
--- Elements which can be used with `hs._asm.guitk.manager` placement managers for `hs._asm.guitk` windows.

local USERDATA_TAG = "hs._asm.guitk.element"
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

-- Return Module Object --------------------------------------------------

return module
