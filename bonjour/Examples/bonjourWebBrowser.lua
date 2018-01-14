-- maybe make this a spoon if the bonjour module ever goes into core

local module = {}

local USERDATA_TAG = debug.getinfo(1).short_src:match("([^/]+)%.lua$")

local bonjour = require("hs._asm.bonjour")
local chooser = require("hs.chooser")
local host    = require("hs.host")
local fnutils = require("hs.fnutils")
local hotkey  = require("hs.hotkey")

-- make this whatever you want, or comment it out entirely
hotkey.bind({"cmd", "alt", "ctrl"}, "=", function() module.toggle() end)
-- by wrapping module.toggle like this, it doesn't have to be defined yet as long as `module` has been

local _log = require("hs.logger").new(USERDATA_TAG, "warning")

local _servers = {}

local _chooser = chooser.new(function(item)
        if item then
            local site = _servers[item.text]
            local link = "http://" .. site:hostname() .. ":" .. tostring(site:port())
            _log.f("open %s", link)
            hs.execute("open " .. link)
        end
    end):choices(function()
        local options = {}
        for k,v in fnutils.sortByKeys(_servers) do
            table.insert(options, {
                text    = v:name(),
            })
        end
        return options
    end)

local _browser = bonjour.browser.new():findServices("_http._tcp.", function(b, message, state, service, m)
        if message == "service" then
            local name = service:name()
            _servers[name] = state and service or nil
            _chooser:refreshChoicesCallback()
            if state then
                -- to get the port and hostname we have to resolve the address
                _servers[name]:resolve(2, function(svc, msg, err)
                    if msg == "stop" or msg == "resolved" then
                        -- in case it disappeared on us, check that it's still around to stop
                        if _servers[name] then _servers[name]:stop() end
                    elseif msg == "error" then
                        _log.ef("service resolve error for %s: %s", name, err)
                    else
                        _log.wf("unexpected resolve message for %s: %s", name, msg)
                    end
                end)
            end
        elseif message == "error" then
            _log.ef("browser query error: %s", state)
        else
            _log.wf("unexpected browser query message: %s", message)
        end
    end)

module.toggle = function()
    if _chooser:isVisible() then
        _chooser:hide()
    else
        _chooser:bgDark(host.interfaceStyle() == "Dark")
                :show()
    end
end

-- keeps an inspect of the module clean, but this info is still available if I need it for debugging
local _debug = {
    _log = _log,
    _servers = _servers,
    _browser = _browser,
    _chooser = _chooser,
}

return setmetatable(module, {
    _debug  = _debug,
    __index = function(self, key) return _debug[key] end,
})
