--- === hs._asm.module ===
---
--- Stuff about the module

local USERDATA_TAG = "hs._asm.guitk.menubar"
local module = {}

-- private variables and methods -----------------------------------------

local warnedAbout = {
    priorityConstructor = false,
    priorityMethod      = false,
    priorityTable       = false,
 -- need to think about how blatantly we want to move people off of the legacy style; don't warn for now
    legacyConstructor   = true,
}
local priorityWarning = "***** hs.menubar priority support is not supported in macOS 10.12 and newer and has been deprecated *****"
local legacyWarning   = "***** hs.menubar has been replaced with hs.menubar.statusitem, hs.menubar.menu, and hs.menubar.menu.item and this legacy wrapper may be deprecated in the future. *****"

local legacyMT = {}

legacyMT.__index = legacyMT
legacyMT.__name  = USERDATA_TAG
legacyMT.__type  = USERDATA_TAG

legacyMT.__tostring = function(self, ...) end

legacyMT.delete = function(self, ...) end
legacyMT.frame = function(self, ...) end
legacyMT.icon = function(self, ...) end
legacyMT.isInMenubar = function(self, ...) end
legacyMT.popupMenu = function(self, ...) end
legacyMT.removeFromMenuBar = function(self, ...) end
legacyMT.returnToMenuBar = function(self, ...) end
legacyMT.setClickCallback = function(self, ...) end
legacyMT.setIcon = function(self, ...) end
legacyMT.setMenu = function(self, ...) end
legacyMT.setTitle = function(self, ...) end
legacyMT.setTooltip = function(self, ...) end
legacyMT.stateImageSize = function(self, ...) end
legacyMT.title = function(self, ...) end
legacyMT.priority = function(self, ...)
    if not warnedAbout.priorityMethod then
        print(priorityWarning)
        warnedAbout.priorityMethod = true
    end

-- ... stuff here ...

end

legacyMT._frame   = legacyMT.frame
legacyMT._setIcon = legacyMT.setIcon
legacyMT.__gc     = legacyMT.delete

-- Public interface ------------------------------------------------------

module.new = function()
    if not warnedAbout.legacyConstructor then
        print(legacyWarning)
        warnedAbout.legacyConstructor = true
    end

-- ... stuff here ...

end

module.newWithPriority = function()
    if not warnedAbout.priorityConstructor then
        print(priorityWarning)
        warnedAbout.priorityConstructor = true
    end
    return module.new()
end

module.priorities = setmetatable({}, {
    __index = function(self, key)
        if not warnedAbout.priorityTable then
            print(priorityWarning)
            warnedAbout.priorityTable = true
        end
        return ({
            default            = 1000,
            notificationCenter = 2147483647,
            spotlight          = 2147483646,
            system             = 2147483645,
        })[key]
    end,
    __tostring = function(self) return priorityWarning end,
})

-- assign to the registry in case we ever need to access the metatable from the C side
debug.getregistry()[USERDATA_TAG] = legacyMT

-- Return Module Object --------------------------------------------------

return module
