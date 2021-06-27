--- === hs.roku ===
---
--- Stuff about the module

local USERDATA_TAG = "hs.roku"
-- local module       = require(USERDATA_TAG..".internal")
local module       = {}
local xml          = require(USERDATA_TAG .. ".qduXML")

local basePath = package.searchpath(USERDATA_TAG, package.path)
if basePath then
    basePath = basePath:match("^(.+)/init.lua$")
    if require"hs.fs".attributes(basePath .. "/docs.json") then
        require"hs.doc".registerJSONFile(basePath .. "/docs.json")
    end
end

local inspect  = require("hs.inspect")
local timer    = require("hs.timer")
local socket   = require("hs.socket")
local http     = require("hs.http")
local fnutils  = require("hs.fnutils")
local settings = require("hs.settings")
local utf8     = require("hs.utf8")
local image    = require("hs.image")
local logger   = require("hs.logger")

-- settings with periods in them can't be watched via KVO with hs.settings.watchKey, so
-- in general it's a good idea not to include periods
local SETTINGS_TAG = USERDATA_TAG:gsub("%.", "_")
local log          = logger.new(USERDATA_TAG, settings.get(SETTINGS_TAG .. "_logLevel") or "warning")

-- private variables and methods -----------------------------------------

local flattenInspect = {  newline = " ", indent = "" }

-- for timers, etc so they don't get collected
local __internals = {}

-- we want to validate at assignment and trigger updates when changed, so handle via module __index/__newindex
local __internalVariables = {}

local ssdpQuery = function(queryTime)
    queryTime = queryTime or __internalVariables.ssdpQueryTime
    return [[
M-SEARCH * HTTP/1.1
HOST: 239.255.255.250:1900
MAN: "ssdp:discover"
MX: ]] .. tostring(queryTime) .. "\n" .. [[
ST: "roku:ecp"
USER-AGENT: Hammerspoon/]] .. hs.processInfo.version .. [[ UPnP/1.1 SSDPDiscover/0.0
]]
end

-- discovered roku devices
local __devices = setmetatable({}, {
    __index = function(self, key) end,
    __newindex = function(self, key, value) end,
    __tostring = function(self)
        local result = ""
        for k, v in pairs(self) do
            result = result .. k .. "\t" .. inspect(v, { newline = " ", indent = "", depth = 1 }) .. "\n"
        end
        return result
    end,
})

local addDeviceHelper = function(host, port, s, b, h)
    if s == 200 then
        local data, msg = pcall(xml.parseXML, b)
        if not data then return nil, string.format("invalid xml data: %s", msg) end
        data = msg
        local serialNumber = data("serial-number")[1]:value()
        if not serialNumber then return nil, string.format("unable to determine serial number from %s", b) end

        if not __devices[serialNumber] then -- if it already exists, don't replace it
            rawset(__devices, serialNumber, {})
        end
        local entry = __devices[serialNumber]
        entry.host  = host
        entry.port  = port
        entry.alive = true

        entry.name  = xml.entityValue(data("user-device-name"), 1)     or
                      xml.entityValue(data("friendly-device-name"), 1) or
                      xml.entityValue(data("friendly-model-name"), 1)  or
                      xml.entityValue(data("default-device-name"), 1)  or
                      serialNumber

        entry.isTV = tostring(xml.entityValue(data("is-tv"), 1)):upper() == "TRUE"
        entry.supportsFindRemote = tostring(xml.entityValue(data("supports-find-remote"), 1)):upper() == "TRUE"
        entry.supportsHeadphones = tostring(xml.entityValue(data("supports-private-listening"), 1)):upper() == "TRUE"

        return serialNumber
    end
    return nil, string.format("Unable to reach Roku device at %s -- %d -- %s -- %s", host, s, b, inspect(h, flattenInspect))
end

local deviceMetatable = {
    name = function(self) return __devices[self[1]].name end,
    host = function(self) return __devices[self[1]].host end,
    port = function(self) return __devices[self[1]].port end,
    sn   = function(self) return self[1] end,
    url  = function(self, query)
        query = query or ""
        return "http://" .. self:host() .. ":" .. self:port() .. "/" .. query:match("^/?(.*)$")
    end,

--     devInfo = function(self, root)
--         local s, b, h = http.get(self:url(root and "/" or "/query/device-info"), {})
--         if s == 200 then
--             return xml.parseXML(b)
--         else
--             log.ef("http query error --  %d -- %s -- %s", s, b, inspect(h, flattenInspect))
--             return xml.parseXML([[<error status="]] .. tostring(s) .. [[">]] .. b .. [[</error>]])
--         end
--     end,

    devInfo = function(self, root)
        local s, b, h = http.get(self:url(root and "/" or "/query/device-info"), {})
        if s == 200 then
            local state, bXML = pcall(xml.parseXML, b)
            if state then
                return setmetatable(bXML:asTable()[root and "root" or "device-info"], { __tostring = inspect })
            else
                return nil, bXML
            end
        else
            return nil, string.format("http query error --  %d -- %s -- %s", s, b, inspect(h, flattenInspect))
        end
    end,

    headphonesConnected = function(self)
        local info, msg = self:devInfo()
        if info then
            return info["headphones-connected"]:upper() == "TRUE"
        else
            return nil, msg
        end
    end,

    powerIsOn = function(self)
        local info, msg = self:devInfo()
        if info then
            return info["power-mode"] == "PowerOn"
        else
            return nil, msg
        end
    end,

    isTV = function(self) return __devices[self[1]].isTV end,
    supportsFindRemote = function(self) return __devices[self[1]].supportsFindRemote end,
    supportsHeadphones = function(self) return __devices[self[1]].supportsHeadphones end,


    remoteButtons = function(self)
        local buttonArray = {
            "Home",
            "Rev",
            "Fwd",
            "Play",
            "Select",
            "Left",
            "Right",
            "Down",
            "Up",
            "Back",
            "InstantReplay",
            "Info",
            "Backspace",
            "Search",
            "Enter",
            "A",
            "B",
        }

        if self:supportsFindRemote() then
            table.insert(buttonArray, "FindRemote")
        end

        if self:isTV() then
            table.insert(buttonArray, "ChannelUp")
            table.insert(buttonArray, "ChannelDown")
            table.insert(buttonArray, "VolumeDown")
            table.insert(buttonArray, "VolumeMute")
            table.insert(buttonArray, "VolumeUp")
            table.insert(buttonArray, "InputTuner")
            table.insert(buttonArray, "InputHDMI1")
            table.insert(buttonArray, "InputHDMI2")
            table.insert(buttonArray, "InputHDMI3")
            table.insert(buttonArray, "InputHDMI4")
            table.insert(buttonArray, "InputAV1")

-- ECP docs only mention "PowerOff", but a little googling found forum posts mentioning "PowerOn"
-- and "Power", so, maybe new additions? At any rate, it works for the one TV I have sporadic access to
            table.insert(buttonArray, "PowerOff")
            table.insert(buttonArray, "PowerOn")
            table.insert(buttonArray, "Power")
        end
        if self:supportsHeadphones() then
            if not fnutils.contains(buttonArray, "VolumeDown") then
                table.insert(buttonArray, "VolumeDown")
            end
            if not fnutils.contains(buttonArray, "VolumeUp") then
                table.insert(buttonArray, "VolumeUp")
            end
        end

        return setmetatable(buttonArray, {
            __tostring = function(self)
                local results = ""
                for _,v in ipairs(buttonArray) do
                    results = results .. v .. "\n"
                end
                return results
            end
        })
    end,

    remote = function(self, button, state, skipCheck)
        local action = (type(state) == "nil" and "keypress") or (state and "keydown" or "keyup")

        button = tostring(button)

        local availableButtons = self:remoteButtons()

        if not skipCheck then
            button = button:upper()
            local idx = 0
            for i,v in ipairs(availableButtons) do
                if v:upper() == button then
                    idx = i
                    break
                end
            end

            if idx > 0 then
                button = availableButtons[idx]
            else
                error("invalid button specified: " .. button .. " not recognized")
            end
        end

        http.asyncPost(
            "http://" .. self:host() .. ":" .. self:port() .. "/" .. action .. "/" .. tostring(button),
            "",
            {},
            function(s, b, h)
                if s ~= 200 and s ~= 202 then -- 202 indicates it has been accepted but not processed yet
                    -- skip it if it's volume related and the headphones aren't attached
                    if not (button:match("^Volume") and not self:headphonesConnected()) then
                        log.ef("remote button error: %d -- %s -- %s", s, b, inspect(h, flattenInspect))
                    end
                end
            end)
        return self
    end,

    type = function(self, what)
        if type(what) ~= "nil" then
            what = utf8.fixUTF8(tostring(what))
            for c in what:gmatch(utf8.charpattern) do
                local literal = ""
                for _, v in ipairs({ string.byte(c, 1, #c) }) do
                    literal = literal .. string.format("%%%02X", v)
                end
                self:remote("Lit_" .. literal, nil, true)
            end
        end
        return self
    end,

    availableApps = function(self, withImages)
        local results = {}
        local s, b, h = http.get(self:url("/query/apps"), {})
        if s == 200 then
            for _, v in ipairs(xml.parseXML(b)("app")) do
                local id = v.id
                local thisApp = { v:value(), {} }
                for k, v2 in pairs(v) do
                    thisApp[2][k] = v2
                end
                if withImages then
                    thisApp[2]["image"] = image.imageFromURL(self:url("/query/icon/") .. tostring(id))
                end
                table.insert(results, thisApp)
            end
            table.sort(results, function(a, b) return a[1]:upper() < b[1]:upper() end)
        else
            log.ef("availableApps error: %d -- %s -- %s", s, b, inspect(h, flattenInspect))
        end
        return setmetatable(results, {
            __tostring = function(self)
                local results = ""
                local col = 0
                for _, v in ipairs(self) do col = math.max(col, #v[1]) end
                for _, v in ipairs(self) do
                    results = results .. string.format("%-" .. tostring(col) .. "s (%s)\n", v[1], v[2].id)
                end
                return results
            end,
        })
    end,

    deviceImage = function(self)
        local info, msg = self:devInfo(true)
        if info then
            -- build in a way that doesn't break if somethings missing
            local imgURL = info["device"]
            imgURL = imgURL and imgURL["iconList"]
            imgURL = imgURL and imgURL["icon"]
            imgURL = imgURL and imgURL["url"]
            if imgURL then
                return image.imageFromURL(self:url("/" .. imgURL))
            else
                return nil, "no image url provided by device"
            end
        else
            return nil, msg
        end
    end,

    currentApp = function(self)
        local result
        local s, b, h = http.get(self:url("/query/active-app"), {})
        if s == 200 then
            result = xml.parseXML(b)("app")[1]:value()
        else
            log.ef("currentApp error: %d -- %s -- %s", s, b, inspect(h, flattenInspect))
        end
        return result
    end,

    currentAppID = function(self)
        local result
        local s, b, h = http.get(self:url("/query/active-app"), {})
        if s == 200 then
            result = xml.parseXML(b)("app")[1].id
        else
            log.ef("currentApp error: %d -- %s -- %s", s, b, inspect(h, flattenInspect))
        end
        return result
    end,

    currentAppIcon = function(self)
        local result
        local s, b, h = http.get(self:url("/query/active-app"), {})
        if s == 200 then
            local id = xml.parseXML(b)("app")[1].id
            if id then
                result = image.imageFromURL(self:url("/query/icon/") .. id)
            end
        else
            log.ef("currentAppIcon error: %d -- %s -- %s", s, b, inspect(h, flattenInspect))
        end
        return result
    end,

    launch = function(self, id, allowInstall)
        local apps = self:availableApps()
        local isLaunch = false
        id = tostring(id)
        for _,v in ipairs(apps) do
            if id == v[1] or id == v[2].id then
                id = v[2].id
                isLaunch = true
                break
            end
        end
        if isLaunch then
            http.asyncPost(
                "http://" .. self:host() .. ":" .. self:port() .. "/launch/" .. id,
                "",
                {},
                function(s, b, h)
                    if s ~= 200 and s ~= 202 then -- 202 indicates it has been accepted but not processed yet
                        log.ef("launch error: %d -- %s -- %s", s, b, inspect(h, flattenInspect))
                    end
                end
            )
        elseif allowInstall then
            http.asyncPost(
                "http://" .. self:host() .. ":" .. self:port() .. "/install/" .. id,
                "",
                {},
                function(s, b, h)
                    if s ~= 200 and s ~= 202 then -- 202 indicates it has been accepted but not processed yet
                        log.ef("install error: %d -- %s -- %s", s, b, inspect(h, flattenInspect))
                    end
                end
            )
        else
            log.wf("id %s not recognized for launch and allowInstall flag not set", id)
        end
        return self
    end,

    __name = USERDATA_TAG,
    __tostring = function(self) return USERDATA_TAG .. ": " .. self:sn() end,
    __eq = function(a, b) return a.__name == USERDATA_TAG and b.__name == USERDATA_TAG and a:sn() == b:sn() end,
}
deviceMetatable.__index = deviceMetatable

-- Public interface ------------------------------------------------------

--- hs.roku.ssdpQueryTime
--- Variable
--- Specifies the number of seconds, default 5, the SSDP query for Roku devices on the local network remains active. Must be an integer > 0.
---
--- This is the number of seconds the SSDP query will remain active when [hs.roku.startDiscovery](#startDiscovery) is invoked or when rediscovery occurs (see [hs.roku.rediscoveryInterval](#rediscoveryInterval)).
---
--- Changing this variable will not trigger a rediscovery, but the new value will be used the next time rediscovery occurs.
__internalVariables.ssdpQueryTime = 10

--- hs.roku.rediscoveryInterval
--- Variable
--- Specifies the number of seconds, default 3600 (1 hour), between automatic discovery checks to determine if new Roku devices have been added to the network or removed from it. Must be an integer > [hs.roku.ssdpQueryTime](#ssdpQueryTime).
---
--- Automatic discovery checks are enabled when [hs.roku.startDiscovery](#startDiscovery) is invoked. Changing this value after `startDiscovery` has been invoked will cause an immediate discovery process and future discovery process will occur as specified by the new interval.
__internalVariables.rediscoveryInterval = 3600


module.startDiscovery = function()
    if not __internals.rediscoveryCheck then
        local rediscoveryFunction
        rediscoveryFunction = function()
            if not __internals.ssdpDiscovery then
                __internals.seenDevices = {}
                __internals.ssdpDiscovery = socket.udp.server(1900, function(data, addr)
                    local status, headerTxt = data:match("^(HTTP/[%d%.]+ 200 OK)[\r\n]+(.*)$")
                    if status then
                        local headers = {}
                        for _,v in pairs(fnutils.split(headerTxt, "[\r\n]+")) do
                            if v ~= "" then
                                local key, value = v:match("^([^:]+): ?(.*)$")
            --                     print("'" .. v .. "'", "'" .. tostring(key) .. "'", "'" .. tostring(value) .. "'")
                                key = key:upper() -- spec says key should be case insensitive
                                headers[key] = value
                            end
                        end
                        if headers["USN"] and headers["USN"]:match("^uuid:roku:ecp:") then
                            local serial = headers["USN"]:match("^uuid:roku:ecp:(.*)$")
                            local host, port = headers["LOCATION"]:match("^http://([%d%.]+):(%d+)/$")
                            -- if a udp response is queued but clearQueryTimer callback is queued first
                            -- seenDevices may disappear... its ok to add the Device and skip seenDevices
                            -- since it's for clearing out things we *no longer* see..
                            if __internals.seenDevices then
                                table.insert(__internals.seenDevices, serial)
                            end

                            -- add device to discovered list
                            local url = "http://" .. host .. ":" .. tostring(port) .. "/query/device-info"
                            http.asyncGet(url, {}, function(s, b, h)
                                local sn, msg = addDeviceHelper(host, port, s, b, h)
                                if sn then
                                    __devices[sn].ssdpDiscovery = headers
                                else
                                    log.ef(msg)
                                end
                            end)
                        end
                    end
                end):receive()

                __internals.ssdpDiscovery:send(ssdpQuery(), "239.255.255.250", 1900) -- multicast udp ssdp m-search
                __internals.clearQueryTimer = timer.doAfter(__internalVariables.ssdpQueryTime, function()
                    if __internals.clearQueryTimer then
                        __internals.clearQueryTimer:stop()
                        __internals.clearQueryTimer = nil
                    end
                    if __internals.ssdpDiscovery then
                        __internals.ssdpDiscovery:close()
                        __internals.ssdpDiscovery = nil

                        -- purge devices that have disappeared from the network
                        if __internals.seenDevices then
                            for k,v in pairs(__devices) do
                                if not fnutils.contains(__internals.seenDevices, k) then
                                    v.alive = false
--                                     rawset(__devices, k, nil)
                                end
                            end
                            __internals.seenDevices = nil
                        end
                    end
                end)
            end

            -- probably overkill, but lets be explicit
            if __internals.rediscoveryCheck then
                __internals.rediscoveryCheck:stop()
                __internals.rediscoveryCheck = nil
            end
            __internals.rediscoveryCheck = timer.doAfter(__internalVariables.rediscoveryInterval, rediscoveryFunction)
        end

        rediscoveryFunction()
    end
end

module.triggerRediscovery = function()
    if __internals.rediscoveryCheck then
        __internals.rediscoveryCheck:fire()
        return true
    else
        return false
    end
end

module.stopDiscovery = function()
    if __internals.rediscoveryCheck then
        __internals.rediscoveryCheck:stop()
        __internals.rediscoveryCheck = nil
    end
    if __internals.clearQueryTimer then
        __internals.clearQueryTimer:stop()
        __internals.clearQueryTimer = nil
    end
    if __internals.ssdpDiscovery then
        __internals.ssdpDiscovery:close()
        __internals.ssdpDiscovery = nil
        __internals.seenDevices = nil
    end
end

module.discoveredDevices = function()
    local results = {}
    for k, v in pairs(__devices) do
        if v.alive then results[k] = module.device(k) end
    end

    return setmetatable(results, {
        __tostring = function(self)
            local items = {}
            for k,v in pairs(self) do
                local item = __devices[k]
                table.insert(items, { item.name, k, item.host .. ":" .. tostring(item.port) })
            end
            table.sort(items, function(a, b) return a[1] < b[1] end)
            local col1, col2, col3 = 0, 0, 0
            for _, v in ipairs(items) do
                col1 = math.max(col1, #v[1])
                col2 = math.max(col2, #v[2])
                col3 = math.max(col2, #v[3])
            end
            local result = ""
            for _, v in ipairs(items) do
                result = result .. string.format("%-" .. tostring(col1) .. "s (%" ..tostring(col2) .. "s) @ %" .. tostring(col3) .. "s\n", v[1], v[2], v[3])
            end
            return result
        end
    })
end

module.device = function(id)
    local deviceSN, devObject
    for k, v in pairs(__devices) do
        if id == k or id == v.name or id == v.host or id == (v.host .. ":" .. tostring(v.port)) then
            deviceSN = k
            break
        end
    end

    if deviceSN then devObject = setmetatable({ deviceSN }, deviceMetatable) end

    return devObject
end

module.addDevice = function(host, port)
    port = tonumber(port) or 8060
    local url = "http://" .. host .. ":" .. tostring(port) .. "/query/device-info"
    local s, b, h = http.get(url, {})
    local sn, msg = addDeviceHelper(host, port, s, b, h)
    if sn then
        return module.device(sn)
    else
        return nil, msg
    end
end

-- Return Module Object --------------------------------------------------

return setmetatable(module, {
    __index = function(self, key)
        return __internalVariables[key]
    end,
    __newindex = function(self, key, value)
        local errMsg = nil
        if key == "ssdpQueryTime" then
            if type(value) == "number" and math.type(value) == "integer" and value > 0 then
                __internalVariables[key] = value
            else
                errMsg = USERDATA_TAG .. ".ssdpQueryTime must be an integer > 0"
            end
        elseif key == "rediscoveryInterval" then
            if type(value) == "number" and math.type(value) == "integer" and value > __internalVariables["ssdpQueryTime"] then
                __internalVariables[key] = value
                if __internals.rediscoveryCheck then
                    __internals.rediscoveryCheck:fire()
                end
            else
                errMsg = USERDATA_TAG .. ".rediscoveryInterval must be an integer > " .. USERDATA_TAG .. ".ssdpQueryTime"
            end

        else
            errMsg = tostring(key) .. " is not a recognized paramter of " .. USERDATA_TAG
        end

        if errMsg then error(errMsg, 2) end
    end,
    __gc = module.stopDiscovery,

    -- for debugging purposes; users should never need to see these directly
    __internals         = __internals,
    __internalVariables = __internalVariables,
    __devices           = __devices,
    xml                 = xml,
})

