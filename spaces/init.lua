--- === hs.spaces ===
---
--- This module provides some basic functions for controlling macOS Spaces.
---
--- The functionality provided by this module is considered experimental and subject to change. By using a combination of private APIs and Accessibility hacks (via hs.axuielement), some basic functions for controlling the use of Spaces is possible with Hammerspoon, but there are some limitations and caveats.
---
--- It should be noted that while the functions provided by this module have worked for some time in third party applications and in a previous experimental module that has received limited testing over the last few years, they do utilize some private APIs which means that Apple could change them at any time.
---
--- The functions which allow you to create new spaes, remove spaces, and jump to a specific space utilize `hs.axuielement` and perform accessibility actions through the Dock application to manipulate Mission Control. Because we are essentially directing the Dock to perform User Interactions, there is some visual feedback which we cannot entirely suppress. You can minimize, but not entirely remove, this by enabling "Reduce motion" in System Preferences -> Accessibility -> Display.
---
--- It is recommended that you also enable "Displays have separate Spaces" in System Preferences -> Mission Control.
---
--- This module is a simplification of my previous `hs._asm.undocumented.spaces` module, changes inspired by reviewing the `Yabai` source, and some experimentation with `hs.axuielement`. If you require more sophisticated control, I encourage you to check out https://github.com/koekeishiya/yabai -- it does require some additional setup (changes to SIP, possibly edits to `sudoers`, etc.) but may be worth the extra steps for some power users. A Spoon supporting direct socket communication with Yabai from Hammerspoon is also being considered.

-- TODO:
-- +  fully document
-- +  goto, add, remove need update screen identification handling
-- +  displayForSpace should allow mission control name and convert to spaceID
-- +      moveWindowToSpace, windowsForSpace should be wrapped to support the same
--    add optional callback fn to gotoSpaceOnScreen and removeSpaceFromScreen
--    goto and remove should allow spaceID and convert to missionControlNameForSpace
-- *  allow screenID argument to be hs.screen object?
--    wrap displayIsAnimating?
--
--    does this work if "Displays have Separate Spaces" isn't checked in System Preferences ->
--        Mission Control? What changes, and can we work around it?
--
--    need working hs.window.filter (or replacement) for pruning windows list and making use of other space windows


-- I think we're probably done with Yabai duplication -- basic functionality desired is present, minus window id pruning
-- +  yabai supports *some* stuff on M1 without injection... investigate
-- *      move window to space               -- according to M1 tracking issue
-- +      ids of windows on other spaces     -- partial; see hs.window.filter comment above

local USERDATA_TAG = "hs.spaces"
local module       = require(USERDATA_TAG..".spacesObjc")
module.watcher     = require(USERDATA_TAG..".watcher")

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

local axuielement = require("hs.axuielement")
local application = require("hs.application")
local screen      = require("hs.screen")
local inspect     = require("hs.inspect")
local timer       = require("hs.timer")
local host        = require("hs.host")
local fs          = require("hs.fs")
local plist       = require("hs.plist")

-- private variables and methods -----------------------------------------

-- locale handling for buttons representing spaces in Mission Control

local AXExitToDesktop, AXExitToFullscreenDesktop, DesktopNum, DesktopConcat
local getDockExitTemplates = function()
    local localesToSearch = host.locale.preferredLanguages() or {}
    -- make a copy since preferredLanguages uses ls.makeConstantsTable for "friendly" display in console
    localesToSearch = table.move(localesToSearch, 1, #localesToSearch, 1, {})
    table.insert(localesToSearch, host.locale.current())
    local path   = application("Dock"):path() .. "/Contents/Resources"

    local locale = ""
    while #localesToSearch > 0 do
        locale = table.remove(localesToSearch, 1):gsub("%-", "_")
        while #locale > 0 do
            if fs.attributes(path .. "/" .. locale .. ".lproj/Accessibility.strings") then break end
            locale = locale:match("^(.-)_?[^_]+$")
        end
        if #locale > 0 then break end
    end

    if #locale == 0 then locale = "en" end -- fallback to english

    local contents = plist.read(path .. "/" .. locale .. ".lproj/Accessibility.strings")
    AXExitToDesktop           = "^" .. contents.AXExitToDesktop:gsub("%%@", "(.-)") .. "$"
    AXExitToFullscreenDesktop = "^" .. contents.AXExitToFullscreenDesktop:gsub("%%@", "(.-)") .. "$"

    contents = plist.read(path .. "/" .. locale .. ".lproj/Localizable.strings")
    DesktopNum = contents.DesktopNum
    DesktopConcat = contents["2_APP_TILED_SPACE"]
end

local localeChange_identifier = host.locale.registerCallback(getDockExitTemplates)
getDockExitTemplates() -- set initial values

local spacesNameFromButtonName = function(name)
    return name:match(AXExitToFullscreenDesktop) or name:match(AXExitToDesktop) or name
end

-- now onto the rest of the local functions
local _dockElement
local getDockElement = function()
    -- if the Dock is killed for some reason, its element will be invalid
    if not (_dockElement and _dockElement:isValid()) then
        _dockElement = axuielement.applicationElement(application("Dock"))
    end
    return _dockElement
end

local _missionControlGroup
local getMissionControlGroup = function()
    if not (_missionControlGroup and _missionControlGroup:isValid()) then
        _missionControlGroup = nil
        local dockElement = getDockElement()
        for i,v in ipairs(dockElement) do
            if v.AXIdentifier == "mc" then
                _missionControlGroup = v
                break
            end
        end
    end
    return _missionControlGroup
end

local openMissionControl = function()
    local missionControlGroup = getMissionControlGroup()
    if not missionControlGroup then hs.execute([[open -a "Mission Control"]]) end
end

local closeMissionControl = function()
    local missionControlGroup = getMissionControlGroup()
    if missionControlGroup then hs.execute([[open -a "Mission Control"]]) end
end

local findSpacesSubgroup = function(targetIdentifier, screenID)
    local missionControlGroup = getMissionControlGroup()

    local mcChildren = missionControlGroup:attributeValue("AXChildren") or {}
    local mcDisplay = table.remove(mcChildren)
    while mcDisplay do
        if mcDisplay.AXIdentifier == "mc.display" and mcDisplay.AXDisplayID == screenID then
            break
        end
        mcDisplay = table.remove(mcChildren)
    end
    if not mcDisplay then
        return nil, "no display with specified id found"
    end

    local mcDisplayChildren = mcDisplay:attributeValue("AXChildren") or {}
    local mcSpaces = table.remove(mcDisplayChildren)
    while mcSpaces do
        if mcSpaces.AXIdentifier == "mc.spaces" then
            break
        end
        mcSpaces = table.remove(mcDisplayChildren)
    end
    if not mcSpaces then
        return nil, "unable to locate mc.spaces group for display"
    end

    local mcSpacesChildren = mcSpaces:attributeValue("AXChildren") or {}
    local targetChild = table.remove(mcSpacesChildren)
    while targetChild do
        if targetChild.AXIdentifier == targetIdentifier then break end
        targetChild = table.remove(mcSpacesChildren)
    end
    if not targetChild then
        return nil, string.format("unable to find target %s for display", targetIdentifier)
    end
    return targetChild
end

-- Public interface ------------------------------------------------------


--- hs.spaces.queueTime
--- Variable
--- Specifies how long to delay completing the accessibility actions for [hs.spaces.gotoSpaceOnScreen](#gotoSpaceOnScreen) and [hs.spaces.removeSpaceFromScreen](#removeSpaceFromScreen)
---
--- Notes:
---  * this is provided as a variable so that it can be adjusted if it is determined that some configurations require significant delay. You should not need to adjust this unless you find that you are consistently getting errors when trying to use these functions.
module.queueTime = require("hs.math").minFloat

--- hs.spaces.toggleShowDesktop() -> None
--- Function
--- Toggles moving all windows on/off screen to display the desktop underneath.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * this is the same functionality as provided by the System Preferences -> Mission Control -> Hot Corners... -> Desktop setting, the Show Desktop touchbar icon, or the Show Desktop trackpad swipe gesture (Spread with thumb and three fingers).
module.toggleShowDesktop = function() module._coreDesktopNotification("com.apple.showdesktop.awake") end

--- hs.spaces.toggleMissionControl() -> None
--- Function
--- Toggles the Mission Control display
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * this is the same functionality as provided by the System Preferences -> Mission Control -> Hot Corners... -> Mission Control setting, the Mission Control touchbar icon, or the Mission Control trackpad swipe gesture (3 or 4 fingers up).
module.toggleMissionControl = function() module._coreDesktopNotification("com.apple.expose.awake") end

--- hs.spaces.toggleAppExpose() -> None
--- Function
--- Toggles the current applications Exposé display
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * this is the same functionality as provided by the System Preferences -> Mission Control -> Hot Corners... -> Application Windows setting or the App Exposé trackpad swipe gesture (3 or 4 fingers down).
module.toggleAppExpose = function() module._coreDesktopNotification("com.apple.expose.front.awake") end

--- hs.spaces.toggleLaunchPad() -> None
--- Function
--- Toggles the Launch Pad display.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * this is the same functionality as provided by the System Preferences -> Mission Control -> Hot Corners... -> Launch Pad setting, the Launch Pad touchbar icon, or the Launch Pad trackpad swipe gesture (Pinch with thumb and three fingers).
module.toggleLaunchPad = function() module._coreDesktopNotification("com.apple.launchpad.toggle") end

--- hs.spaces.openMissionControl() -> None
--- Function
--- Opens the Mission Control display
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * Does nothing if the Mission Control display is already visible.
---  * This function uses Accessibility features provided by the Dock to open up Mission Control and is used internally when performing the [hs.spaces.gotoSpaceOnScreen](#gotoSpaceOnScreen), [hs.spaces.addSpaceToScreen](#addSpaceToScreen), and [hs.spaces.removeSpaceFromScreen](#removeSpaceFromScreen) functions.
---  * It is unlikely you will need to invoke this by hand, and the public interface to this function may go away in the future.
module.openMissionControl = openMissionControl

--- hs.spaces.closeMissionControl() -> None
--- Function
--- Opens the Mission Control display
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * Does nothing if the Mission Control display is not currently visible.
---  * This function uses Accessibility features provided by the Dock to close Mission Control and is used internally when performing the [hs.spaces.gotoSpaceOnScreen](#gotoSpaceOnScreen), [hs.spaces.addSpaceToScreen](#addSpaceToScreen), and [hs.spaces.removeSpaceFromScreen](#removeSpaceFromScreen) functions.
---  * It is possible to invoke the above mentioned functions and prevent them from auto-closing Mission Control -- this may be useful if you wish to perform multiple actions and want to minimize the visual side-effects. You can then use this function when you are done.
module.closeMissionControl = closeMissionControl

--- hs.spaces.missionControlNameForSpaceID(spaceID) -> string | nil, errorMessage
--- Function
--- Returns the string specifying the Mission Control name for the spaceID provided
---
--- Parameters:
---  * `spaceID` - an integer specifying the ID of a space.
---
--- Returns:
---  * a string specifying the name used by Mission Control for the given space, or nil and an error string if the ID could not be matched to an existing space.
---
--- Notes:
---  * this function attempts to use the localization strings for the Dock application to properly determine the Mission Control name. If you find that it doesn't provide the correct values for your system, please provide the following information when submitting an issue:
---    * the desktop or application name(s) as they appear at the top of the Mission Control screen when you invoke it manually (or with `hs.spaces.toggleMissionControl()` entered into the Hammerspoon console.
---    * the output from the following commands, issued in the Hammerspoon console:
---      * `hs.host.locale.current()`
---      * `hs.inspect(hs.host.locale.preferredLanguages())`
---      * `hs.inspect(hs.host.locale.details())`
module.missionControlNameForSpaceID = function(...)
    local args, spaceID = { ... }, nil
    assert(#args == 1, "expected 1 argument")
    spaceID = args[1]
    assert(math.type(spaceID) == "integer", "expected integer specifying spaces ID")

    local spaceCounter = 0
    local managedDisplayData, errMsg = module.managedDisplaySpaces()
    if managedDisplayData == nil then return nil, errMsg end
    for _, managedDisplay in ipairs(managedDisplayData) do
        for _, space in ipairs(managedDisplay.Spaces) do
            if space.type == 0 then
                spaceCounter = spaceCounter + 1
            end
            if space.ManagedSpaceID == spaceID then
                if space.type == 0 then
                    return (DesktopNum:gsub("%%@", tostring(spaceCounter)))
                elseif space.type == 4 then
                    local pid = space.pid
                    if type(pid) ~= "table" then
                        return application.applicationForPID(pid):title()
                    else
                        local names = {}
                        local answer = DesktopConcat
                        for i, app in ipairs(pid) do
                            table.insert(names, application.applicationForPID(app):title())
                            -- take care of placeholders with index
                            answer = answer:gsub("%%" .. tostring(i) .. "%$@", names[i])
                        end
                        -- take care of non-indexed placeholders
                        local idx = 0
                        answer = answer:gsub("%%@", function(_) idx = idx + 1 ; return names[idx] end)
                        return answer
                    end
                else
                    return nil, "unknown space type or no Mission Control representation"
                end
            end
        end
    end
    return nil, "space not found in managed displays"
end

--- hs.spaces.spaceIDForMissionControlName(name) -> integer | nil, errorMessage
--- Function
--- Returns the spaceID for the space with the specified Mission Control name
---
--- Parameters:
---  * `name` - a string specifying the Mission Control name of the space
---
--- Returns:
---  * an integer specifying the ID for the space corresponding to the space with the specified Mission Control name, or nil and an error string if the name could not be matched to an existing space.
---
--- Notes:
---  * this function attempts to use the localization strings for the Dock application to properly determine the Mission Control name. If you find that it doesn't provide the correct values for your system, please provide the following information when submitting an issue:
---    * the desktop or application name(s) as they appear at the top of the Mission Control screen when you invoke it manually (or with `hs.spaces.toggleMissionControl()` entered into the Hammerspoon console.
---    * the output from the following commands, issued in the Hammerspoon console:
---      * `hs.host.locale.current()`
---      * `hs.inspect(hs.host.locale.preferredLanguages())`
---      * `hs.inspect(hs.host.locale.details())`
module.spaceIDForMissionControlName = function(...)
    local args, name = { ... }, nil
    assert(#args == 1, "expected 1 argument")
    name = args[1]
    assert(type(name) == "string", "expected string specifying space by its Mission Control Name")

    local spaceCounter = 0
    local managedDisplayData, errMsg = module.managedDisplaySpaces()
    if managedDisplayData == nil then return nil, errMsg end
    for _, managedDisplay in ipairs(managedDisplayData) do
        for _, space in ipairs(managedDisplay.Spaces) do
            local possibleName
            if space.type == 0 then
                spaceCounter = spaceCounter + 1
                possibleName = (DesktopNum:gsub("%%@", tostring(spaceCounter)))
            elseif space.type == 4 then
                local pid = space.pid
                if type(pid) ~= "table" then
                    possibleName = application.applicationForPID(pid):title()
                else
                    local names = {}
                    local answer = DesktopConcat
                    for i, app in ipairs(pid) do
                        table.insert(names, application.applicationForPID(app):title())
                        -- take care of placeholders with index
                        answer = answer:gsub("%%" .. tostring(i) .. "%$@", names[i])
                    end
                    -- take care of non-indexed placeholders
                    local idx = 0
                    answer = answer:gsub("%%@", function(_) idx = idx + 1 ; return names[idx] end)
                    possibleName = answer
                end
            end

            if possibleName and possibleName == name then return space.ManagedSpaceID end
        end
    end
    return nil, "space not found in managed displays"
end

--- hs.spaces.spacesForScreen([screen]) -> table | nil, error
--- Function
--- Returns a table containing the IDs of the spaces for the specified screen in their current order.
---
--- Parameters:
---  * `screen` - an optional screen specification identifying the screen to return the space array for. The screen may be specified by it's ID (`hs.screen:id()`), it's UUID (`hs.screen:getUUID()`), or as an `hs.screen` object. If no screen is specified, the screen returned by `hs.screen.mainScreen()` is used.
---
--- Returns:
---  * a table containing space IDs for the spaces for the screen, or nil and an error message if there is an error.
---
--- Notes:
---  * the table returned has its __tostring metamethod set to `hs.inspect` to simplify inspecting the results when using the Hammerspoon Console.
module.spacesForScreen = function(...)
    local args, screenID = { ... }, nil
    assert(#args <= 1, "expected no more than 1 argument")
    if #args > 0 then screenID = args[1] end
    if screenID == nil then
        screenID = screen.mainScreen():getUUID()
    elseif type(screenID) == "userdata" and getmetatable(screenID) == hs.getObjectMetatable("hs.screen") then
        screenID = screenID:getUUID()
    elseif math.type(screenID) == "integer" then
        for _,v in ipairs(screen.allScreens()) do
            if v:id() == screenID then
                screenID = v:getUUID()
                break
            end
        end
        if math.type(screenID) == "integer" then error("not a valid screen ID") end
    elseif not (type(screenID) == "string" and #screenID == 36) then
        error("screen must be specified as UUID, screen ID, or hs.screen object")
    end

    local managedDisplayData, errMsg = module.managedDisplaySpaces()
    if managedDisplayData == nil then return nil, errMsg end
    for _, managedDisplay in ipairs(managedDisplayData) do
        if managedDisplay["Display Identifier"] == screenID then
            local results = {}
            for _, space in ipairs(managedDisplay.Spaces) do
                table.insert(results, space.ManagedSpaceID)
            end
            return setmetatable(results, { __tostring = inspect })
        end
    end
    return nil, "screen not found in managed displays"
end

--- hs.spaces.allSpaces() -> table | nil, error
--- Function
--- Returns a Kay-Value table contining the IDs of all spaces for all screens.
---
--- Parameters:
---  * None
---
--- Returns:
---  * a key-value table in which the keys are the UUIDs for the current screens and the value for each key is a table of space IDs corresponding to the spaces for that screen. Returns nil and an error message if an error occurs.
---
--- Notes:
---  * the table returned has its __tostring metamethod set to `hs.inspect` to simplify inspecting the results when using the Hammerspoon Console.
module.allSpaces = function(...)
    local results = {}
    for _, v in ipairs(screen.allScreens()) do
        local screenID = v:getUUID()
        local spacesForScreen, errMsg = module.spacesForScreen(screenID)
        if not spacesForScreen then
            return nil, string.format("%s for %s", errMsg, screenID)
        end
        results[screenID] = spacesForScreen
    end
    return setmetatable(results, { __tostring = inspect })
end

--- hs.spaces.activeSpaceOnScreen([screen]) -> integer | nil, error
--- Function
--- Returns the currently visible (active) space for the specified screen.
---
--- Parameters:
---  * `screen` - an optional screen specification identifying the screen to return the active space for. The screen may be specified by it's ID (`hs.screen:id()`), it's UUID (`hs.screen:getUUID()`), or as an `hs.screen` object. If no screen is specified, the screen returned by `hs.screen.mainScreen()` is used.
---
--- Returns:
---  * an integer specifying the ID of the space displayed, or nil and an error message if an error occurs.
module.activeSpaceOnScreen = function(...)
    local args, screenID = { ... }, nil
    assert(#args <= 1, "expected no more than 1 argument")
    if #args > 0 then screenID = args[1] end
    if screenID == nil then
        screenID = screen.mainScreen():getUUID()
    elseif type(screenID) == "userdata" and getmetatable(screenID) == hs.getObjectMetatable("hs.screen") then
        screenID = screenID:getUUID()
    elseif math.type(screenID) == "integer" then
        for _,v in ipairs(screen.allScreens()) do
            if v:id() == screenID then
                screenID = v:getUUID()
                break
            end
        end
        if math.type(screenID) == "integer" then error("not a valid screen ID") end
    elseif not (type(screenID) == "string" and #screenID == 36) then
        error("screen must be specified as UUID, screen ID, or hs.screen object")
    end

    local managedDisplayData, errMsg = module.managedDisplaySpaces()
    if managedDisplayData == nil then return nil, errMsg end
    for _, managedDisplay in ipairs(managedDisplayData) do
        if managedDisplay["Display Identifier"] == screenID then
            for _, space in ipairs(managedDisplay.Spaces) do
                if space.ManagedSpaceID == managedDisplay["Current Space"].ManagedSpaceID then
                    return space.ManagedSpaceID
                end
            end
            return nil, "space not found in specified display"
        end
    end
    return nil, "screen not found in managed displays"
end

--- hs.spaces.activeSpaces() -> table | nil, error
--- Function
--- Returns a key-value table specifying the active spaces for all screens.
---
--- Parameters:
---  * None
---
--- Returns:
---  * a key-value table in which the keys are the UUIDs for the current screens and the value for each key is the space ID of the active space for that display.
---
--- Notes:
---  * the table returned has its __tostring metamethod set to `hs.inspect` to simplify inspecting the results when using the Hammerspoon Console.
module.activeSpaces = function(...)
    local results = {}
    for _, v in ipairs(screen.allScreens()) do
        local screenID = v:getUUID()
        local activeSpaceID, activeSpaceName = module.activeSpaceOnScreen(screenID)
        if not activeSpaceID then
            return nil, string.format("%s for %s", activeSpaceName, screenID)
        end
        results[screenID] = activeSpaceID
    end
    return setmetatable(results, { __tostring = inspect })
end

--- hs.spaces.displayForSpace(space) -> string | nil, error
--- Function
--- Returns the screen UUID for the screen that the specified space is on.
---
--- Parameters:
---  * `space` - an integer specifying the ID of the space, or a string specifying the Mission Control name for the space
---
--- Returns:
---  * a string specifying the UUID of the display the space is on, or nil and error message if an error occurs.
---
--- Notes:
---  * the space does not have to be currently active (visible) to determine which screen the space belongs to.
module.displayForSpace = function(...)
    local args, spaceID = { ... }, nil
    assert(#args == 1, "expected 1 argument")
    spaceID = args[1]
    if type(spaceID) == "string" then spaceID = module.spaceIDForMissionControlName(spaceID) or spaceID end
    assert(math.type(spaceID) == "integer", "expected integer specifying spaces ID")

    local managedDisplayData, errMsg = module.managedDisplaySpaces()
    if managedDisplayData == nil then return nil, errMsg end
    for _, managedDisplay in ipairs(managedDisplayData) do
        for _, space in ipairs(managedDisplay.Spaces) do
            if space.ManagedSpaceID == spaceID then
                return managedDisplay["Display Identifier"]
            end
        end
    end
    return nil, "space not found in managed displays"
end

-- documented in spacesObjc.m where the core logic of the function resides
local _moveWindowToSpace = module.moveWindowToSpace
module.moveWindowToSpace = function(...)
    local args = { ... }
    if #args == 2 then
        if type(args[1]) == "userdata" and getmetatable(args[1]) == hs.getObjectMetatable("hs.window") then
            args[1] = args[1]:id()
        end
        if type(args[2]) == "string" then
            args[2] = module.spaceIDForMissionControlName(args[2]) or args[2]
        end
    end
    return _moveWindowToSpace(table.unpack(args))
end

-- documented in spacesObjc.m where the core logic of the function resides
local _windowsForSpace = module.windowsForSpace
module.windowsForSpace = function(...)
    local args = { ... }
    if #args == 1 and type(args[1]) == "string" then
        args[1] = module.spaceIDForMissionControlName(args[1]) or args[1]
    end
    return _windowsForSpace(table.unpack(args))
end

-- documented in spacesObjc.m where the core logic of the function resides
local _windowSpaces = module.windowSpaces
module.windowSpaces = function(...)
    local args = { ... }
    if #args == 1 and type(args[1]) == "userdata" and getmetatable(args[1]) == hs.getObjectMetatable("hs.window") then
        args[1] = args[1]:id()
    end
    return _windowSpaces(table.unpack(args))
end

-- addSpaceToScreen([screenID], [closeMCOnCompletion]) -> true | nil, errMsg
-- adds space to specified (or main) screen
module.addSpaceToScreen = function(...)
    local args, screenID, closeMC = { ... }, nil, true
    assert(#args <= 2, "expected no more than 2 arguments")
    if #args == 1 then
        if type(args[1]) ~= "boolean" then
            screenID = args[1]
        else
            closeMC = args[1]
        end
    elseif #args > 1 then
        screenID, closeMC = table.unpack(args)
    end
    if screenID == nil then
        screenID = screen.mainScreen():id()
    elseif type(screenID) == "userdata" and getmetatable(screenID) == hs.getObjectMetatable("hs.screen") then
        screenID = screenID:id()
    elseif type(screenID) == "string" and #screenID == 36 then
        for _,v in ipairs(screen.allScreens()) do
            if v:getUUID() == screenID then
                screenID = v:id()
                break
            end
        end
    end
    assert(math.type(screenID) == "integer", "screen id must be an integer")
    assert(type(closeMC) == "boolean", "close flag must be boolean")

    openMissionControl()
    local mcSpacesAdd, errMsg = findSpacesSubgroup("mc.spaces.add", screenID)
    if not mcSpacesAdd then
        if closeMC then closeMissionControl() end
        return nil, errMsg
    end

    local status, errMsg2 = mcSpacesAdd:doAXPress()

    if closeMC then closeMissionControl() end
    if status then
        return true
    else
        return nil, errMsg2
    end
end

-- ** THESE PROBABLY SHOULD HAVE AN OPTIONAL CALLBACK FOR CHAINING MULTIPLE ACTIONS **

-- gotoSpaceOnScreen(target, [screenID], [closeMCOnCompletion]) -> true | nil, errMsg
-- goes to the specified screen (names compared with string.match) on the specified (or main) screen
--
-- * requires delayed firing of button press via timer, so probably should add callback fn to allow
-- specifying followup commands.
-- * closeMCOnCompletion ignored on success -- going to a new space forces closing Mission Control
-- * because of delayed triggering, Mission Control may be visible for more than a second; we can't avoid this, but it's still better than killing the Dock
module.gotoSpaceOnScreen = function(...)
    local args, target, screenID, closeMC = { ... }, nil, nil, true
    assert(#args >= 1 and #args <= 3, "expected between 1 and 3 arguments")
    if #args < 3 then
        target = args[1]
        if #args == 2 then
            if type(args[2]) ~= "boolean" then
                screenID = args[2]
            else
                closeMC = args[2]
            end
        end
    else
        target, screenID, closeMC = table.unpack(args)
    end
    target = tostring(target)
    if screenID == nil then
        screenID = screen.mainScreen():id()
    elseif type(screenID) == "userdata" and getmetatable(screenID) == hs.getObjectMetatable("hs.screen") then
        screenID = screenID:id()
    elseif type(screenID) == "string" and #screenID == 36 then
        for _,v in ipairs(screen.allScreens()) do
            if v:getUUID() == screenID then
                screenID = v:id()
                break
            end
        end
    end
    assert(math.type(screenID) == "integer", "screen id must be an integer")
    assert(type(closeMC) == "boolean", "close flag must be boolean")

    openMissionControl()
    local mcSpacesList, errMsg = findSpacesSubgroup("mc.spaces.list", screenID)
    if not mcSpacesList then
        if closeMC then closeMissionControl() end
        return nil, errMsg
    end

    for _, child in ipairs(mcSpacesList) do
        local childName = spacesNameFromButtonName(child.AXDescription)
        if childName:match(target) then
            local tmr
            tmr = timer.doAfter(module.queueTime, function()
                tmr = nil -- make it an upvalue
                local status, errMsg2 = child:doAXPress()
                if not status then print(status, errMsg2) end
                if closeMC then closeMissionControl() end
            end)
            return true
        end
    end

    if closeMC then closeMissionControl() end
    return nil, string.format("unable to find space matching '%s' on display", target)
end

-- removeSpaceFromScreen(target, [screenID], [closeMCOnCompletion]) -> true | nil, errMsg
-- removes the specified screen (names compared with string.match) on the specified (or main) screen
--
-- * requires delayed firing of button press via timer, so probably should add callback fn to allow
-- specifying followup commands.
-- * because of delayed triggering, Mission Control may be visible for more than a second; we can't avoid this, but it's still better than killing the Dock
module.removeSpaceFromScreen = function(...)
    local args, target, screenID, closeMC = { ... }, nil, nil, true
    assert(#args >= 1 and #args <= 3, "expected between 1 and 3 arguments")
    if #args < 3 then
        target = args[1]
        if #args == 2 then
            if type(args[2]) ~= "boolean" then
                screenID = args[2]
            else
                closeMC = args[2]
            end
        end
    else
        target, screenID, closeMC = table.unpack(args)
    end
    target = tostring(target)
    if screenID == nil then
        screenID = screen.mainScreen():id()
    elseif type(screenID) == "userdata" and getmetatable(screenID) == hs.getObjectMetatable("hs.screen") then
        screenID = screenID:id()
    elseif type(screenID) == "string" and #screenID == 36 then
        for _,v in ipairs(screen.allScreens()) do
            if v:getUUID() == screenID then
                screenID = v:id()
                break
            end
        end
    end
    assert(math.type(screenID) == "integer", "screen id must be an integer")
    assert(type(closeMC) == "boolean", "close flag must be boolean")

    openMissionControl()
    local mcSpacesList, errMsg = findSpacesSubgroup("mc.spaces.list", screenID)
    if not mcSpacesList then
        if closeMC then closeMissionControl() end
        return nil, errMsg
    end

    for _, child in ipairs(mcSpacesList) do
        local childName = spacesNameFromButtonName(child.AXDescription)
        if childName:match(target) then
            local tmr
            tmr = timer.doAfter(module.queueTime, function()
                tmr = nil -- make it an upvalue
                local status, errMsg2 = child:performAction("AXRemoveDesktop")
                if not status then print(status, errMsg2) end
                if closeMC then closeMissionControl() end
            end)
            return true
        end
    end

    if closeMC then closeMissionControl() end
    return nil, string.format("unable to find space matching '%s' on display", target)
end

-- Return Module Object --------------------------------------------------

return setmetatable(module, {
    __gc = function(_)
        host.locale.unregisterCallback(localeChange_identifier)
    end
})
