--
-- Creates a panel which slides up from the bottom of the screen when the mouse pointer is moved to the bottom
-- border of the screen
--
-- At present, this is more of a "proof of concept" then anything useful; the ultimate intent is to allow assigning
-- elements and canvases to the panel so that they can be viewed on demand but are hidden out of sight otherwise.
-- This will likely become a spoon at some point -- it is included here to provide an example of the mouse
-- tracking features added to hs._asm.guitk
--

local guitk  = require("hs._asm.guitk")
local timer  = require("hs.timer")
local canvas = require("hs.canvas")
local screen = require("hs.screen")
local mouse  = require("hs.mouse")

local MAXSTEPS = 10 -- how many steps should the panel take to go from full close to full open or vice-versa

local module = {}
local _panel, _sensor
local _frame
local resetOnCurrentScreen = function()
    _frame = screen.mainScreen():fullFrame()
    _panel:frame{  x = _frame.x, y = _frame.y + _frame.h,     h = _frame.h / 2, w = _frame.w }
    _sensor:frame{ x = _frame.x, y = _frame.y + _frame.h - 1, h = 1,            w = _frame.w }
--            :orderAbove(_panel:_nextResponder()) -- see below
end

local _targetCount, _count, _dir
local startPanelTimer = function()
    return timer.doEvery(0.5 / MAXSTEPS, function()
        if _count == 0 and _targetCount == MAXSTEPS then _panel:show() end
        _count = _count + _dir
        _panel:topLeft{ x = _frame.x, y = _frame.y + _frame.h * ( 1 - _count / (2 * MAXSTEPS) ) }
        if _count == 0 and _targetCount == 0 then _panel:hide() end
        if _count == _targetCount then
            module._panelMoveTimer:stop()
            module._panelMoveTimer = nil
        end
    end)
end

_panel  = guitk.newCanvas{}:level("status")
                           :ignoresMouseEvents(false) -- see below
                           :contentManager(guitk.manager.new())

_sensor = guitk.newCanvas{}:level("status")
                           :collectionBehavior("canJoinAllSpaces")
                           :contentManager(guitk.manager.new():mouseCallback(function(mgr, msg, loc)
--                                print(msg, finspect(loc))
                               if msg == "enter" then
                                   _targetCount, _dir = MAXSTEPS, 1
                                   if not module._panelMoveTimer then
                                       _count = 0
                                       module._panelMoveTimer = startPanelTimer()
                                   end
                               elseif msg == "exit" then
                                   _targetCount, _dir = 0, -1
                                   if not module._panelMoveTimer then
                                       _count = MAXSTEPS
                                       module._panelMoveTimer = startPanelTimer()
                                   end
                               end
                           end)):show()
-- by keeping them at different levels, the movement of the panel doesn't cause sensor to lose its position as
-- the receiver of mouse enter/exit messages during panel deployment. Could also set ignoresMouseEvents true on the
-- panel, but I'm considering adding a timer to allow panel elements to take mouse clicks before automatically
-- clearning.
_sensor:level(_sensor:level() + 1)

-- since we access the content managers more often then the windows, save the manager object instead;
-- it makes for clearer code IMHO. We can always get the window if we need it with :_nextResponder()
_panel, _sensor = _panel:contentManager(), _sensor:contentManager()
resetOnCurrentScreen()

_panel[#_panel + 1] = {
    _element = canvas.new{},
    frameDetails = { x = 0, y = 0, h = "100%", w = "100%" },
    id = "background",
}

_panel("background")[#_panel("background") + 1] = {
    type             = "rectangle",
    id               = "backPanel",
    strokeWidth      = 10,
    fillColor        = { alpha = .5 },
    strokeColor      = { alpha = .7 },
    roundedRectRadii = {xRadius = 10, yRadius = 10},
    clipToPath       = true,
}

module._screenWatcher = screen.watcher.newWithActiveScreen(function(active)
    if module._panelMoveTimer then
        _sensor:mouseCallback()(_sensor, "exit", mouse.getAbsolutePosition())
    end
    resetOnCurrentScreen()
end):start()

module._panel  = _panel
module._sensor = _sensor

return module
