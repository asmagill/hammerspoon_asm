--- === hs._asm.phillipshue ===
---
--- Manage Phillips Hue Hubs on your local network.

-- TODO:
--   Additional methods for common actions (light on/off, search by name, groups, etc.)
--   Default connection re-try if failure when network changes, on timer?
--   Document
--   Move to spoon?

local USERDATA_TAG = "hs._asm.phillipshue"
-- local module       = require(USERDATA_TAG..".internal")
local module = {}

local basePath = package.searchpath(USERDATA_TAG, package.path)
if basePath then
    basePath = basePath:match("^(.+)/init.lua$")
    if require"hs.fs".attributes(basePath .. "/docs.json") then
        require"hs.doc".registerJSONFile(basePath .. "/docs.json")
    end
end

local inspect  = require("hs.inspect")
local settings = require("hs.settings")
local timer    = require("hs.timer")
local http     = require("hs.http")
local json     = require("hs.json")
local udp      = require("hs.socket").udp

local log      = require("hs.logger").new(USERDATA_TAG, "debug")

-- private variables and methods -----------------------------------------

local ssdpQuery = function(queryTime)
    queryTime = queryTime or 3
    return [[
M-SEARCH * HTTP/1.1
HOST: 239.255.255.250:1900
MAN: "ssdp:discover"
MX: ]] .. tostring(queryTime) .. "\n" .. [[
ST: "ssdp:all"
USER-AGENT: Hammerspoon/]] .. hs.processInfo.version .. [[ UPnP/1.1 SSDPDiscover/0.0
]]
end

local internals = setmetatable({}, { __mode = "k" })
local objectMT = {}
objectMT.__index    = objectMT
objectMT.__tostring = function(_) return USERDATA_TAG .. ": " .. internals[_].bridge end

local query = function(method, _, queryString, body)
    local self = internals[_] or _
    queryString = tostring(queryString)
    if #queryString > 1 and queryString:sub(1,1) ~= "/" then queryString = "/" .. queryString end
    body = body and json.encode(body) or nil
    local url  = self.info.url .. "api/" .. self.user .. queryString
    local qR, qB, qH = http.doRequest(url, method, body)
    if qR ~= 200 then
        log.ef("request error for %s %s: %d, %s, %s", method, queryString, qR, qB, (inspect(qH):gsub("%s+", " ")))
        return nil
    else
        local result = json.decode(qB)
        if #result > 0 and result[1].error then
            log.d((inspect(result):gsub("%s+", " ")))
        end
        return setmetatable(result, { __tostring = inspect })
    end
end

objectMT.get    = function(_, queryString)       return query("GET",    _, queryString, nil)  end
objectMT.delete = function(_, queryString)       return query("DELETE", _, queryString, nil)  end
objectMT.put    = function(_, queryString, body) return query("PUT",    _, queryString, body) end
objectMT.post   = function(_, queryString, body) return query("POST",   _, queryString, body) end

objectMT.makeDefault = function(_, force)
    force = force and true or false
    local self = internals[_]
    return module.setDefault(self.bridge, self.user, force)
end

-- Public interface ------------------------------------------------------

-- module._internals = internals -- for debugging, remember to remove

module.log = log

module.discovered = setmetatable({}, {
    __index = function(self, key) end,
    __newindex = function(self, key, value) end,
    __tostring = function(self)
        local result = ""
        for k, v in pairs(self) do
            result = result .. k .. "\t" .. (inspect(v):gsub("%s+", " ")) .. "\n"
        end
        return result
    end,
})

module.beginDiscovery = function(queryTime, doAfter)
    if type(queryTime) == "function" and type(doAfter) == "nil" then queryTime, doAfter = nil, queryTime end
    queryTime = queryTime or 3
    doAfter = doAfter or function() end
    local server = udp.server(1900, function(data, addr)
        local hueid = data:match("hue%-bridgeid: ([^\r\n]+)")
        if hueid then
            local qR, qB, qH = http.get(data:match("LOCATION: ([^\r\n]+)"))
            if qR == 200 then
                rawset(module.discovered, hueid, {
                    name = qB:match("<friendlyName>(.+)</friendlyName>"),
                    seen = os.time(),
                    url  = qB:match("<URLBase>(.+)</URLBase>"),
                })
            end
        end
    end):receive()
    server:send(ssdpQuery(queryTime), "239.255.255.250", 1900) -- multicast udp ssdp m-search
    local clearQueryTimer
    clearQueryTimer = timer.doAfter(queryTime, function()
        server:close()
        server = nil
        clearQueryTimer:stop()
        clearQueryTimer = nil
        doAfter()
    end)
end

module.connect = function(bridgeID, userID)
    if module.discovered[bridgeID] == nil then
        log.ef("unrecognized bridge id %s", bridgeID)
        return nil
    end
    local object = setmetatable({}, objectMT)
    internals[object] = { bridge = bridgeID, user = userID, info = module.discovered[bridgeID] }
    local result = object:get("")
    if not result then return nil end
    if #result > 0 and result.error then
        log.e(result.error.description)
        return nil
    end
    return object
end

module.setDefault = function(bridgeID, userID, force)
    force = force and true or false
    if not force and settings.get(USERDATA_TAG .. ".defaultBridge") then
        log.w("will not erase existing default without force == true")
        return false
    elseif bridgeID == nil and userID == nil then
        settings.clear(USERDATA_TAG .. ".defaultBridge")
        return true
    elseif type(bridgeID) == "string" and type(userID) == "string" then
        settings.set(USERDATA_TAG .. ".defaultBridge", bridgeID .. "::" .. userID)
        return true
    else
        log.e("invalid bridge or user id provided to setDefault")
        return false
    end
end

module.createUser = function(bridgeID, userName)
    if module.discovered[bridgeID] == nil then
        log.ef("unrecognized bridge id %s", bridgeID)
        return nil
    end
    userName = tostring(userName)
    return query("POST", { info = module.discovered[bridgeID], user = "" }, "", { devicetype = "hammerspoon#" .. userName })
end

local defaultBridge = settings.get(USERDATA_TAG .. ".defaultBridge")
if defaultBridge then
    module.beginDiscovery(function()
        local bridge, user = defaultBridge:match("^([^:]*)::([^:]*)$")
        if not bridge or not user then
            log.ef("invalid default bridge set: %s", defaultBridge)
        else
            module.default = module.connect(bridge, user)
        end
    end)
end

-- Return Module Object --------------------------------------------------

return module
