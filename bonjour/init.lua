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

local collectionPrevention = {}
local task    = require("hs.task")
local host    = require("hs.host")
local fnutils = require("hs.fnutils")
local timer   = require("hs.timer")

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

module.networkServices = function(callback, timeout)
    assert(type(callback) == "function" or (getmetatable(callback) or {})._call, "function expected for argument 1")
    if (timeout) then assert(type(timeout) == "number", "number expected for optional argument 2") end
    timeout = timeout or 5

    local uuid = host.uuid()
    local job = module.browser.new()
    collectionPrevention[uuid] = { job = job, results = {} }
    job:findServices("_services._dns-sd._udp.", "local", function(b, msg, state, obj, more)
        local internals = collectionPrevention[uuid]
        if msg == "service" and state then
            table.insert(internals.results, obj:name() .. "." .. obj:type():match("^(.+)local%.$"))
            if internals.timer then
                internals.timer:stop()
                internals.timer = nil
            end
            if not more then
                internals.timer = timer.doAfter(timeout, function()
                    internals.job:stop()
                    internals.job = nil
                    internals.timer = nil
                    collectionPrevention[uuid] = nil
                    callback(internals.results)
                end)
            end
        end
    end)
end

-- note: online says that this doesn't work for all devices, but does seem to work for Apple devices
-- and linux running avahi-daemon
module.machineServices = function(target, callback)
    assert(type(target) == "string", "string expected for argument 1")
    assert(type(callback) == "function" or (getmetatable(callback) or {})._call, "function expected for argument 2")

    local uuid = host.uuid()
    local job = task.new("/usr/bin/dig", function(r, o, e)
        local results
        if r == 0 then
            results = {}
            for i, v in ipairs(fnutils.split(o, "[\r\n]+")) do
                table.insert(results, v:match("^(.+)local%.$"))
            end
        else
            results = (e == "" and o or e):match("^[^ ]+ (.+)$"):gsub("[\r\n]", "")
        end
        collectionPrevention[uuid] = nil
        callback(results)
    end, { "+short", "_services._dns-sd._udp.local", "ptr", "@" .. target, "-p", "5353" })
    collectionPrevention[uuid] = job:start()
end

-- Return Module Object --------------------------------------------------

return module
