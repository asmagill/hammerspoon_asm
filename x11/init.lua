--- === hs.window.x11 ===
---
--- Add support for X11 windows to Hamemrspoon. This is a work in progress and will likely be limited in comparison to the full gamut of `hs.window` functions and methods.
---
--- Based primarily on the ShiftIt code found at https://github.com/fikovnik/ShiftIt/blob/master/ShiftIt/X11WindowDriver.m

local USERDATA_TAG = "hs.window.x11"
local module       = require(USERDATA_TAG..".internal")

local basePath = package.searchpath(USERDATA_TAG, package.path)
if basePath then
    basePath = basePath:match("^(.+)/init.lua$")
    if require"hs.fs".attributes(basePath .. "/docs.json") then
        require"hs.doc".registerJSONFile(basePath .. "/docs.json")
    end
end

-- settings with periods in them can't be watched via KVO with hs.settings.watchKey, so
-- in general it's a good idea not to include periods
local SETTINGS_TAG = USERDATA_TAG:gsub("%.", "_")
local settings     = require("hs.settings")
local log          = require("hs.logger").new(USERDATA_TAG, settings.get(SETTINGS_TAG .. "_logLevel") or "warning")

local window  = require("hs.window")
local inspect = require("hs.inspect")

-- private variables and methods -----------------------------------------

local _X11LibPaths = {
    "/opt/X11/lib/libX11.6.dylib",   -- XQuartz
    "/opt/local/lib/libX11.6.dylib", -- MacPorts
    "/sw/X11/lib/libX11.6.dylib",    -- Fink?
    "/usr/local/X11/libX11.6.dylib", -- anyone?
}
local _savedX11LibPath = settings.get(SETTINGS_TAG .. "_libPath")
if _savedX11LibPath then table.insert(_X11LibPaths, 1, _savedX11LibPath) end

local libraryLoaded = false
for _, path in ipairs(_X11LibPaths) do
    local ok, msg = module._loadLibrary(path)
    if ok then
        log.f("X11 library loaded from %s", path)
        libraryLoaded = ok
        break
    else
        log.f("error loading %s: %s", path, msg)
    end
end
if not libraryLoaded then
    log.wf("No valid X11 library found in search paths: %s", inspect(_X11LibPaths))
end

module._setLoggerRef(log)

-- Public interface ------------------------------------------------------

module.specifyLibraryPath = function(path)
    assert(type(path) == "string", "path must be specified as a string")
    -- this will be true if a library is already loaded
    local testOnly = module._loadLibrary()
    local ok, msg = module._loadLibrary(path, testOnly)
    if ok then
        hs.printf("%s specifies valid library, saving as default", path)
        settings.set(SETTINGS_TAG .. "_libPath", path)
        if testOnly then
            print("You will need to restart Hammerspoon for the new library to be loaded.")
        else
            libraryLoaded = ok
            print("The new library has been loaded and the module is now fully functional.")
        end
        return true
    else
        return false, msg
    end
end

--- hs.window.animationDuration (number)
--- hs.window.desktop() -> hs.window object
--- hs.window.allWindows() -> list of hs.window objects
--- hs.window.visibleWindows() -> list of hs.window objects
--- hs.window.invisibleWindows() -> list of hs.window objects
--- hs.window.minimizedWindows() -> list of hs.window objects
--- hs.window.orderedWindows() -> list of hs.window objects
--- hs.window.get(hint) -> hs.window object
--- hs.window.find(hint) -> hs.window object(s)
--- hs.window.setFrameCorrectness
--- hs.window.frontmostWindow() -> hs.window object

--- hs.window:isVisible() -> boolean
--- hs.window:setFrame(rect[, duration]) -> hs.window object
--- hs.window:setFrameWithWorkarounds(rect[, duration]) -> hs.window object
--- hs.window:setFrameInScreenBounds([rect][, duration]) -> hs.window object
--- hs.window:frame() -> hs.geometry rect
--- hs.window:otherWindowsSameScreen() -> list of hs.window objects
--- hs.window:otherWindowsAllScreens() -> list of hs.window objects
--- hs.window:focus() -> hs.window object
--- hs.window:sendToBack() -> hs.window object
--- hs.window:maximize([duration]) -> hs.window object
--- hs.window:toggleFullScreen() -> hs.window object
--- hs.window:screen() -> hs.screen object
--- hs.window:windowsToEast([candidateWindows[, frontmost[, strict]]]) -> list of hs.window objects
--- hs.window:windowsToWest([candidateWindows[, frontmost[, strict]]]) -> list of hs.window objects
--- hs.window:windowsToNorth([candidateWindows[, frontmost[, strict]]]) -> list of hs.window objects
--- hs.window:windowsToSouth([candidateWindows[, frontmost[, strict]]]) -> list of hs.window objects
--- hs.window:focusWindowEast([candidateWindows[, frontmost[, strict]]]) -> boolean
--- hs.window:focusWindowWest([candidateWindows[, frontmost[, strict]]]) -> boolean
--- hs.window:focusWindowNorth([candidateWindows[, frontmost[, strict]]]) -> boolean
--- hs.window:focusWindowSouth([candidateWindows[, frontmost[, strict]]]) -> boolean
--- hs.window:centerOnScreen([screen][, ensureInScreenBounds][, duration]) --> hs.window object
--- hs.window:moveToUnit(unitrect[, duration]) -> hs.window object
--- hs.window:moveToScreen(screen[, noResize, ensureInScreenBounds][, duration]) -> hs.window object
--- hs.window:move(rect[, screen][, ensureInScreenBounds][, duration]) --> hs.window object
--- hs.window:moveOneScreenEast([noResize, ensureInScreenBounds][, duration]) -> hs.window object
--- hs.window:moveOneScreenWest([noResize, ensureInScreenBounds][, duration]) -> hs.window object
--- hs.window:moveOneScreenNorth([noResize, ensureInScreenBounds][, duration]) -> hs.window object
--- hs.window:moveOneScreenSouth([noResize, ensureInScreenBounds][, duration]) -> hs.window object

-- Return Module Object --------------------------------------------------

return module
