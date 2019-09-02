--- === hs._asm.module ===
---
--- Stuff about the module

local USERDATA_TAG = "hs._asm.dnssd"
local module       = require(USERDATA_TAG..".internal")
local _lookups     = {
    _errorList = module._errorList
}

-- module._errorList = nil

for i,v in ipairs{ "browser" } do
    local submodule = require(USERDATA_TAG.."."..v)
    if submodule._registerHelpers then
        submodule._registerHelpers(_lookups)
        submodule._registerHelpers = nil -- no need to advertise private only function
    end
    module[v] = submodule
end

local basePath = package.searchpath(USERDATA_TAG, package.path)
if basePath then
    basePath = basePath:match("^(.+)/init.lua$")
    if require"hs.fs".attributes(basePath .. "/docs.json") then
        require"hs.doc".registerJSONFile(basePath .. "/docs.json")
    end
end

-- local log = require("hs.logger").new(USERDATA_TAG, require"hs.settings".get(USERDATA_TAG .. ".logLevel") or "warning")

-- private variables and methods -----------------------------------------

_lookups.if_indexToName = function(idx)
    local name = nil
    for k,v in pairs(module.interfaces(true)) do
        if v == idx then
            name = k
            break
        end
    end
    return name
end

_lookups.if_nameToIndex = function(name)
    local idx = nil
    for k,v in pairs(module.interfaces(true)) do
        if k:upper() == name:upper() then
            idx = v
            break
        end
    end
    return idx
end

-- Public interface ------------------------------------------------------

-- Return Module Object --------------------------------------------------

-- for debugging purposes, may be removed in the future
local mMeta = getmetatable(module)
if not mMeta then
    mMeta = {}
    setmetatable(module, mMeta)
end
mMeta._internal = {
    _lookups = _lookups
}
return module
