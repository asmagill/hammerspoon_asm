--- === hs._asm.reachability ===
---
--- Stuff about the module

local USERDATA_TAG = "hs._asm.reachability"
local module       = require(USERDATA_TAG..".internal")
local object       = hs.getObjectMetatable(USERDATA_TAG)

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

module.flags            = _makeConstantsTable(module.flags)
module.specialAddresses = _makeConstantsTable({
    IN_LINKLOCALNETNUM = 0xA9FE0000, -- 169.254.0.0
    INADDR_ANY         = 0x00000000, -- 0.0.0.0
})

module.forIPv4Address = function(address)
    local addressAsTable = {}
    if type(address) == "string" then
        addressAsTable = table.pack(address:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$"))
    elseif type(address) == "table" or type(address) == "number" then
        addressAsTable = address
    end
    return module._forIPv4Address(addressAsTable)
end

module.forIPv4AddressPair = function(Laddress, Raddress)
    local LaddressAsTable = {}
    if type(Laddress) == "string" then
        LaddressAsTable = table.pack(Laddress:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$"))
    elseif type(Laddress) == "table" or type(Laddress) == "number" then
        LaddressAsTable = Laddress
    end
    local RaddressAsTable = {}
    if type(Raddress) == "string" then
        RaddressAsTable = table.pack(Raddress:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$"))
    elseif type(Raddress) == "table" or type(Raddress) == "number" then
        LaddressAsTable = Raddress
    end
    return module._forIPv4AddressPair(LaddressAsTable, RaddressAsTable)
end

module.internet = function()
    return module.forIPv4Address(module.specialAddresses.INADDR_ANY)
end

module.linklocal = function()
    return module.forIPv4Address(module.specialAddresses.IN_LINKLOCALNETNUM)
end

-- Return Module Object --------------------------------------------------

return module
