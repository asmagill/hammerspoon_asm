-- REMOVE IF ADDED TO CORE APPLICATION
    repeat
        -- add proper user dylib path if it doesn't already exist
        if not package.cpath:match(hs.configdir .. "/%?.dylib") then
            package.cpath = hs.configdir .. "/?.dylib;" .. package.cpath
        end

        -- load docs file if provided
        local basePath, moduleName = debug.getinfo(1, "S").source:match("^@(.*)/([%w_]+).lua$")
        if basePath and moduleName then
            if moduleName == "init" then
                moduleName = moduleName:match("/([%w_]+)$")
            end

            local docsFileName = basePath .. "/" .. moduleName .. ".docs.json"
            if require"hs.fs".attributes(docsFileName) then
                require"hs.doc".registerJSONFile(docsFileName)
            end
        end

        -- setup loaders for submodules (if any)
        --     copy into Hammerspoon/setup.lua before removing

    until true -- executes once and hides any local variables we create
-- END REMOVE IF ADDED TO CORE APPLICATION

--- === hs._asm.iokit ===
---
--- This module provides tools for querying macOS and hardware with the IOKit library, take 2... or 3, I forget.

local USERDATA_TAG = "hs._asm.iokit"
local module       = require(table.concat({ USERDATA_TAG:match("^([%w%._]+%.)([%w_]+)$") }, "lib"))
local objectMT     = hs.getObjectMetatable(USERDATA_TAG)

-- settings with periods in them can't be watched via KVO with hs.settings.watchKey, so
-- in general it's a good idea not to include periods
-- local SETTINGS_TAG = USERDATA_TAG:gsub("%.", "_")
-- local settings     = require("hs.settings")
-- local log          = require("hs.logger").new(USERDATA_TAG, settings.get(SETTINGS_TAG .. "_logLevel") or "warning")

-- private variables and methods -----------------------------------------

local subModules = {
--  name         lua or library?
    constants       = false,
    power           = false,
}

-- set up preload for elements so that when they are loaded, the methods from _control and/or
-- __view are also included and the property lists are setup correctly.
local preload = function(m, isLua)
    return function()
        local el = isLua and require(USERDATA_TAG .. "_" .. m)
                         or  require(table.concat({ USERDATA_TAG:match("^([%w%._]+%.)([%w_]+)$") }, "lib") .. "_" .. m)
        return el
    end
end

for k, v in pairs(subModules) do
    if type(v) == "boolean" then
        package.preload[USERDATA_TAG .. "." .. k] = preload(k, v)
    end
end

-- Public interface ------------------------------------------------------

local _planes = {}
for _, v in pairs(module.rootEntry():properties().IORegistryPlanes) do
    table.insert(_planes, v)
end
module.planes = ls.makeConstantsTable(_planes)

for name, func in pairs(module) do
    local typeName = name:match("^_matching(%w+)$")
    print(name, typeName)
    if typeName then
        module["serviceFor" .. typeName] = function(...)
            local matchCriteria = func(...)
            return matchCriteria and module.serviceMatching(matchCriteria) or nil
        end
        module["servicesFor" .. typeName] = function(...)
            local matchCriteria = func(...)
            return matchCriteria and module.servicesMatching(matchCriteria) or {}
        end
    end
end

objectMT.bundleID = function(self, ...)
    return module.bundleIDForClass(self:class(...))
end

objectMT.superclass = function(self, ...)
    return module.superclassForClass(self:class(...))
end

-- Return Module Object --------------------------------------------------

return setmetatable(module, {
    __index = function(self, key)
        if type(subModules[key]) ~= "nil" then
            module[key] = require(USERDATA_TAG .. "." ..key)
            return module[key]
        else
            return nil
        end
    end,
})
