--- === hs._asm.btle ===
---
--- Hammerspoon module for Core Bluetooth Objects.
---
---  This module provides an interface to the Core Bluetooth OS X Object classes for accessing BTLE devices.  This module currently requires OS X 10.9 or later to function and will refuse to load if you are running an earlier version of OS X.
---
--- Currently this module only supports Hammerspoon as a BTLE Manager, not as a BTLE Peripheral.  Peripheral support may come in a companion module in the future.
---
--- This code is still very experimental.

local USERDATA_TAG     = "hs._asm.btle"
local data = package.searchpath(USERDATA_TAG, package.path):match("^(/.*/).*%.lua$").."org.bluetooth.txt"

if require("hs.host").operatingSystemVersion().minor < 9 then
    error(USERDATA_TAG.." requires OS X 10.9 or newer",2)
-- actually, only a few of the obj-c methods do, and can be mostly wrapped with deprecated methods, so maybe I'll fix it later, but since Hammerspoon officially only supports 10.9 and later, for now I say meh.
end

module           = {}
local core       = require(USERDATA_TAG..".internal")
local log        = require("hs.logger").new("btle","verbose") -- for debugging, change back to info or warn when more tested
-- module._core     = core
module.log       = log

local peripheral = hs.getObjectMetatable(USERDATA_TAG..".peripheral")

module.gattByUUID, module.gattByName = {}, {}
local tableType, url
for line in io.lines(data) do
    if line:match("^https:") then
        tableType = line:match("^https:.*/(%w+)Home.*%.aspx$"):lower()
        url = line
    elseif line ~= "" then
        local desc, name, number = line:match("^([^\t]+)\t([^\t]+)\t0[xX]([^\t]+)$")
--         print(desc, name, number)
        module.gattByUUID[number] = {
            uuid = number,
            description = desc,
            name = name,
            ["type"] = tableType,
            url = url
        }
        module.gattByName[name] = module.gattByUUID[number]
    end
end
core._assignGattLookup(module.gattByUUID)
core._assignGattLookup = nil -- it should only be called once

-- private variables and methods -----------------------------------------

local _kMetaTable = {}
-- planning to experiment with using this with responses to functional queries... and I
-- don't want to keep loose generated data hanging around
_kMetaTable._k = setmetatable({}, {__mode = "k"})
_kMetaTable._t = setmetatable({}, {__mode = "k"})
_kMetaTable.__index = function(obj, key)
        if _kMetaTable._k[obj] then
            if _kMetaTable._k[obj][key] then
                return _kMetaTable._k[obj][key]
            else
                for k,v in pairs(_kMetaTable._k[obj]) do
                    if v == key then return k end
                end
            end
        end
        return nil
    end
_kMetaTable.__newindex = function(obj, key, value)
        error("attempt to modify a table of constants",2)
        return nil
    end
_kMetaTable.__pairs = function(obj) return pairs(_kMetaTable._k[obj]) end
_kMetaTable.__len = function(obj) return #_kMetaTable._k[obj] end
_kMetaTable.__tostring = function(obj)
        local result = ""
        if _kMetaTable._k[obj] then
            local width = 0
            for k,v in pairs(_kMetaTable._k[obj]) do width = width < #tostring(k) and #tostring(k) or width end
            for k,v in require("hs.fnutils").sortByKeys(_kMetaTable._k[obj]) do
                if _kMetaTable._t[obj] == "table" then
                    result = result..string.format("%-"..tostring(width).."s %s\n", tostring(k),
                        ((type(v) == "table") and "{ table }" or tostring(v)))
                else
                    result = result..((type(v) == "table") and "{ table }" or tostring(v)).."\n"
                end
            end
        else
            result = "constants table missing"
        end
        return result
    end
_kMetaTable.__metatable = _kMetaTable -- go ahead and look, but don't unset this

local _makeConstantsTable
_makeConstantsTable = function(theTable)
    if type(theTable) ~= "table" then
        local dbg = debug.getinfo(2)
        local msg = dbg.short_src..":"..dbg.currentline..": attempting to make a '"..type(theTable).."' into a constant table"
        if module.log then module.log.ef(msg) else print(msg) end
        return theTable
    end
    for k,v in pairs(theTable) do
        if type(v) == "table" then
            local count = 0
            for a,b in pairs(v) do count = count + 1 end
            local results = _makeConstantsTable(v)
            if #v > 0 and #v == count then
                _kMetaTable._t[results] = "array"
            else
                _kMetaTable._t[results] = "table"
            end
            theTable[k] = results
        end
    end
    local results = setmetatable({}, _kMetaTable)
    _kMetaTable._k[results] = theTable
    local count = 0
    for a,b in pairs(theTable) do count = count + 1 end
    if #theTable > 0 and #theTable == count then
        _kMetaTable._t[results] = "array"
    else
        _kMetaTable._t[results] = "table"
    end
    return results
end


-- Public interface ------------------------------------------------------

-- TODO: Wrap this up in a nice neat table which can be returned as a "userdata" so methods can be applied and multiple
--       "users" can use the same manager for their own queries, etc.

peripheral.setCallback = function(self, fn)
    for i,v in ipairs(module.discovered) do
        if v.peripheral == self then
            if fn == nil then
                v.fn = nil
            elseif type(fn) == "function" then
                v.fn = fn
            else
                error("expected function or nil", 2)
            end
            break
        end
    end
    return self
end

module.userCallbacks            = {}
module.UUIDLookup               = _makeConstantsTable(core.UUIDLookup)
module.characteristicProperties = _makeConstantsTable(core.characteristicProperties)
module.gattByUUID               = _makeConstantsTable(module.gattByUUID)
module.gattByName               = _makeConstantsTable(module.gattByName)

module.discovered = {}

module.create = function()
    if module.manager then
        log.wf("%s already initialized", USERDATA_TAG)
    else
        module.manager = core.create():setCallback(function(manager, message, ...)
            log.vf("manager callback:%s -- %s", message, hs.utf8.asciiOnly(hs.inspect(table.pack(...))))
            if     message == "didConnectPeripheral" then
            elseif message == "didDisconnectPeripheral" then
            elseif message == "didFailToConnectPeripheral" then
            elseif message == "didDiscoverPeripheral" then
                local exists = false
                local peripheral, advertisementData, RSSI = ...
                for i,v in ipairs(module.discovered) do
                    if v.peripheral == peripheral then
                        -- in case they've changed
                        v.advertisement = advertisementData
                        v.RSSI          = RSSI
                        v.name          = peripheral:name()
                        -- really what we care most about at this stage
                        v.lastSeen      = os.time()
                        exists = true
                        break
                    end
                end
                if not exists then
                    table.insert(module.discovered, {
                        peripheral    = peripheral,
                        name          = peripheral:name(),
                        advertisement = advertisementData,
                        RSSI          = RSSI,
                        lastSeen      = os.time()
                    })
                end
            elseif message == "didRetrieveConnectedPeripherals" then
            elseif message == "didRetrievePeripherals" then
            elseif message == "didUpdateState" then
                local state = manager:state()
                if state == "poweredOn" then
                    log.i("btle powered on")
                -- uses more power, so don't auto-enable scan
                --     manager:startScan()
                elseif state == "poweredOff" then
                -- probably automatically turned off, but lets be explicit
                    manager:stopScan()
                    log.i("btle powered off, any running scans disabled")
                else
                -- any other state invalidates any peripheral records we may already have
                    log.wf("btle state %s: invalidating discovered peripherals", state)
                    module.discovered = {}
                end
            elseif message == "willRestoreState" then
            end
            if #module.userCallbacks then
                for i,v in ipairs(module.userCallbacks) do v(manager, message, ...) end
            end
        end):setPeripheralCallback(function(peripheral, message, ...)
            log.vf("peripheral callback:%s -- %s", message, hs.utf8.asciiOnly(hs.inspect(table.pack(...))))
            for i,v in ipairs(module.discovered)  do
                if v.peripheral == peripheral and v.fn then
                    v.fn(peripheral, message, ...)
                    break
                end
            end
        end)
    end
end

module.delete = function()
    if module.manager then
        module.manager = module.manager:delete()
    end
end

module.startScanning = function()
    if not module.manager then
        log.ef("%s manager has not been created", USERDATA_TAG)
    else
        local state = module.manager:state()
        if state ~= "poweredOn" then
            error("btle state "..state..": scanning disabled", 2)
        end
        module.manager:startScan()
    end
end

module.stopScanning = function()
    if not module.manager then
        log.ef("%s manager has not been created", USERDATA_TAG)
    else
        module.manager:stopScan()
    end
end

-- Return Module Object --------------------------------------------------

module.create()

return module
