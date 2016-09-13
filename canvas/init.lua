--- === hs._asm.canvas ===
---
--- Wrapper for hs._asm.enclosure and hs._asm.enclosure.canvas to simplify the creation of canvas only visual elements.
---
--- This module provides a wrapper that makes creating canvas only visual elements easier by handling the window and view hierarchy code for you.
---
--- hs._asm.canvas was originally envisioned as a more feature packed replacement to hs.drawing in Hammerspoon.  As hs._asm.canvas grew, it's scope expanded to envision a plugin architecture for additional views including multimedia content, text editing, and scrollable areas, to name a few.  To more adequately handle these additions, canvas as broken up into hs._asm.enclosure and hs._asm.enclosure.canvas to more closely match the Objective-C classes which are actually handling the visual elements behind the scenes.  While the new architecture is more powerful, it also make creating simple visual elements more complex then the original hs.drawing module which canvas was intended to replace.
---
--- This wrapper handles this additional complexity for you, when all you wish to do is create a visual element for use within Hammerspoon.

local USERDATA_TAG = "hs._asm.canvas"
local module       = {} -- require(USERDATA_TAG..".internal")

local enclosure = require("hs._asm.enclosure")
local canvas    = require("hs._asm.enclosure.canvas")

local enclosureMT = hs.getObjectMetatable("hs._asm.enclosure")
local canvasMT    = hs.getObjectMetatable("hs._asm.enclosure.canvas")

-- private variables and methods -----------------------------------------

local internals = setmetatable({}, { __mode = "k" })

local simplifiedMT = {
    __name = USERDATA_TAG,
    __type = USERDATA_TAG,
}
simplifiedMT.__index = function(self, key)
    if simplifiedMT[key] then
        return simplifiedMT[key]
    elseif math.type(key) == "integer" then
        return self.canvas[key]
    elseif key == "_default" then
        return self.canvas._default
    else
        return nil
    end
end
simplifiedMT.__eq = function(self, other)
    return self.window == other.window and self.canvas == other.canvas
end
simplifiedMT.__len = function(self)
    return #self.canvas
end
simplifiedMT.__gc = function(self)
    self.window:contentView(nil)
    self.canvas = nil ; -- don't think we need a delete, but we'll see... self.canvas:delete()
    self.window = self.window:delete()
    setmetatable(self, nil)
end
simplifiedMT.__tostring = function(self)
    return string.format("%s: %s (%s)", USERDATA_TAG, tostring(self.window):match("{{.*}}"),internals[self].label)
end
simplifiedMT.__newindex = function(self, key, value)
    self.canvas[key] = value
end
simplifiedMT.__pairs = function(self)
    return self.canvas:__pairs()
end

local runForKeyOf = function(self, target, message, ...)
-- print(target, message, type(self.canvas), type(self.window))
    local obj = self[target]
    local result = obj[message](obj, ...)
    if result == obj then
        return self
    else
        return result
    end
end

-- Public interface ------------------------------------------------------

-- wrap the non-metamethods for the canvas submodule
for k, v in pairs(canvasMT) do
    if k:match("^%w") then
        simplifiedMT[k] = function(self, ...) return runForKeyOf(self, "canvas", k, ...) end
    end
end
-- except for hidden & alphaValue -- we're tying those effects to the window
simplifiedMT.hidden, simplifiedMT.alphaValue = nil, nil

simplifiedMT.alpha           = function(self, ...) return runForKeyOf(self, "window", "alphaValue", ...) end
simplifiedMT.behavior        = function(self, ...) return runForKeyOf(self, "window", "collectionBehavior", ...) end
simplifiedMT.bringToFront    = function(self, ...) return runForKeyOf(self, "window", "bringToFront", ...) end
simplifiedMT.clickActivating = function(self, ...) return runForKeyOf(self, "window", "clickActivating", ...) end
simplifiedMT.frame           = function(self, ...) return runForKeyOf(self, "window", "frame", ...) end
simplifiedMT.hide            = function(self, ...) return runForKeyOf(self, "window", "hide", ...) end
simplifiedMT.isOccluded      = function(self, ...) return runForKeyOf(self, "window", "isOccluded", ...) end
simplifiedMT.isShowing       = function(self, ...) return runForKeyOf(self, "window", "isShowing", ...) end
simplifiedMT.isVisible       = function(self, ...) return runForKeyOf(self, "window", "isVisible", ...) end
simplifiedMT.level           = function(self, ...) return runForKeyOf(self, "window", "level", ...) end
simplifiedMT.sendToBack      = function(self, ...) return runForKeyOf(self, "window", "sendToBack", ...) end
simplifiedMT.show            = function(self, ...) return runForKeyOf(self, "window", "show", ...) end
simplifiedMT.size            = function(self, ...) return runForKeyOf(self, "window", "size", ...) end
simplifiedMT.topLeft         = function(self, ...) return runForKeyOf(self, "window", "topLeft", ...) end

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

simplifiedMT.mouseCallback = function(self, ...)
    local args = table.pack(...)
    if args.n ~= 1 then
        error("expected 1 argument", 2)
    else
        local callback = args[1]
        if type(callback) == "function" or type(callback) == "nil" then
            self.window:ignoresMouseEvents(true)
            self.canvas:mouseCallback(callback)
            if callback then self.window:ignoresMouseEvents(false) end
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

module.windowBehaviors      = enclosure.behaviors
module.windowLevels         = enclosure.levels
module.disableScreenUpdates = enclosure.disableScreenUpdates
module.enableScreenUpdates  = enclosure.enableScreenUpdates

for k, v in pairs(canvas) do module[k] = v end

module.new = function(frame)
    local self = {}

    internals[self] = { label = tostring(self):match("^table: (.+)$") }

    self.window = enclosure.new(frame, enclosure.masks.borderless):level(module.windowLevels.screenSaver)
                                                                  :opaque(false)
                                                                  :hasShadow(false)
                                                                  :ignoresMouseEvents(true)
                                                                  :hidesOnDeactivate(false)
                                                                  :backgroundColor{ white = 0.0, alpha = 0.0 }
                                                                  :animationBehavior("none")
    frame.x, frame.y = 0, 0
    self.canvas = canvas.newView(frame)
    self.window:contentView(self.canvas)

    return setmetatable(self, simplifiedMT)
end

-- Return Module Object --------------------------------------------------

-- assign to the registry in case we ever need to access the metatable from the C side
debug.getregistry()[USERDATA_TAG] = simplifiedMT

return module
