
local USERDATA_TAG = "hs._asm.enclosure.webview"

local osVersion = require"hs.host".operatingSystemVersion()
if (osVersion["major"] == 10 and osVersion["minor"] < 10) then
    hs.luaSkinLog.wf("%s is only available on OS X 10.10 or later", USERDATA_TAG)
    -- nil gets interpreted as "nothing" and thus "true" by require...
    return false
end

local module       = require(USERDATA_TAG .. ".internal")
module.usercontent = require(USERDATA_TAG .. ".usercontent")

local objectMT     = hs.getObjectMetatable(USERDATA_TAG)

if (osVersion["major"] == 10 and osVersion["minor"] < 11) then
    local message = USERDATA_TAG .. ".datastore is only available on OS X 10.11 or later"
    module.datastore = setmetatable({}, {
        __index = function(_)
            hs.luaSkinLog.w(message)
            return nil
        end,
        __tostring = function(_) return message end,
    })
else
    module.datastore   = require(USERDATA_TAG .. ".datastore")
    objectMT.datastore = module.datastore.fromWebview
end

-- required for image support
require("hs.image")

-- private variables and methods -----------------------------------------

local _kMetaTable = {}
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

module.certificateOIDs = _makeConstantsTable(module.certificateOIDs)

objectMT.__index = objectMT

objectMT.allowGestures = function(self, ...)
    local r = table.pack(...)
    if r.n ~= 0 then
        self:allowMagnificationGestures(...)
        self:allowNavigationGestures(...)
        return self
    end
    return self:allowMagnificationGestures() and self:allowNavigationGestures()
end

return module
