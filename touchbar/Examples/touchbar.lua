
--
-- Sample Use of hs._asm.touchbar
--
-- Copy this file into your ~/.hammerspoon/ directory and then type (or add to your init.lua) the
-- following: myToolbar = require("touchbar")
--
--
-- This example uses the hs._asm.touchbar module to create an on-screen visible representation of the
-- Apple Touch Bar on your screen.
--
-- When you press and hold the right Option key for at least 2 seconds, the touch bar's visibility
-- will toggle.  When the touch bar becomes visible, it will appear centered at the bottom of your
-- main screen.
--
-- While the touch bar is visible, if you move your mouse pointer within the bounds of the visible
-- touch bar window and then press and hold the left Option key, you can then click and drag the
-- touch bar to another location on the screen.  Release the option key to start using it again.
--

local module   = {}
local touchbar = require("hs._asm.touchbar")
local eventtap = require("hs.eventtap")
local timer    = require("hs.timer")

local events   = eventtap.event.types

local mouseInside = false
local touchbarWatcher = function(obj, message)
    if message == "didEnter" then
        mouseInside = true
    elseif message == "didExit" then
        mouseInside = false
    -- just in case we got here before the eventtap returned the touch bar to normal
        module.touchbar:backgroundColor{ white = 0 }
                       :movable(false)
                       :acceptsMouseEvents(true)
    end
end

local createTouchbarIfNeeded = function()
    if not module.touchbar then
        module.touchbar = touchbar.new():inactiveAlpha(.4):setCallback(touchbarWatcher)
    end
end

-- should add a cleaner way to detect right modifiers then checking their flags, but for now,
-- ev:getRawEventData().CGEventData.flags == 524608 works for right alt, 524576 for left alt
-- You can check for others with this in the console:
--  a = hs.eventtap.new({12}, function(e) print(hs.inspect(e:getFlags()), hs.inspect(e:getRawEventData())) ; return false end):start()

module.rightOptPressed   = false
module.rightOptPressTime = 2

-- we only care about events other than flagsChanged that should *stop* a current count down
module.eventwatcher = eventtap.new({events.flagsChanged, events.keyDown, events.leftMouseDown}, function(ev)
    module.rightOptPressed = false
    if ev:getType() == events.flagsChanged and ev:getRawEventData().CGEventData.flags == 524608 then
        module.rightOptPressed = true
        module.countDown = timer.doAfter(module.rightOptPressTime, function()
            if module.rightOptPressed then
                createTouchbarIfNeeded()
                module.touchbar:toggle()
                if module.touchbar:isVisible() then module.touchbar:centered() end
            end
        end)
    else
        if module.countDown then
            module.countDown:stop()
            module.countDown = nil
        end
        if mouseInside then
            if ev:getType() == events.flagsChanged and ev:getRawEventData().CGEventData.flags == 524576 then
                module.touchbar:backgroundColor{ red = 1 }
                               :movable(true)
                               :acceptsMouseEvents(false)
            elseif ev:getType() ~= events.leftMouseDown then
                module.touchbar:backgroundColor{ white = 0 }
                               :movable(false)
                               :acceptsMouseEvents(true)
            end
        end
    end
    return false
end):start()

module.toggle = function()
    createTouchbarIfNeeded()
    module.touchbar:toggle()
    if module.touchbar:isVisible() then module.touchbar:centered() end
end

return module
