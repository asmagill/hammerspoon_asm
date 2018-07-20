-- maybe make this a spoon if the bonjour module ever goes into core

local module = {}

local USERDATA_TAG = debug.getinfo(1).short_src:match("([^/]+)%.lua$")

-- interesting, I didn't know this existed, but ultimately not of much use as it doesn't seem to have
-- been utilized much... try it if you want
local WIDE_AREA_DOMAIN = "dns-sd.org."
local ENABLE_WIDE_AREA_DOMAIN = false

local bonjour = require("hs._asm.bonjour")
local chooser = require("hs.chooser")
local host    = require("hs.host")
local fnutils = require("hs.fnutils")
local hotkey  = require("hs.hotkey")

-- make this whatever you want, or comment it out entirely
hotkey.bind({"cmd", "alt", "ctrl"}, "=", function() module.toggle() end)

-- ditto if you're using the wide area domain lookup as well
if ENABLE_WIDE_AREA_DOMAIN then
    hotkey.bind({"cmd", "alt", "ctrl", "shift"}, "=", function() module.toggleWide() end)
end

local _log = require("hs.logger").new(USERDATA_TAG, "warning")

local _chooserCommonCallback = function(item, serverList)
    if item then
        local link = item.subText
        _log.f("open %s", link)
        hs.execute("open " .. link)
    end
end

local _chooserCommonChoices = function(serverList)
    local options = {}
    for k,v in fnutils.sortByKeys(serverList) do
        local hostname, link = v:hostname(), "n/a"
        if hostname then
            local path = (v:txtRecord() or {}).path or "/"
            link = string.format("http://%s:%d%s", hostname, v:port(), path)
        end
        table.insert(options, {
            text    = v:name(),
            subText = link,
        })
    end
    return options
end

local _servers = {}

local _chooser = chooser.new(function(item) _chooserCommonCallback(item, _servers) end)
                        :choices(function() return _chooserCommonChoices(_servers) end)

local _browserCommonCallback = function(serverList, ui, b, message, state, service, m)
    if message == "service" then
        local name = service:name()
        serverList[name] = state and service or nil
        if state then
            -- to get the port and hostname we have to resolve the address
            serverList[name]:resolve(10, function(svc, msg, err)
                if msg == "stop" or msg == "resolved" then
                    -- in case it disappeared on us, check that it's still around to stop
                    if serverList[name] then serverList[name]:stop() end
                elseif msg == "error" then
                    _log.ef("service resolve error for %s: %s", name, err)
                else
                    _log.wf("unexpected resolve message for %s: %s", name, msg)
                end
                ui:refreshChoicesCallback()
            end)
        else
            ui:refreshChoicesCallback() -- to clear removed entry
        end
    elseif message == "error" then
        _log.ef("browser query error: %s", state)
    else
        _log.wf("unexpected browser query message: %s", message)
    end
end

local _browser = bonjour.browser.new():findServices("_http._tcp.", function(...)
    _browserCommonCallback(_servers, _chooser, ...)
end)

module.toggle = function()
    if _chooser:isVisible() then
        _chooser:hide()
    else
        _chooser:bgDark(host.interfaceStyle() == "Dark"):show()
    end
end

if ENABLE_WIDE_AREA_DOMAIN then
    local _serversWide = {}

    local _chooserWide = chooser.new(function(item) _chooserCommonCallback(item, _serversWide) end)
                            :choices(function() return _chooserCommonChoices(_serversWide) end)

    local _browserWide = bonjour.browser.new():findServices("_http._tcp.", WIDE_AREA_DOMAIN, function(...)
        _browserCommonCallback(_serversWide, _chooserWide, ...)
    end)

    module.toggleWide = function()
        if _chooserWide:isVisible() then
            _chooserWide:hide()
        else
            _chooserWide:bgDark(host.interfaceStyle() == "Dark"):show()
        end
    end
end

-- keeps an inspect of the module clean, but this info is still available if I need it for debugging
local _debug = {
    _log = _log,
    _servers     = _servers,
    _serversWide = _serversWide,
    _browser     = _browser,
    _browserWide = _browserWide,
    _chooser     = _chooser,
    _chooserWide = _chooserWide,
}

return setmetatable(module, {
    _debug  = _debug,
    __index = function(self, key) return _debug[key] end,
})
