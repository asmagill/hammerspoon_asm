local USERDATA_TAG = "hs.webview"

local osVersion = require"hs.host".operatingSystemVersion()
if (osVersion["major"] == 10 and osVersion["minor"] < 10) then
    hs.luaSkinLog.wf("%s is only available on OS X 10.10 or later", USERDATA_TAG)
    -- nil gets interpreted as "nothing" and thus "true" by require...
    return false
end

local module       = {} -- require(USERDATA_TAG..".internal")
module.toolbar     = require("hs._asm.enclosure.toolbar")

local enclosure = require("hs._asm.enclosure")
local webview   = require("hs._asm.enclosure.webview")

local enclosureMT = hs.getObjectMetatable("hs._asm.enclosure")
local webviewMT   = hs.getObjectMetatable("hs._asm.enclosure.webview")

-- private variables and methods -----------------------------------------

local internals = setmetatable({}, { __mode = "k" })

local deprecatedWarningsGiven = {}
local deprecatedWarningCheck = function(oldName, newName)
    if not deprecatedWarningsGiven[oldName] then
        deprecatedWarningsGiven[oldName] = true
        hs.luaSkinLog.wf("%s:%s is deprecated; use %s:%s instead", USERDATA_TAG, oldName, USERDATA_TAG, newName)
    end
end

local simplifiedMT = {
    __name = USERDATA_TAG,
    __type = USERDATA_TAG,
}
simplifiedMT.__index = function(self, key)
    if simplifiedMT[key] then
        return simplifiedMT[key]
--     elseif math.type(key) == "integer" then
--         return self.webview[key]
    else
        return nil
    end
end
simplifiedMT.__eq = function(self, other)
    return self.window == other.window and self.webview == other.webview
end
-- simplifiedMT.__len = function(self)
--     return #self.webview
-- end
simplifiedMT.__gc = function(self)
    self.window:contentView(nil)
    self.webview = nil ; -- don't think we need a delete, but we'll see... self.webview:delete()
    self.window = self.window:delete()
    setmetatable(self, nil)
end
simplifiedMT.__tostring = function(self)
    return string.format("%s: %s (%s)", USERDATA_TAG, tostring(self.window):match("{{.*}}"),internals[self].label)
end

local runForKeyOf = function(self, target, message, ...)
-- print(target, message, type(self.webview), type(self.window))
    local obj = self[target]
    local result = obj[message](obj, ...)
    if result == obj then
        return self
    else
        return result
    end
end

-- Public interface ------------------------------------------------------

-- wrap the non-metamethods for the webview submodule
for k, v in pairs(webviewMT) do
    if k:match("^%w") then
        simplifiedMT[k] = function(self, ...) return runForKeyOf(self, "webview", k, ...) end
    end
end

-- except for XXXX -- we're tying those effects to the window
-- simplifiedMT.hidden, simplifiedMT.alphaValue = nil, nil

simplifiedMT.alpha           = function(self, ...) return runForKeyOf(self, "window", "alphaValue", ...) end
simplifiedMT.behavior        = function(self, ...) return runForKeyOf(self, "window", "collectionBehavior", ...) end
simplifiedMT.bringToFront    = function(self, ...) return runForKeyOf(self, "window", "bringToFront", ...) end
simplifiedMT.closeOnEscape   = function(self, ...) return runForKeyOf(self, "window", "closeOnEscape", ...) end
simplifiedMT.hide            = function(self, ...) return runForKeyOf(self, "window", "hide", ...) end
simplifiedMT.level           = function(self, ...) return runForKeyOf(self, "window", "level", ...) end
simplifiedMT.sendToBack      = function(self, ...) return runForKeyOf(self, "window", "sendToBack", ...) end
simplifiedMT.show            = function(self, ...) return runForKeyOf(self, "window", "show", ...) end
simplifiedMT.hswindow        = function(self, ...) return runForKeyOf(self, "window", "hswindow", ...) end
simplifiedMT.toolbar         = function(self, ...) return runForKeyOf(self, "window", "toolbar", ...) end
simplifiedMT.windowStyle     = function(self, ...) return runForKeyOf(self, "window", "styleMask", ...) end

-- got to through hswindow/asHSWindow, which should really go away or use deprecated wrapper
-- simplifiedMT.frame           = function(self, ...) return runForKeyOf(self, "window", "frame", ...) end
-- simplifiedMT.size            = function(self, ...) return runForKeyOf(self, "window", "size", ...) end
-- simplifiedMT.topLeft         = function(self, ...) return runForKeyOf(self, "window", "topLeft", ...) end

simplifiedMT.allowTextEntry = function(self, ...)
    local args = table.pack(...)
    if args.n == 0 then
        return internals[self].allowTextEntry
    elseif args.n == 1 and type(args[1]) == "boolean" then
        internals[self].allowTextEntry = args[1]
        self.window:specifyCanBecomeKeyWindow(args[1])
        return self
    else
        error("expected an optional single boolean argument")
    end
end

simplifiedMT.transparent = function(self, ...)
    local args = table.pack(...)
    if args.n ~= 0 then
        self.webview:transparent(...)
        self.window:opaque(!self.webview:transparent())
        return self
    else
        return self.webview:transparent()
    end
end

simplifiedMT.behaviorAsLabels = function(self, ...)
    local args = table.pack(...)

    if args.n == 0 then
        local results = {}
        local behaviorNumber = self:behavior()

        if behaviorNumber ~= 0 then
            for i, v in pairs(module.windowBehaviors) do
                if type(i) == "string" then
                    if (behaviorNumber & v) > 0 then table.insert(results, i) end
                end
            end
        else
            table.insert(results, module.windowBehaviors[0])
        end
        return setmetatable(results, { __tostring = function(_)
            table.sort(_)
            return "{ "..table.concat(_, ", ").." }"
        end})
    elseif args.n == 1 and type(args[1]) == "table" then
        local newBehavior = 0
        for i,v in ipairs(args[1]) do
            local flag = tonumber(v) or module.windowBehaviors[v]
            if flag then newBehavior = newBehavior | flag end
        end
        return self:behavior(newBehavior)
    elseif args.n > 1 then
        error("behaviorByLabels method expects 0 or 1 arguments", 2)
    else
        error("behaviorByLabels method argument must be a table", 2)
    end
end

simplifiedMT.delete = simplifiedMT.__gc

simplifiedMT.sslCallback = function(self, ...)
    local args = table.pack(...)
    if args.n ~= 1 then
        error("expected 1 argument", 2)
    else
        local callback = args[1]
        if type(callback) == "function" or type(callback) == "nil" then
            if callback then
                local originalCallback = callback
                callback = function(v, ...) originalCallback(self, ...) end
            end
            self.webview:sslCallback(callback)
        else
            error("argument must be a function or nil", 2)
        end
    end
end

simplifiedMT.navigationCallback = function(self, ...)
    local args = table.pack(...)
    if args.n ~= 1 then
        error("expected 1 argument", 2)
    else
        local callback = args[1]
        if type(callback) == "function" or type(callback) == "nil" then
            if callback then
                local originalCallback = callback
                callback = function(m, v, ...) originalCallback(m, self, ...) end
            end
            self.webview:navigationCallback(callback)
        else
            error("argument must be a function or nil", 2)
        end
    end
end

simplifiedMT.policyCallback = function(self, ...)
    local args = table.pack(...)
    if args.n ~= 1 then
        error("expected 1 argument", 2)
    else
        local callback = args[1]
        if type(callback) == "function" or type(callback) == "nil" then
            if callback then
                local originalCallback = callback
                callback = function(m, v, ...) originalCallback(m, self, ...) end
            end
            self.webview:policyCallback(callback)
        else
            error("argument must be a function or nil", 2)
        end
    end
end

simplifiedMT.orderAbove = function(self, other)
    if other then
        return runForKeyOf(self, "window", "orderAbove", other.window)
    else
        return runForKeyOf(self, "window", "orderAbove")
    end
end

simplifiedMT.orderBelow = function(self, other)
    if other then
        return runForKeyOf(self, "window", "orderBelow", other.window)
    else
        return runForKeyOf(self, "window", "orderBelow")
    end
end

--- hs.webview:urlParts() -> table
--- Method
--- Returns a table of keys containing the individual components of the URL for the webview.
---
--- Parameters:
---  * None
---
--- Returns:
---  * a table containing the keys for the webview's URL.  See the function `hs.http.urlParts` for a description of the possible keys returned in the table.
---
--- Notes:
---  * This method is a wrapper to the `hs.http.urlParts` function wich uses the OS X APIs, based on RFC 1808.
---  * You may also want to consider the `hs.httpserver.hsminweb.urlParts` function for a version more consistent with RFC 3986.
simplifiedMT.urlParts = function(self)
    return http.urlParts(self.webview.url)
end

simplifiedMT.asHSWindow = function(self, ...)
    deprecatedWarningCheck("asHSWindow", "hswindow")
    return self:hswindow(...)
end

simplifiedMT.setLevel = function(self, ...)
    deprecatedWarningCheck("setLevel", "level")
    return self:level(...)
end

simplifiedMT.asHSDrawing = setmetatable({}, {
    __call = function(self, obj, ...)
        if not deprecatedWarningsGiven["asHSDrawing"] then
            deprecatedWarningsGiven["asHSDrawing"] = true
            hs.luaSkinLog.wf("%s:asHSDrawing() is deprecated and should not be used.", USERDATA_TAG)
        end
        return setmetatable({}, {
            __index = function(self, func)
                if simplifiedMT[func] then
                    deprecatedWarningCheck("asHSDrawing():" .. func, func)
                    return function (_, ...) return simplifiedMT[func](obj, ...) end
                elseif func:match("^set") then
                    local newFunc = func:match("^set(.*)$")
                    newFunc = newFunc:sub(1,1):lower() .. newFunc:sub(2)
                    if simplifiedMT[newFunc] then
                        deprecatedWarningCheck("asHSDrawing():" .. func, newFunc)
                        return function (_, ...) return simplifiedMT[newFunc](obj, ...) end
                    end
                end
                hs.luaSkinLog.wf("%s:asHSDrawing() is deprecated and the method %s does not currently have a replacement.  If you believer this is an error, please submit an issue.", USERDATA_TAG, func)
                return nil
            end,
        })
    end,
})

module.windowMasks = enclosure.masks

for k, v in pairs(webview) do module[k] = v end

module.new = function(frame, ...)
    local self = {}

    internals[self] = { label = tostring(self):match("^table: (.+)$"), allowTextEntry = false }

    self.window = enclosure.new(frame, enclosure.masks.borderless):level(module.windowLevels.normal)
                                                                  :opaque(true)
                                                                  :hasShadow(false)
                                                                  :ignoresMouseEvents(false)
                                                                  :hidesOnDeactivate(false)
                                                                  :backgroundColor{ white = 0.0, alpha = 0.0 }
                                                                  :animationBehavior("none")
                                                                  :closeOnEscape(false)
                                                                  :specifyCanBecomeKeyWindow(false)
--         self.parent             = nil ;
--         self.children           = [[NSMutableArray alloc] init] ;

    self.webview = webview.newView(self.window:contentViewBounds(), ...)
    self.window:contentView(self.webview)

    return setmetatable(self, simplifiedMT)
end

module.newBrowser = function(...)
    return module.new(...):windowStyle(1+2+4+8)
                          :allowTextEntry(true)
                          :allowGestures(true)
end

-- Return Module Object --------------------------------------------------

-- assign to the registry in case we ever need to access the metatable from the C side
debug.getregistry()[USERDATA_TAG] = simplifiedMT
debug.getregistry()[USERDATA_TAG .. ".toolbar"]     = debug.getregistry()["hs._asm.enclosure.toolbar"]
debug.getregistry()[USERDATA_TAG .. ".datastore"]   = debug.getregistry()["hs._asm.enclosure.webview.datastore"]
debug.getregistry()[USERDATA_TAG .. ".usercontent"] = debug.getregistry()["hs._asm.enclosure.webview.usercontent"]

return module
