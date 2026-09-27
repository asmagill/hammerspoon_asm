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

        local USERDATA_TAG = "hs._asm.btle"
        local subModules = {
        --  name         lua or library?
            peripheral     = false,
            service        = false,
            characteristic = false,
            descriptor     = false,
        }

        local preload = function(m, isLua)
            return function()
                local el = isLua and require(USERDATA_TAG .. "_" .. m)
                                 or  require(table.concat({ USERDATA_TAG:match("^([%w%._]+%.)([%w_]+)$") }, "lib") .. "_" .. m)
                return el
            end
        end

        for k, v in pairs(subModules) do
            package.preload[USERDATA_TAG .. "." .. k] = preload(k, v)
        end

    until true -- executes once and hides any local variables we create
-- END REMOVE IF ADDED TO CORE APPLICATION

local inspect = require("hs.inspect")

--- === hs._asm.module ===
---
--- Stuff about the module

local USERDATA_TAG = "hs._asm.btle"
local module       = require(table.concat({ USERDATA_TAG:match("^([%w%._]+%.)([%w_]+)$") }, "lib"))

module.peripheral     = require(USERDATA_TAG .. ".peripheral")
module.service        = require(USERDATA_TAG .. ".service")
module.characteristic = require(USERDATA_TAG .. ".characteristic")
module.descriptor     = require(USERDATA_TAG .. ".descriptor")

-- settings with periods in them can't be watched via KVO with hs.settings.watchKey, so
-- in general it's a good idea not to include periods
-- local SETTINGS_TAG = USERDATA_TAG:gsub("%.", "_")
-- local settings     = require("hs.settings")
-- local log          = require("hs.logger").new(USERDATA_TAG, settings.get(SETTINGS_TAG .. "_logLevel") or "warning")

-- private variables and methods -----------------------------------------

local btleMT           = hs.getObjectMetatable(USERDATA_TAG)
local characteristicMT = hs.getObjectMetatable(USERDATA_TAG .. ".characteristic")
local descriptorMT     = hs.getObjectMetatable(USERDATA_TAG .. ".descriptor")
local peripheralMT     = hs.getObjectMetatable(USERDATA_TAG .. ".peripheral")
local serviceMT        = hs.getObjectMetatable(USERDATA_TAG .. ".service")

-- Public interface ------------------------------------------------------

peripheralMT.connect = function(self, ...)
    local manager = self:manager()
    if manager then
        manager:connectPeripheral(self, ...)
        return self
    else
        return nil, "no manager associated with peripheral"
    end
end

peripheralMT.disconnect = function(self, ...)
    local manager = self:manager()
    if manager then
        manager:disconnectPeripheral(self, ...)
        return self
    else
        return nil, "no manager associated with peripheral"
    end
end

local _characteristic_properties = characteristicMT.properties
characteristicMT.properties = function(self, ...)
    return setmetatable(_characteristic_properties(self, ...), {
        __tostring = inspect,
    })
end

-- Return Module Object --------------------------------------------------

return module
