--- === hs.network.ping ===
---
--- This sub-module provides functions to use ICMP send and receive messages to test host availability.

local USERDATA_TAG = "hs.network.ping"
local module       = require(USERDATA_TAG..".internal")

local fnutils      = require("hs.fnutils")
local timer        = require("hs.timer")
local inspect      = require("hs.inspect")

local log          = require"hs.logger".new(USERDATA_TAG, "warning")
module.log = log

-- private variables and methods -----------------------------------------

local validClasses = { "any", "IPv4", "IPv6" }

-- Public interface ------------------------------------------------------

module.ping = function(server, ...)
    assert(type(server) == "string", "server must be a string")
    local count, interval, class, fn = 5, 1, "any", function(o, m, ...)
            local printSummary = function(_)
                local transmitted, received = 0, 0
                local min, max, avg = math.huge, -math.huge, 0
                for i, v in pairs(_) do
                    transmitted = transmitted + 1
                    if v.recv then
                        received = received + 1
                        local rt = v.recv - v.sent
                        min = math.min(min, rt)
                        max = math.max(max, rt)
                        avg = avg + rt
                    end
                end
                avg = avg / transmitted
                min, max, avg = min * 1000, max * 1000, avg * 1000
                print("--- " .. o:hostName() .. " ping statistics ---")
                print(string.format("%d packets transmitted, %d packets received, %.1f packet loss",
                    transmitted, received, 100.0 * ((transmitted - received) / transmitted)
                ))
                print(string.format("round-trip min/avg/max = %.3f/%.3f/%.3f ms", min, avg, max))
            end

            if m == "didStart" then
                local _, address = ...
                print("PING: " .. o:hostName() .. " (" .. address .. "):")
            elseif m == "pingTimeout" then
                local _, timeout = ...
                print("PING: " .. o:hostAddress() .. " timeout at " .. tostring(timeout) .. " seconds")
                printSummary(_)
            elseif m == "didFail" then
                local _, err = ...
                local address = o:hostAddress()
                if type(address) == "boolean" then address = "<unresolved address>" end
                print("PING: " .. address .. " error: " .. err)
                printSummary(_)
            elseif m == "sendPacketFailed" then
                local _, err = ...
                print(string.format("%d bytes to   %s: icmp_seq=%d %s.",
                    #_.icmp._raw,
                    o:hostAddress(),
                    _.icmp.sequenceNumber,
                    err
                ))
            elseif m == "receivedPacket" then
                local _ = ...
                print(string.format("%d bytes from %s: icmp_seq=%d time=%.3f ms",
                    #_.icmp._raw, o:hostAddress(), _.icmp.sequenceNumber, (_.recv - _.sent) * 1000
                ))
            elseif m == "pingCompleted" then
                local _ = ...
                printSummary(_)
            end
        end

    local args = table.pack(...)
    local seenCount, seenInterval, seenClass, seenFn = false, false, false, false
    while #args > 0 do
        local this = table.remove(args, 1)
        if type(this) == "number" then
            if not seenCount then
                count = this
                assert(math.type(count) == "integer", "count must be an integer")
                seenCount = true
            elseif not seenInterval then
                interval = this
                assert(type(interval) == "number", "interval must be a number")
                seenInterval = true
            else
                error("unexpected numerical argument", 2)
            end
        elseif type(this) == "string" then
            if not seenClass then
                class = this
                assert(fnutils.contains(validClasses, class),
                    "class must be one of '" .. table.concat(validClasses, "', '") .. "'")
                seenClass = true
            else
                error("unexpected string argument", 2)
            end
        elseif type(this) == "function" or type(this) == "table" then
            if not seenFn then
                if type(this) == "table" then
                    local mt = getmetatable(this)
                    if mt.__call then
                        fn = function(...) mt.__call(this, ...) end
                    else
                        fn = nil
                    end
                else
                    fn = this
                end
                assert(type(fn) == "function", "fn must be a function")
                seenfn = true
            else
                error("unexpected function argument", 2)
            end
        else
            error("unexpected " .. type(this) .. " argument", 2)
        end
    end

    local backgroundedPings = {}
    local backgroundedStats = {}
    local pingTimer
    local pinger
    pinger = module.new(server):acceptAddressFamily(class):setCallback(function(o, m, ...)
        if m == "didStart" then
            local address = ...
            for i = 1, count, 1 do
                table.insert(backgroundedPings, timer.doAfter(interval * (i - 1), function()
                    o:sendPayload()
                end))
            end
            -- will have to see if this needs adjusting -- should be time enough for all
            --      pings plus a little extra for resolution/delays/etc.
            local timeout = interval * count + 5
            pingTimer = timer.doAfter(timeout, function()
                if pinger and getmetatable(pinger) then
                    while #backgroundedPings > 0 do
                        local pt = table.remove(backgroundedPings)
                        if getmetatable(pt) then pt:stop() end
                    end
                    fn(o, "pingTimeout", backgroundedStats, timeout)
                    pinger:stop()
                    pingTimer = nil
                    pinger = nil
                end
            end)
            fn(o, m, backgroundedStats, address)
        elseif m == "didFail" then
            local err = ...
            if pingTimer then
                pingTimer:stop()
                pingTimer = nil
            end
            while #backgroundedPings > 0 do
                local pt = table.remove(backgroundedPings)
                if getmetatable(pt) then pt:stop() end
            end
            fn(o, m, backgroundedStats, err)
            -- we don't have to stop because the fail callback has already done it for us
            pinger = nil
        elseif m == "sendPacket" then
            local icmp, seq = ...
            backgroundedStats[seq + 1] = {
                sent = timer.secondsSinceEpoch()
            }
        elseif m == "sendPacketFailed" then
            local icmp, seq, err = ...
            backgroundedStats[seq + 1] = {
                sent = timer.secondsSinceEpoch(),
                err  = err,
                icmp = icmp,
            }
            fn(o, m, backgroundedStats[seq + 1], err)
        elseif m == "receivedPacket" then
            local icmp, seq = ...
            backgroundedStats[seq + 1].recv = timer.secondsSinceEpoch()
            backgroundedStats[seq + 1].icmp = icmp
            fn(o, m, backgroundedStats[seq + 1])
        elseif m == "receivedUnexpectedPacket" then
            -- log it, but the ping callback doesn't need to know about it
            local icmp = ...
            log.df("unexpected packet when pinging %s:%s", o:hostName(), inspect(icmp))
        end

        local done = true
        for i = 1, count, 1 do
            if backgroundedStats[i] then
                if not backgroundedStats[i].recv and not backgroundedStats[i].err then
                    done = false
                end
            else
                done = false
            end
            if not done then break end
        end

        if done then
            pingTimer:stop()
            pingTimer = nil
            fn(o, "pingCompleted", backgroundedStats)
            pinger:stop()
            while #backgroundedPings > 0 do
                local pt = table.remove(backgroundedPings)
                if getmetatable(pt) then pt:stop() end
            end
            pinger = nil
        end
    end):start()
end

-- Return Module Object --------------------------------------------------

return module
