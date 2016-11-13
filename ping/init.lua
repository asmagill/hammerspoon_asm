
--- === hs.network.ping ===
---
--- This module provides a basic ping function which can test host availability.  Ping is a network diagnostic tool commonly found in most operating systems which can be used to test if a route to a specified host exists and if that host is responding to network traffic.

local USERDATA_TAG = "hs.network.ping"
local module       = require(USERDATA_TAG..".internal")

local fnutils      = require("hs.fnutils")
local timer        = require("hs.timer")
local inspect      = require("hs.inspect")

local log          = require"hs.logger".new(USERDATA_TAG, "warning")
module.log = log

-- private variables and methods -----------------------------------------

local validClasses = { "any", "IPv4", "IPv6" }

local basicPingCompletionFunction = function(self)
    -- most likely this has already happened, unless called through cancel method
    if getmetatable(self.pingTimer) then self.pingTimer:stop() end
    self.pingTimer = nil
    self.callback(self, "pingCompleted")
    -- theoretically a packet could be received out of order, but since we're ending,
    -- clear callback to make sure it can't be invoked again by something in the queue
    self.pingObject:setCallback(nil):stop()
    self.pingObject = nil
    -- use pairs just in case we're missing a sequence number...
    for k, v in pairs(self.packets) do
        if getmetatable(v.timeoutWatcher) then v.timeoutWatcher:stop() end
        v.timeoutWatcher = nil
    end
end

local basicPingSummary = function(self)
    local packets, results, transmitted, received = self.packets, "", 0, 0
    local min, max, avg = math.huge, -math.huge, 0
    for i, v in pairs(packets) do
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
    results = results .. "--- " .. self.hostname .. " ping statistics ---\n" ..
            string.format("%d packets transmitted, %d packets received, %.1f packet loss\n",
                transmitted, received, 100.0 * ((transmitted - received) / transmitted)
            ) ..
            string.format("round-trip min/avg/max = %.3f/%.3f/%.3f ms", min, avg, max)
    return results
end

-- Public interface ------------------------------------------------------

module._defaultCallback = function(self, msg, ...)
    if msg == "didStart" then
        print("PING: " .. self.hostname .. " (" .. self.address .. "):")
    elseif msg == "didFail" then
        local err = ...
        print("PING: " .. self.address .. " error: " .. err)
        print(basicPingSummary(self))
    elseif msg == "sendPacketFailed" then
        local seq, err = ...
        local singleStat = self.packets[seq + 1]
        print(string.format("%d bytes to   %s: icmp_seq=%d %s.",
            #singleStat.icmp._raw,
            self.address,
            singleStat.icmp.sequenceNumber,
            err
        ))
    elseif msg == "receivedPacket" then
        local seq = ...
        local singleStat = self.packets[seq + 1]
        print(string.format("%d bytes from %s: icmp_seq=%d time=%.3f ms",
            #singleStat.icmp._raw,
            self.address,
            singleStat.icmp.sequenceNumber,
            (singleStat.recv - singleStat.sent) * 1000
        ))
    elseif msg == "pingCompleted" then
        print(basicPingSummary(self))
    end
end

module.ping = function(server, ...)
    assert(type(server) == "string", "server must be a string")
    local count, interval, timeout, class, fn = 5, 1, 2, "any", module._defaultCallback

    local args = table.pack(...)
    local seenCount, seenInterval, seenTimeout, seenClass, seenFn = false, false, false, false
    while #args > 0 do
        local this = table.remove(args, 1)
        if type(this) == "number" then
            if not seenCount then
                count = this
                assert(math.type(count) == "integer" and count > 0, "count must be an integer > 0")
                seenCount = true
            elseif not seenInterval then
                interval = this
                assert(type(interval) == "number" and interval > 0, "interval must be a number > 0")
                seenInterval = true
            elseif not seenTimeout then
                timeout = this
                assert(type(timeout) == "number" and timeout > 0, "timeout must be a number > 0")
                seenTimeout = true
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
    -- this also allows a table or userdata with a __call metamethod to be considered a function
        elseif (getmetatable(this) or {}).__call or type(this) == "function" then
            if not seenFn then
                fn = this
                seenfn = true
            else
                error("unexpected function argument", 2)
            end
        else
            error("unexpected " .. type(this) .. " argument", 2)
        end
    end

    local self = {
        packets     = {},
        sentCount = 0,
        maxCount  = count,
        allSent   = false,
        hostname  = server,
        address   = "<unresolved address>",
        callback  = fn,
    }
    self.label      = tostring(self):match("^table: (.+)$")

    self.pingObject = module.echoRequest(server):acceptAddressFamily(class):setCallback(function(obj, msg, ...)
        if msg == "didStart" then
            local address = ...
            self.address = address
            self.callback(self, msg)
        elseif msg == "didFail" then
            local err = ...
            if getmetatable(self.pingTimer) then self.pingTimer:stop() end
            self.pingTimer = nil
            -- we don't have to stop because the fail callback has already done it for us
            self.pingObject = nil
            self.callback(self, msg, err)
        elseif msg == "sendPacket" then
            local icmp, seq = ...
            self.packets[seq + 1] = {
                sent           = timer.secondsSinceEpoch(),
                timeoutWatcher = timer.doAfter(timeout, function()
                    self.packets[seq + 1].err = "packet timeout exceeded"
                    self.packets[seq + 1].timeoutWatcher = nil
                    if self.allSent then basicPingCompletionFunction(self) end
                end)
            }
            -- no callback in simplified version
        elseif msg == "sendPacketFailed" then
            local icmp, seq, err = ...
            self.packets[seq + 1] = {
                sent = timer.secondsSinceEpoch(),
                err  = err,
                icmp = icmp,
            }
            self.callback(self, msg, seq, err)
        elseif msg == "receivedPacket" then
            local icmp, seq = ...
            self.packets[seq + 1].recv = timer.secondsSinceEpoch()
            self.packets[seq + 1].icmp = icmp
            self.packets[seq + 1].err  = nil -- in case a late packet finally arrived
            if getmetatable(self.packets[seq + 1].timeoutWatcher) then
                self.packets[seq + 1].timeoutWatcher:stop()
            end
            self.packets[seq + 1].timeoutWatcher = nil
            self.callback(self, msg, seq)
            if self.allSent then basicPingCompletionFunction(self) end
        elseif msg == "receivedUnexpectedPacket" then
            local icmp = ...
            -- log it, but the ping callback doesn't need to know about it
            log.vf("unexpected packet when pinging %s:%s", obj:hostName(), (inspect(icmp):gsub("%s+", " ")))
        end
    end):start()
    self.pingTimer  = timer.doEvery(interval, function()
        if not self.paused then
            if self.sentCount < self.maxCount then
                self.pingObject:sendPayload()
                self.sentCount = self.sentCount + 1
                if self.sentCount == self.maxCount then self.allSent = true end
            else
                self.pingTimer:stop()
                self.pingTimer = nil
            end
        end
    end)

    return setmetatable(self, {
        __index = {
            pause = function(self)
                if getmetatable(self.pingTimer) then
                    self.paused = true
                    return self
                else
                    return nil
                end
            end,
            resume = function(self)
                if getmetatable(self.pingTimer) then
                    self.paused = nil
                    return self
                else
                    return nil
                end
            end,
            count = function(self, num)
                if type(num) == "nil" then
                    return self.maxCount
                elseif getmetatable(self.pingTimer) then
                    if math.type(num) == "integer" and num > self.sentCount then
                        self.maxCount = num
                        self.allSent = false
                        return self
                    else
                        error(string.format("must be an integer > %d", self.sentCount), 2)
                    end
                else
                    return nil
                end
            end,
            summary = basicPingSummary,
            cancel  = basicPingCompletionFunction,
        },
        __tostring = function(self)
            return string.format("%s: %s (%s)", USERDATA_TAG, self.hostname, self.label)
        end,
    })
end

-- Return Module Object --------------------------------------------------

return module
