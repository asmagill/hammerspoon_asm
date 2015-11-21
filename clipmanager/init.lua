
--- === hs._asm.clipmanager ===
---
--- Description


-- Need to add parameter setting, menu, pasting, parameter and history saving

local module = {}

-- Technically not needed in hammerspoon, but good practice anyways
local menubar     = require "hs.menubar"
local timer       = require "hs.timer"
local settings    = require "hs.settings"
local pasteboard  = require "hs.pasteboard"

-- private variables and methods -----------------------------------------

local storedChangeCount = pasteboard.changeCount()
local storedClipHistory = {}
local maxHistory = settings.get("hs._asm.clipmanager.maxHistory") or 25
local pollInterval = settings.get("hs._asm.clipmanager.pollInterval") or 1

local clipboardChecker = function()
    if pasteboard.changeCount() > storedChangeCount then
        local clipboardContents = pasteboard.getContents()
        if clipboardContents then   -- we can do something with it
            table.insert(storedClipHistory, clipboardContents)
            storedClipHistory[maxHistory + 1] = nil
        end                         -- else we can't... yet.
        storedChangeCount = pasteboard.changeCount()
    end
end

local clipboardMonitorTimer = nil

-- Public interface ------------------------------------------------------

--- hs._asm.clipmanager.monitorClipboard([state]) -> state
--- Function
--- Sets or gets the status of the clipboard monitoring process.
---
--- Parameters:
---   * state  - if present and a boolean value, then the clipboard monitor is either turned on or turned off, depending upon the value of `state`.  If it is not present, or is not a boolean value, then the current running state of the clipboard monitor is returned.
---
--- Returns:
---   * state - the current (or changed) status of the clipboard monitoring process.
module.monitorClipboard = function(state)
    if type(state) == "boolean" then
        if state then
            if not clipboardMonitorTimer then
                clipboardMonitorTimer = timer.new(pollInterval, clipboardChecker):start()
            end
        else
            if clipboardMonitorTimer then
                clipboardMonitorTimer = timer.new(pollInterval, clipboardChecker):stop()
                clipboardMonitorTimer = nil
            end
        end
    end
    return (clipboardMonitorTimer ~= nil)
end

--- hs._asm.clipmanager.historySize() -> number
--- Function
--- Returns the number of items currently in the clipboard history.
---
--- Parameters:
---   * None
---
--- Returns:
---   * The number of items currently in the clipboard history.
module.historySize = function()
    return #storedClipHistory
end

-- Return Module Object --------------------------------------------------

return module
