--- === hs._asm.kodi ===
---
--- Manage a Kodi server
---
--- This module requires "Allow remote control via HTTP" (System -> Settings -> Services -> Webserver) to be enabled for each Kodi instance you wish to control.

local USERDATA_TAG = "hs._asm.kodi"
local module       = {}
local kodiMT       = {}

local pingTime      = 120
local reconnectTime = 30

local instances = setmetatable({}, { __mode = "k" })
local mappings  = setmetatable({}, { __mode = "v" })

local http       = require("hs.http")
local alert      = require("hs.alert")
local json       = require("hs.json")
local host       = require("hs.host")
local hsutf8     = require("hs.utf8")
local logger     = require("hs.logger")
local inspect    = require("hs.inspect")
local settings   = require("hs.settings")
local timer      = require("hs.timer")
local fnutils    = require("hs.fnutils")
local caffeinate = require("hs.caffeinate")

-- local logLabel = (#USERDATA_TAG <= 10) and USERDATA_TAG
--                                        or hsutf8.codepointToUTF8(0x2026) .. USERDATA_TAG:sub(-7)
-- local log      = logger.new(logLabel, settings.get(USERDATA_TAG .. ".logLevel") or "warning")
local log = logger.new(USERDATA_TAG, settings.get(USERDATA_TAG .. ".logLevel") or "warning")

-- private variables and methods -----------------------------------------

local autoconnect = function()
    local doit = settings.get(USERDATA_TAG .. ".autoconnect")
    if (doit) then
        return module.new(settings.get(USERDATA_TAG .. ".server"))
    end
end

local cleanServerString = function(server, forDisplay)
    local adjustedServer = server
    local parts = http.urlParts(server)
    if parts.scheme then
        if (parts.user and parts.user ~="") or (parts.password and parts.password ~="") then
            local user = parts.user or ""
            local pass = parts.password or ""
            if forDisplay then
                pass = (pass and pass ~= "") and "••••••" or pass
            end
            adjustedServer = parts.scheme .. "://" .. user .. ":" .. pass .. "@" .. parts.host .. ":" .. parts.port
        else
            adjustedServer = parts.scheme .. "://" .. parts.host .. ":" .. parts.port
        end
    end
    return adjustedServer
end

local backgroundConnection
backgroundConnection = function(id)
    local self = mappings[id]
    if self then
        self:submit("JSONRPC.Introspect", { getmetadata = true }, function(status, body, headers)
            local self = mappings[id]
            if self then
                local selfInternals = instances[self]
                if status == 200 then
                    if selfInternals.reconnect then
                        selfInternals.reconnect:stop()
                        selfInternals.reconnect = nil
                    end
                    selfInternals.API = json.decode(body).result
                    if not selfInternals.pingPong then
                        log.df("%s online", cleanServerString(selfInternals.URL, true))
                        selfInternals.lastSeen = os.time()
                        selfInternals.pingPong = timer.doEvery(pingTime, function()
                            local self = mappings[id]
                            if self then
                                local selfInternals = instances[self]
                                self:submit("JSONRPC.Ping", nil, function(status, body, headers)
                                    local self = mappings[id]
                                    if self then
                                        local selfInternals = instances[self]
                                        if status ~= 200 then
                                            selfInternals.pingPong:stop()
                                            selfInternals.pingPong = nil
                                            log.df("%s offline", cleanServerString(selfInternals.URL, true))
                                            selfInternals.API = nil
                                            selfInternals.reconnect = timer.doEvery(reconnectTime, function()
                                                backgroundConnection(id)
                                            end)
                                        else
                                            local dt = os.time()
                                            selfInternals.lastSeen = dt
                                            selfInternals.ping = json.decode(body).result
                                            if selfInternals.debug then
                                              log.vf("%s ping -> %s", cleanServerString(selfInternals.URL, true), json.decode(body).result)
                                            end
                                        end
                                    else
                                        log.d("ping callback no self")
                                    end
                                end)
                            else
                                log.d("pingPong timer no self")
                            end
                        end)
                    end
                else
                    if not selfInternals.reconnect then
                        log.df("%s offline", cleanServerString(selfInternals.URL, true))
                        selfInternals.API = nil
                        selfInternals.reconnect = timer.doEvery(reconnectTime, function()
                            backgroundConnection(id)
                        end)
                    end
                end
            else
                log.d("introspect callback no self")
            end
        end)
    else
        log.d("backgroundConnection no self")
    end
end

local getAPIifConnected = function(self, withAlert)
    local API = instances[self].API
    if not API then
        if withAlert then
            alert.show("default KODI instance not connected")
        else
            log.w("KODI instance not connected")
        end
    end
    return API
end

local sleepWatcher = caffeinate.watcher.new(function(state)
    if state == caffeinate.watcher.systemDidWake then
        for i, v in pairs(instances) do
            log.df("%s waking up", cleanServerString(v.URL, true))
            backgroundConnection(v.id)
        end
    elseif state == caffeinate.watcher.systemWillSleep then
        for i, v in pairs(instances) do
            log.df("%s going to sleep", cleanServerString(v.URL, true))
            v.API = nil
            if v.reconnect then
                v.reconnect:stop()
                v.reconnect = nil
            end
            if v.pingPong then
                v.pingPong:stop()
                v.pingPong = nil
            end
        end
    end
end):start()

-- Public interface ------------------------------------------------------

--     if server:match("@") then
--         local cred, host = server:match("^([^@]+)@([^@]+)$")
--         if not cred or not host then
--             error("invalid server format: must be server.name or [user]:[pass]@server.name", 2)
--         end
--         server = host
--         local user, pass = cred:match("^([^:]*):(.*)$")
--         if not user or not pass then
--             error("invalid server format: must be server.name or [user]:[pass]@server.name", 2)
--         end
--         kodiUser = user
--         kodiPass = pass
--     end

module.default = function(...)
    local args = table.pack(...)
    local server = args[1]
    local auto   = args[2]

    local setServer = settings.get(USERDATA_TAG .. ".server")
    local setAuto   = settings.get(USERDATA_TAG .. ".autoconnect")

    if args.n > 0 and args.n < 3 then
        server = server and cleanServerString(server) or setServer
        if type(auto) == "nil" then auto = setAuto end

        assert(type(server)    == "string",  "server must be a string")
        assert(type(auto)      == "boolean", "autoconnect must be a boolean")

        settings.set(USERDATA_TAG .. ".server", server)
        settings.set(USERDATA_TAG .. ".autoconnect", auto)

        setServer, setAuto = server, auto

        if auto then
            if module.KODI then
                module.KODI = module.KODI:delete()
            end
            module.KODI = autoconnect()
            instances[module.KODI].default = true
        else -- not autoconnect
            if module.KODI then
                module.KODI = module.KODI:delete()
            end
        end
    elseif args.n ~= 0 then
        return error("expected 3 arguments, got " .. tostring(args.n), 2)
    end

    local current = {
        server = setServer and cleanServerString(setServer, true) or "<not-defined>",
        auto   = type(setAuto) ~= "boolean" and "<not-defined>" or setAuto,
    }

    return setmetatable(current, { __tostring = inspect })
end

module.new = function(server)
    assert(type(server)    == "string",  "server must be specified and must be a string")

    local self = {}
    local id   = host.uuid()
    local headers = { ["Content-Type"] = "application/json" }

    mappings[id] = self
    instances[self] = {
        URL      = cleanServerString(server) .. "/jsonrpc",
        id       = id,
        headers  = headers,

        -- capture address of table for __tostring before we assign a __tostring metamethod
        tableRef = tostring(self),
    }
    setmetatable(self, kodiMT)

    backgroundConnection(id)
    return self
end

module.log = log

kodiMT.submit = function(self, method, parameters, callback)
    assert(type(method) == "string",                                "method must be a string")
    assert(type(paramters) == "table" or type(paramters) == "nil",  "parameters must be a table or nil")
    assert(type(callback) == "function" or type(callback) == "nil", "callback must be a function or nil")

    local params = json.encode({
        jsonrpc = "2.0",
        method  = method,
        params  = parameters,
        id      = instances[self].id,
    })

    if instances[self].debug then
        log.df("Request %s from %s", params, cleanServerString(instances[self].URL, true))
    end

    if callback then
        http.asyncPost(instances[self].URL, params, instances[self].headers, function(s, d, h)
            if instances[self].debug then
                local _, w = pcall(json.decode, d)
                local responseType = "invalid json"
                if _ and w.error then
                    responseType = "error"
                elseif _ and w.result then
                    responseType = "result"
                else
                    responseType = "unrecognized json"
                end
                log.df("ASync Response %s Status:%d with %s", instances[self].id, s, responseType)
                if instances[self].debugResponse then
                    log.df("ASync Response %s Details, status = %d\n     data:%s\n  headers:%s", instances[self].id, s, d, inspect(h))
                end
            end
            callback(s, d, h)
        end)
        return self
    elseif getAPIifConnected(self, instances[self].default) then
        local s, d, h = http.post(instances[self].URL, params, instances[self].headers)

        if instances[self].debug then
            local _, w = pcall(json.decode, d)
            local responseType = "invalid json"
            if _ and w.error then
                responseType = "error"
            elseif _ and w.result then
                responseType = "result"
            else
                responseType = "unrecognized json"
            end
            log.df("Sync Response %s Status:%d with %s", instances[self].id, s, responseType)
            if instances[self].debugResponse then
                log.df("Sync Response %s Details, status = %d\n     data:%s\n  headers:%s", instances[self].id, s, d, inspect(h))
            end
        end

        if (s == 200) then
            local answer = json.decode(d)
            return answer.result or answer.error
        else
            log.ef("%s request return code:%d", method, s)
        end
    end
end

kodiMT.API = function(self) return instances[self].API end
kodiMT.URL = function(self) return cleanServerString(instances[self].URL, true) end
kodiMT.id  = function(self) return instances[self].id end

kodiMT.delete = function(self)
    if instances[self].pingPong then
        instances[self].pingPong:stop()
        instances[self].pingPong = nil
    end
    if instances[self].reconnect then
        instances[self].reconnect:stop()
        instances[self].reconnect = nil
    end
    setmetatable(self, nil)
end

--- hs._asm.kodi:debug([state]) -> table | kodiObject
--- Method
--- Set whether or not debug logging is enabled for the KODI object, or access it's internal structures directly.
---
--- Parameters:
---  * `state` - an optional boolean indicating whether or not debugging should be enabled.
---
--- Returns:
---  * if `state` is specified, return the KODI object; otherwise, returns the table containing the internal structures which maintain state for the KODI object.
---
--- Notes:
---  * the additional logging which this method enables will be posted at the "debug" level.  You should set the modules log level to at least "debug" or greater verbosity to see the messages in the console as they appear; you could also use `hs.logger.printHistory(nil, "debug", "kodi")`.
---
---  * the internal structures should generally not be edited directly; it is currently available for debugging purposes during module development, and may go away in the future.  The most likely general use is to add response details to the debug logging (this is not logged by default, as the response body can be quite long for some requests):
--- ~~~lua
--- obj:debug(true)
--- obj:debug().debugResponse = true
--- ~~~
kodiMT.debug = function(self, state)
    if state == nil then
        return instances[self]
    else
        instances[self].debug = state and true or false
        return self
    end
end

-- mimic hs.itunes as closely as we can

-- + Constants - Useful values which cannot be changed
-- +     state_paused
-- +     state_playing
-- +     state_stopped
--   Functions - API calls offered directly by the extension
-- +     displayCurrentTrack
--       getCurrentAlbum
--       getCurrentArtist
--       getCurrentTrack
-- +     getPlaybackState
-- +     isPlaying
-- +     isRunning
-- +     next
-- +     pause
-- +     play
-- +     playpause
-- +     previous

-- since we're trying to match hs.itunes in this section, use the same constants
-- even though they don't really make any sense for this module.
module.state_paused  = "kPSp"
module.state_playing = "kPSP"
module.state_stopped = "kPSS"

module.displayCurrentTrack = function()
    if module.KODI then
        module.KODI:displayCurrentTrack()
    else
        alert.show("default KODI instance not specified", 1.75)
    end
end

module.getCurrentAlbum = function()
    if module.KODI then
        return module.KODI:getCurrentAlbum()
    else
        alert.show("default KODI instance not specified", 1.75)
    end
end

module.getCurrentArtist = function()
    if module.KODI then
        return module.KODI:getCurrentArtist()
    else
        alert.show("default KODI instance not specified", 1.75)
    end
end

module.getCurrentTrack = function()
    if module.KODI then
        return module.KODI:getCurrentTrack()
    else
        alert.show("default KODI instance not specified", 1.75)
    end
end

module.getPlaybackState = function()
    if module.KODI then
        return module.KODI:getPlaybackState()
    else
        alert.show("default KODI instance not specified", 1.75)
        return module.state_stopped
    end
end

module.isPlaying = function()
    if module.KODI then
        return module.KODI:isPlaying()
    else
        alert.show("default KODI instance not specified", 1.75)
        return false
    end
end

module.isRunning = function()
    if module.KODI then
        return module.KODI:isRunning()
    else
        alert.show("default KODI instance not specified", 1.75)
        return false
    end
end

module.next = function()
    if module.KODI then
        module.KODI:next()
    else
        alert.show("default KODI instance not specified", 1.75)
    end
end

module.pause = function()
    if module.KODI then
        module.KODI:pause()
    else
        alert.show("default KODI instance not specified", 1.75)
    end
end

module.play = function()
    if module.KODI then
        module.KODI:play()
    else
        alert.show("default KODI instance not specified", 1.75)
    end
end

module.playpause = function()
    if module.KODI then
        module.KODI:playpause()
    else
        alert.show("default KODI instance not specified", 1.75)
    end
end

module.previous = function()
    if module.KODI then
        module.KODI:previous()
    else
        alert.show("default KODI instance not specified", 1.75)
    end
end

kodiMT.displayCurrentTrack = function(self)
    local artist = self:getCurrentArtist() or "Unknown artist"
    local album  = self:getCurrentAlbum()  or "Unknown album"
    local track  = self:getCurrentTrack()  or "Unknown track"
    alert.show(track .."\n".. album .."\n".. artist, 1.75)
end

kodiMT.getPlaybackState = function(self)
    local players = self:submit("Player.GetActivePlayers")
    if not players then return module.state_stopped end

    if #players == 0 then return module.state_stopped end
    local somethingIsPlaying = false
    for i, v in ipairs(players) do
        local r = self:submit("Player.GetProperties", { playerid = v.playerid, properties = { "speed" } })
        somethingIsPlaying = (r.speed and r.speed ~= 0)
    end
    return somethingIsPlaying and module.state_playing or module.state_paused
end

kodiMT.isPlaying = function(self)
    return self:getPlaybackState() == module.state_playing
end

kodiMT.isRunning = function(self)
    return instances[self].API and true or false
end

kodiMT.playpause = function(self)
    local players = self:submit("Player.GetActivePlayers")
    if players then
        for i, v in ipairs(players) do
            self:submit("Player.PlayPause", { playerid = v.playerid })
        end
    end
    return self
end

kodiMT.play = function(self)
    local players = self:submit("Player.GetActivePlayers")
    if players then
        for i, v in ipairs(players) do
            self:submit("Player.SetSpeed", { playerid = v.playerid, speed = 1 })
        end
    end
    return self
end

kodiMT.pause = function(self)
    local players = self:submit("Player.GetActivePlayers")
    if players then
        for i, v in ipairs(players) do
            self:submit("Player.SetSpeed", { playerid = v.playerid, speed = 0 })
        end
    end
    return self
end

kodiMT.next = function(self)
    local players = self:submit("Player.GetActivePlayers")
    if players then
        for i, v in ipairs(players) do
            self:submit("Player.GoTo", { playerid = v.playerid, to = "next" })
        end
    end
    return self
end

kodiMT.previous = function(self)
    local players = self:submit("Player.GetActivePlayers")
    if players then
        for i, v in ipairs(players) do
            self:submit("Player.GoTo", { playerid = v.playerid, to = "previous" })
        end
    end
    return self
end

kodiMT.methods = function(self, withParams)
    local API = getAPIifConnected(self)
    if API then
        local results = {}
        for i,v in fnutils.sortByKeys(API.methods) do
            local t = i
            if withParams then
                t = t .. "("
                for i2, v2 in ipairs(v.params) do
                    if v2.required then
                        t = t .. v2.name
                    else
                        t = t .. "[" .. v2.name .. "]"
                    end
                    t = t .. ", "
                end
                t = (#v.params == 0 and t or t:sub(1, -3)) .. ")"
            end
            table.insert(results, t)
        end
        return setmetatable(results, { __tostring = function(_)
            return table.concat(_, "\n")
        end})
    end
end

local copyAndExapandReferences
copyAndExapandReferences = function(self, t, seen)
    seen = seen or {}
    if seen[t] then return seen[t] end
    local n = {}
    seen[t] = n
    for k, v in pairs(t) do
--         print(k, tostring(v))
        if k == "$ref" then
            local ref = copyAndExapandReferences(self, instances[self].API.types[v], seen)
            for k2, v2 in pairs(ref) do
                if not t[k2] then n[k2] = v2 end
            end
        elseif k == "extends" then
            if type(v) == "table" then
                for i3, v3 in ipairs(v) do
                    local ref = copyAndExapandReferences(self, instances[self].API.types[v3], seen)
                    for k2, v2 in pairs(ref) do
                        if not t[k2] then n[k2] = v2 end
                    end
                end
            else
                local ref = copyAndExapandReferences(self, instances[self].API.types[v], seen)
                for k2, v2 in pairs(ref) do
                    if not t[k2] then n[k2] = v2 end
                end
            end
        else
            if type(v) == "table" then
                n[k] = copyAndExapandReferences(self, v, seen)
            else
                n[k] = v
            end
        end
    end
    return n
end

local parseParameter = function(self, param, depth)
    local API = instances[self].API
    local lines = {}
    depth = depth or 0

    local fullDef = copyAndExapandReferences(self, param)

    table.insert(lines, inspect(fullDef))

    return lines
end

kodiMT.describe = function(self, cmd)
    assert(type(cmd) == "string", "method must be specified as a string")
    local API = getAPIifConnected(self)
    if API then
        local def = API.methods[cmd]

        if def then
            local lines = {}
            table.insert(lines, cmd .. " - " .. def.description)

            table.insert(lines, "")
            table.insert(lines, "Parameters:")
            if #def.params > 0 then
                table.insert(lines, "  * A table which contains the following key-value pairs:")
                for i,v in ipairs(def.params) do
                    local param = parseParameter(self, v, 1)
                    while #param > 0 do
                        table.insert(lines, table.remove(param, 1))
                    end
                end
            else
                table.insert(lines, "  * None")
            end

            table.insert(lines, "")
            table.insert(lines, "Returns:")
    -- don't know yet
            local noNotesPosition = #lines
            if def.permission then
                table.insert(lines, "  * Requires permission " .. def.permission)
            end
            -- more?

            if noNotesPosition ~= #lines then
                table.insert(lines, noNotesPosition + 1, "Notes:")
                table.insert(lines, noNotesPosition + 1, "")
            end

            return table.concat(lines, "\n")
        else
            log.ef("unrecognized method %s", cmd)
        end
    end
end

kodiMT.definition = function(self, cmd)
    assert(type(cmd) == "string", "method must be specified as a string")
    local API = getAPIifConnected(self)
    if API then
        local def = API.methods[cmd]
        if def then
            return setmetatable(copyAndExapandReferences(self, def), { __tostring = inspect })
        else
            log.ef("unrecognized method %s", cmd)
        end
    end
end

kodiMT.resetConnection = function(self)
    local internalSelf = instances[self]
    internalSelf.API = nil
    if internalSelf.reconnect then
        internalSelf.reconnect:stop()
        internalSelf.reconnect = nil
    end
    if internalSelf.pingPong then
        internalSelf.pingPong:stop()
        internalSelf.pingPong = nil
    end
    backgroundConnection(self.id)
    return self
end

kodiMT.__name  = USERDATA_TAG
kodiMT.__type  = USERDATA_TAG
kodiMT.__index = kodiMT

kodiMT.__call = function(self, cmd, params, callback)
    assert(type(cmd) == "string", "method must be specified as a string")
    if type(params) == "function" then params, callback = nil, params end
    assert(type(params) == "nil" or type(params) == "table", "parameters must be a table if specified")
    assert(type(callback) == "nil" or type(callback) == "table", "callback must be a function if specified")

    local API = getAPIifConnected(self)
    if API then
        local definition = API.methods[cmd]
        if definition then
            local result = self:submit(cmd, params, callback)
            if type(result) == "table" then
                return setmetatable(result, { __tostring = inspect })
            else
                return result
            end
        else
            log.ef("unrecognized method %s", cmd)
        end
    end
end

kodiMT.__tostring = function(self)
    return string.format("%s: %s (%s)", USERDATA_TAG, cleanServerString(instances[self].URL, true), instances[self].tableRef)
end

kodiMT.__gc = function(self)
    if instances[self] then
        if instances[self].debug then
            log.df("%s __gc", cleanServerString(instances[self].URL, true))
            local pingPong, reconnect = instances[self].pingPong, instances[self].reconnect

            if pingPong and getmetatable(pingPong) then
                log.d("__gc releasing pingPong timer")
                pingPong:stop()
            else
                log.df("__gc pingPong timer does%s exist%s", (pingPong and "" or "n't"), (pingPong and " but has no metatable" or ""))
            end
            instances[self].pingPong = nil

            if reconnect and getmetatable(reconnect) then
                log.d("__gc releasing reconnect timer")
                reconnect:stop()
            else
                log.df("__gc reconnect timer does%s exist%s", (reconnect and "" or "n't"), (reconnect and " but has no metatable" or ""))
            end
            instances[self].reconnect = nil

        end
    end
end

--- hs._asm.kodi._internals() -> table
--- Function
--- Returns a table containing the internal structures which maintain state for all of the current KODI instances.
---
--- Parameters:
---  * None
---
--- Returns:
---  * a table with the keys `instances` and `mappings` which contain internal structure and state information for the KODI instances.
---
--- Notes:
---  * This function is used for debugging during module development.  You should generally not need to access this, and it will likely go away in the future.
module._internals = function()
    return {
        instances = instances,
        mappings  = mappings
    }
end

-- Return Module Object --------------------------------------------------

--- hs._asm.kodi.KODI -> kodiObject
--- Variable
--- The default KODI object instance.
---
--- By using the [hs._asm.kodi.default](#default) function, you can create a default instance which allows using the iTunes/Spotify compatibility functions directly from the module.  Note that only one default can be specified.  The default can also be set to automatically connect when the module is loaded.
---
--- Use this object if you wish to take advantage of the more advanced methods provided by this module -- you do not need to use this object if you are just sticking with the compatibility functions and the default is set to automatically connect on module load.
---
--- If you wish to manage multiple KODI instances, or if you need to change the server based upon your current network, you should use [hs._asm.kodi.new](#new) and use the compatibility functions as methods, rather than as functions.
module.KODI = autoconnect()

module._sleepWatcher = sleepWatcher

debug.getregistry()[USERDATA_TAG] = kodiMT
return module
