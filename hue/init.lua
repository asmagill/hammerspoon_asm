--- === hs._asm.hue ===
---
--- Manage Philips Hue Hubs on your local network.

-- TODO:
--   Additional methods for common actions (light on/off, search by name, groups, etc.)
-- * Default connection re-try if failure when network changes, on timer?
-- + Document
-- * Move to spoon? No. Or at least not this... maybe a wrapper for it.

local USERDATA_TAG = "hs._asm.hue"
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

local log      = require("hs.logger").new(USERDATA_TAG, settings.get(USERDATA_TAG .. ".logLevel") or "warning")

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

local checkAndConnectToDefault = function()
--- hs._asm.hue.default
--- Variable
--- The hueObject representing the default bridge connection set by [hs._asm.hue.setDefault](#setDefault).
---
--- If you have not set a default, or if the default is not available when this module is first loaded, this value will be nil. If you change the default with [hs._asm.hue.setDefault](#setDefault) then this value will be set to nil and a connection attempt to the new bridge will be attempted.  On success, this variable will then contain the hueObject for the new connection.
    module.default = nil
    local defaultBridge = settings.get(USERDATA_TAG .. ".defaultBridge")
    if defaultBridge then
        local defaultConnectFunction
        defaultConnectFunction = function()
            local bridge, user = defaultBridge:match("^([^:]*)::([^:]*)$")
            if not bridge or not user then
                log.ef("invalid default bridge set: %s", defaultBridge)
            else
                if module.discovered[bridge] then
                    module.default = module.connect(bridge, user)
                end
                if module.default then
                    log.f("Connected to bridge %s", bridge)
                else
                    log.df("Default bridge not available or an error occurred. Will retry in %s seconds.", module.defaultRetryTime)
                    local thumbTwiddle
                    thumbTwiddle = timer.doAfter(module.defaultRetryTime, function()
                        thumbTwiddle = nil
                        defaultBridge = settings.get(USERDATA_TAG .. ".defaultBridge")
                        if defaultBridge then
                            module.beginDiscovery(defaultConnectFunction)
                        else
                            log.i("default bridge removed; aborting retry.")
                        end
                    end)
                end
            end
        end
        module.beginDiscovery(defaultConnectFunction)
    end
end

local internals = setmetatable({}, { __mode = "k" })
local query = function(method, _, queryString, body)
    local self = internals[_] or _
    queryString = tostring(queryString)
    if #queryString > 1 and queryString:sub(1,1) ~= "/" then queryString = "/" .. queryString end
    body = body and ((type(body) == "string") and body or json.encode(body)) or nil
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

local discoveredMetatable = {
    __index = function(self, key) end,
    __newindex = function(self, key, value) end,
    __tostring = function(self)
        local result = ""
        for k, v in pairs(self) do
            result = result .. k .. "\t" .. (inspect(v):gsub("%s+", " ")) .. "\n"
        end
        return result
    end,
}

-- Public interface ------------------------------------------------------

local objectMT = {}
objectMT.__index    = objectMT
objectMT.__tostring = function(_) return USERDATA_TAG .. ": " .. internals[_].bridge end

objectMT.paths = function(_, section, criteria, pattern)
    local self = internals[_]
    local result = _:get(section)
    if #result > 0 and result[1].error then return nil end
    local answers = {}

    local kvInItem
    kvInItem = function(target, key, value, pattern)
        local check = target[key]
        if type(value) == "table" then
            for k, v in ipairs(value) do
                if tostring(check):match((pattern and "" or "^") .. tostring(v) .. (pattern and "" or "$")) then return true end
            end
        else
            if tostring(check):match((pattern and "" or "^") .. tostring(value) .. (pattern and "" or "$")) then return true end
        end
        if target[key] == value then return true end
        for k, v in pairs(target) do
            if type(v) == "table" then
                if kvInItem(v, key, value, pattern) then return true end
            end
        end
        return false
    end

    for k,v in pairs(result) do
        local foundOne = true
        for k2, v2 in pairs(criteria) do
            if not kvInItem(v, k2, v2, pattern) then
                foundOne = false
                break
            end
        end
        if foundOne then table.insert(answers, section .. "/" .. k) end
    end
    return setmetatable(answers, { __tostring = inspect })
end

--- hs._asm.hue:get(queryString) -> table
--- Method
--- Sends a GET query to the Hue bridge using its REST API.
---
--- Parameters:
---  * queryString - a string specifying the query for the Hue bridge.
---
--- Returns:
---  * a table of the decoded json data returned by the Hue bridge in response to this query
---
--- Notes:
---  * The table returned uses `hs.inspect` as it's __tostring metamethod; this means that you can issue the command in the Hammerspoon console and see the results without having to capture the return value and viewing it with `hs.inspect` yourself.
objectMT.get    = function(_, queryString)       return query("GET",    _, queryString, nil)  end

--- hs._asm.hue:delete(queryString) -> table
--- Method
--- Sends a DELETE query to the Hue bridge using its REST API.
---
--- Parameters:
---  * queryString - a string specifying the query for the Hue bridge.
---
--- Returns:
---  * a table of the decoded json data returned by the Hue bridge in response to this query
---
--- Notes:
---  * The table returned uses `hs.inspect` as it's __tostring metamethod; this means that you can issue the command in the Hammerspoon console and see the results without having to capture the return value and viewing it with `hs.inspect` yourself.
objectMT.delete = function(_, queryString)       return query("DELETE", _, queryString, nil)  end

--- hs._asm.hue:put(queryString, body) -> table
--- Method
--- Sends a PUT query to the Hue bridge using its REST API.
---
--- Parameters:
---  * queryString - a string specifying the query for the Hue bridge.
---  * body        - the data for the query.  This should be a string specifying json encoded data, a table which will be converted to json encoded data, or nil
---
--- Returns:
---  * a table of the decoded json data returned by the Hue bridge in response to this query
---
--- Notes:
---  * The table returned uses `hs.inspect` as it's __tostring metamethod; this means that you can issue the command in the Hammerspoon console and see the results without having to capture the return value and viewing it with `hs.inspect` yourself.
objectMT.put    = function(_, queryString, body) return query("PUT",    _, queryString, body) end

--- hs._asm.hue:post(queryString, body) -> table
--- Method
--- Sends a POST query to the Hue bridge using its REST API.
---
--- Parameters:
---  * queryString - a string specifying the query for the Hue bridge.
---  * body        - the data for the query.  This should be a string specifying json encoded data, a table which will be converted to json encoded data, or nil
---
--- Returns:
---  * a table of the decoded json data returned by the Hue bridge in response to this query
---
--- Notes:
---  * The table returned uses `hs.inspect` as it's __tostring metamethod; this means that you can issue the command in the Hammerspoon console and see the results without having to capture the return value and viewing it with `hs.inspect` yourself.
objectMT.post   = function(_, queryString, body) return query("POST",   _, queryString, body) end

--- hs._asm.hue:makeDefault([force]) -> boolean
--- Method
--- Set this current connection as the module's default connection to be attempted on module load.
---
--- Parameters:
---  * force - an optional boolean, default false, specifying whether or not this connection should overwrite any existing default connection.
---
--- Returns:
---  * true if the change was successful or false if it was not
---
--- Notes:
---  * This is a wrapper for [hs._asm.hue.setDefault](#setDefault) providing the bridgeID and userID from this connection.  It's return value and behavior are described in the documentation for `setDefault`.
objectMT.makeDefault = function(_, force)
    force = force and true or false
    local self = internals[_]
    return module.setDefault(self.bridge, self.user, force)
end

-- module._internals = internals -- for debugging, remember to remove

--- hs._asm.hue.log
--- Variable
--- hs.logger object used within this module.
module.log = log

--- hs._asm.hue.defaultRetryTime
--- Variable
--- The retry interval when a default is set with [hs._asm.hue.setDefault](#setDefault) but the specified bridge was not discovered.  Defaults to 60 seconds.
---
--- To effect a persistent change to this value, set your desired timeout with `hs.settings.set("hs._asm.hue.defaultRetryTime", value)`.
module.defaultRetryTime = settings.get(USERDATA_TAG .. ".defaultRetryTime") or 60

--- hs._asm.hue.discovered
--- Constant
--- A table containing key-value pairs for the Philips Hue bridges discovered on the current network by this module.
---
--- This table is initially empty until [hs._asm.hue.beginDiscovery](#beginDiscovery) has been executed.  If you have a default defined with [hs._asm.hue.setDefault](#setDefault), then this process will occur automatically when the module is loaded.
---
--- The keys represent the bridge ID's of Hue bridges discovered and the value will be a table containing the name of the bridge, the time it last responded to a discovery query, and the root URL to use for queries.  A __tostring metatable method has been added so you can view the table in the console by just referencing this variable.
module.discovered = setmetatable({}, discoveredMetatable)

--- hs._asm.hue.beginDiscovery([queryTime], [callback]) -> none
--- Function
--- Perform an SSDP M-SEARCH query to discover Philips Hue bridges on the current network.
---
--- Parameters:
---  * queryTime - the number of seconds, default 3.0, to query for bridges on the local network.
---  * callback   - an optional function to execute after the query has completed.  Defaults to an empty function.
---
--- Returns:
---  * None
---
--- Notes:
---  * This function will clear current entries in [hs._asm.hue.discovered](#discovered) before performing the query and then populate it with bridges discovered on the current local networks.
module.beginDiscovery = function(queryTime, doAfter)
    if type(queryTime) == "function" and type(doAfter) == "nil" then queryTime, doAfter = nil, queryTime end
    queryTime = queryTime or 3
    doAfter = doAfter or function() end
    module.discovered = setmetatable({}, discoveredMetatable)
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

--- hs._asm.hue.connect(bridgeID, userID) -> hueObject
--- Constructor
--- Connect to the specified Hue bridge with the specified user hash.
---
--- Parameters:
---  * bridgeID - a string specifying the bridge id of the bridge to connect to. See [hs._asm.hue.discovered](#discovered).
---  * userID   - a string specifying the user hash as provided by [hs._asm.hue.createUser](#createUser).
---
--- Returns:
---  * the hueObject if the bridge is available or nil if it is not
---
--- Notes:
---  * if you have set a default with [hs._asm.hue.setDefault](#setDefault) then a connection will be attempted automatically when this module is loaded. See [hs._asm.hue.default](#default).
module.connect = function(bridgeID, userID)
    if module.discovered[bridgeID] == nil then
        log.ef("unrecognized bridge id %s", bridgeID)
        return nil
    end
    local object = setmetatable({}, objectMT)
    internals[object] = { bridge = bridgeID, user = userID, info = module.discovered[bridgeID] }
    local result = object:get("")
    if not result then return nil end
    if #result > 0 and result[1].error then
        log.e(result[1].error.description)
        return nil
    end
    return object
end

--- hs._asm.hue.setDefault(bridgeID, userID, [force]) -> boolean
--- Function
--- Set or clear the default bridge and user used for automatic connection when this module loads.
---
--- Parameters:
---  * bridgeID - a string (or explicit nil if you wish to remove the current default) specifying the bridge id of the bridge to connect to by default. See [hs._asm.hue.discovered](#discovered).
---  * userID   - a string (or explicit nil if you wish to remove the current default) specifying the user hash as provided by [hs._asm.hue.createUser](#createUser).
---  * force    - an optional boolean, default false, specifying if an existing default should be replaced by the new values.
---
--- Returns:
---  * true if the new settings have been saved or false if they were not.
---
--- Notes:
---  * If a default is set then this module will automatically discover available bridges when loaded and connect to the specified bridge if it is available. See [hs._asm.hue.default](#default).
---  * On a successful change, [hs._asm.hue.default](#default) will be reset to reflect the new defaults.
---
---  * See also [hs._asm.hue:makeDefault](#makeDefault).
module.setDefault = function(bridgeID, userID, force)
    force = force and true or false
    if not force and settings.get(USERDATA_TAG .. ".defaultBridge") then
        log.w("will not erase existing default without force == true")
        return false
    elseif bridgeID == nil and userID == nil then
        settings.clear(USERDATA_TAG .. ".defaultBridge")
        checkAndConnectToDefault()
        return true
    elseif type(bridgeID) == "string" and type(userID) == "string" then
        settings.set(USERDATA_TAG .. ".defaultBridge", bridgeID .. "::" .. userID)
        checkAndConnectToDefault()
        return true
    else
        log.e("invalid bridge or user id provided to setDefault")
        return false
    end
end

--- hs._asm.hue.createUser(bridgeID, userName) -> results
--- Function
--- Attempts to create a new user ID on the specified Philips Hue bridge
---
--- Parameters:
---  * bridgeID - a string specifying the id of the discovered bridge on which you wish to create a new user. See [hs._asm.hue.discovered](#discovered).
---  * userID   - a string specifying a human readable name for the new user identification string
---
--- Returns:
---  * a table containing the results of the request.
---    * If the link button on your Philips Hue bridge has not been pressed, the table will contain the following:
---  ~~~
--- { {
---     error = {
---       address = "/",
---       description = "link button not pressed",
---       type = 101
---     }
---   } }
--- ~~~
---    * If you have pressed the link button and issue this function within 30 seconds, the table will contain the following:
---  ~~~
--- { {
---     success = {
---       username = "string-contaning-letters-and-numbers"
---     }
---   } }
--- ~~~
---    * Note the value of `username` as you will need it for [hs._asm.hue.connect](#connect)
---
--- Notes:
---  * The Philips Hue bridge does not support usernames directly; instead, you must specify an application name and a device or user for that application which are used to construct a unique hashed value in your bridge which is added to its whitelist. Internally this function prepends "hammerspoon" as the application name, so you only provide the user portion. The returned hash is how you authenticate yourself for future communication with the bridge.
---
---  * The table returned uses `hs.inspect` as it's __tostring metamethod; this means that you can issue the command in the Hammerspoon console and see the results without having to capture the return value and viewing it with `hs.inspect` yourself.
module.createUser = function(bridgeID, userName)
    if module.discovered[bridgeID] == nil then
        log.ef("unrecognized bridge id %s", bridgeID)
        return nil
    end
    userName = tostring(userName)
    return query("POST", { info = module.discovered[bridgeID], user = "" }, "", { devicetype = "hammerspoon#" .. userName })
end

--- hs._asm.hue.hueColor(color) -> table
--- Function
--- Returns a table containing the hue, sat, and bri properties recognizable by the Philips Hue bridge representing the color specified.
---
--- Parameters:
---  * color - a table specifying a color as defined by the `hs.drawing.color` module
---
--- Returns:
---  * a table containing the `hue`, `sat`, and `bri` key-value pairs recognizable by the Philips Hue bridge representing the color specified. If no conversion is possible, returns an empty table, which if provided to the bridge, will result in no change.
module.hueColor = function(original)
    local color = require("hs.drawing.color")
    local hsb = color.asHSB(original)
    if type(hsb) == "table" then
        return {
            bri = math.floor(.5 + hsb.brightness * 254),
            sat = math.floor(.5 + hsb.saturation * 254),
            hue = math.floor(.5 + hsb.hue * 65535),
        }
    else
        return {}
    end
end

checkAndConnectToDefault()

-- Return Module Object --------------------------------------------------

return module
