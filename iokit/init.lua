--- === hs._asm.iokit ===
---
--- This module provides tools for querying macOS and hardware with the IOKit library.

local USERDATA_TAG = "hs._asm.iokit"
local module       = require(USERDATA_TAG..".internal")
local objectMT     = hs.getObjectMetatable(USERDATA_TAG)

local basePath = package.searchpath(USERDATA_TAG, package.path)
if basePath then
    basePath = basePath:match("^(.+)/init.lua$")
    if require"hs.fs".attributes(basePath .. "/docs.json") then
        require"hs.doc".registerJSONFile(basePath .. "/docs.json")
    end
end

local fnutils = require("hs.fnutils")

-- local log = require("hs.logger").new(USERDATA_TAG, require"hs.settings".get(USERDATA_TAG .. ".logLevel") or "warning")

-- private variables and methods -----------------------------------------

--- hs._asm.iokit.planes[]
--- Constant
--- A table of strings naming the registry planes defined when the module is loaded.
local _planes = {}
for _, v in pairs(module.root():properties().IORegistryPlanes) do
    table.insert(_planes, v)
end
module.planes = ls.makeConstantsTable(_planes)

-- Public interface ------------------------------------------------------

module.serviceForRegistryID = function(id)
    local matchCriteria = module.dictionaryMatchingRegistryID(id)
    return matchCriteria and module.serviceMatching(matchCriteria) or nil
end

module.serviceForBSDName = function(name)
    local matchCriteria = module.dictionaryMatchingBSDName(name)
    return matchCriteria and module.serviceMatching(matchCriteria) or nil
end

module.serviceForName = function(name)
    local matchCriteria = module.dictionaryMatchingName(name)
    return matchCriteria and module.serviceMatching(matchCriteria) or nil
end

module.servicesForClass = function(class)
    local matchCriteria = module.dictionaryMatchingClass(class)
    return matchCriteria and module.servicesMatching(matchCriteria) or nil
end

module.servicesMatchingCriteria = function(value, plane)
    if type(value) ~= "table" then value = { name = tostring(value) } end
    plane = plane or "IOService"
    assert(fnutils.contains(module.planes, plane), string.format("plane must be one of %s", table.concat(module.planes, ", ")))

    local results = {}

    local svcs = { module.root() }

    while (#svcs ~= 0) do
        local svc = table.remove(svcs, 1)
        for _,v in ipairs(svc:childrenInPlane(plane)) do table.insert(svcs, v) end
        local matches = true
        for k, v in pairs(value) do
            if k == "name" then
                matches = svc:name():match(v) and true or false
            elseif k == "class" then
                matches = svc:class():match(v) and true or false
            elseif k == "bundleID" then
                matches = svc:bundleID():match(v) and true or false
            elseif k == "properties" then
                local props = svc:properties() or {}
                for k2, v2 in pairs(v) do
                    if type(v2) == "string" and type(props[k2]) == "string" then
                        matches = props[k2]:match(v2) and true or false
                    else
                        matches = (props[k2] == v2)
                    end
                    if not matches then break end
                end
            else
                matches = false
            end
            if not matches then break end
        end

        if matches then
            table.insert(results, svc)
        end
    end
    return results
end

objectMT.bundleID = function(self, ...)
    return module.bundleIDForClass(self:class(...))
end

objectMT.superclass = function(self, ...)
    return module.superclassForClass(self:class(...))
end

-- Return Module Object --------------------------------------------------

return module
