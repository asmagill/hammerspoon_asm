--- === hs._asm.bonjour ===
---
--- Stuff about the module

local USERDATA_TAG = "hs._asm.bonjour"
local module       = {}
module.browser     = require(USERDATA_TAG .. ".browser")
module.service     = require(USERDATA_TAG .. ".service")

local browserMT = hs.getObjectMetatable(USERDATA_TAG .. ".browser")
local serviceMT = hs.getObjectMetatable(USERDATA_TAG .. ".service")

local basePath = package.searchpath(USERDATA_TAG, package.path)
if basePath then
    basePath = basePath:match("^(.+)/init.lua$")
    if require"hs.fs".attributes(basePath .. "/docs.json") then
        require"hs.doc".registerJSONFile(basePath .. "/docs.json")
    end
end

-- local log = require("hs.logger").new(USERDATA_TAG, require"hs.settings".get(USERDATA_TAG .. ".logLevel") or "warning")

-- private variables and methods -----------------------------------------

-- currently, except for _services._dns-sd._udp., these should be limited to 2 parts, but
-- since one exception exists, let's be open to more in the future
local validateServiceFormat = function(service)
    -- first test: is it a string?
    local isValid = (type(service) == "string")

    -- does it end with _tcp or _udp (with an optional trailing period?)
    if isValid then
        isValid = (service:match("_udp%.?$") or service:match("_tcp%.?$")) and true or false
    end

    -- does each component separated by a period start with an underscore?
    if isValid then
        for part in service:gmatch("([^.]*)%.") do
            isValid = (part:sub(1,1) == "_") and (#part > 1)
            if not isValid then break end
        end
    end

    -- finally, make sure there are at least two parts to the service type
    if isValid then
        isValid = service:match("%g%.%g") and true or false
    end

    return isValid
end

-- Public interface ------------------------------------------------------

browserMT._browserFindServices = browserMT.findServices
browserMT.findServices = function(self, ...)
    local args = table.pack(...)
    if args.n > 0 and type(args[1]) == "string" then
        if not validateServiceFormat(args[1]) then
            error("service type must be in the format of _service._protocol.", 2)
        end
    end
    return self:_browserFindServices(...)
end

module.service._new = module.service.new
module.service.new = function(...)
    local args = table.pack(...)
    if args.n > 1 and type(args[2]) == "string" then
        if not validateServiceFormat(args[2]) then
            error("service type must be in the format of _service._protocol.", 2)
        end
    end
    return module.service._new(...)
end

module.service._remote = module.service.remote
module.service.remote = function(...)
    local args = table.pack(...)
    if args.n > 1 and type(args[2]) == "string" then
        if not validateServiceFormat(args[2]) then
            error("service type must be in the format of _service._protocol.", 2)
        end
    end
    return module.service._remote(...)
end

-- Return Module Object --------------------------------------------------

return module
