--- === hs._asm.guitk.menubar ===
---
--- Stuff about the module

local USERDATA_TAG = "hs._asm.guitk.menubar"
local module       = require(USERDATA_TAG..".internal")
module.menu        = require(USERDATA_TAG..".menu")
module.menu.item   = require(USERDATA_TAG..".menuItem")

local objectMT   = hs.getObjectMetatable(USERDATA_TAG)
local menuMT     = hs.getObjectMetatable(USERDATA_TAG..".menu")
local menuItemMT = hs.getObjectMetatable(USERDATA_TAG..".menu.item")

require("hs.drawing.color")
require("hs.image")
require("hs.styledtext")
require("hs.sound")

local basePath = package.searchpath(USERDATA_TAG, package.path)
if basePath then
    basePath = basePath:match("^(.+)/init.lua$")
    if require"hs.fs".attributes(basePath .. "/docs.json") then
        require"hs.doc".registerJSONFile(basePath .. "/docs.json")
    end
end

-- local log = require("hs.logger").new(USERDATA_TAG, require"hs.settings".get(USERDATA_TAG .. ".logLevel") or "warning")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

module.menu.item._characterMap = ls.makeConstantsTable(module.menu.item._characterMap)

local _originalMenuItemMTkeyEquivalent = menuItemMT.keyEquivalent
menuItemMT.keyEquivalent = function(self, ...)
    local args = table.pack(...)
    if args.n == 0 then
        local answer = _originalMenuItemMTkeyEquivalent(self)
        for k, v in pairs(module.menu.item._characterMap) do
            if answer == v then
                answer = k
                break
            end
        end
        return answer
    elseif args.n == 1 and type(args[1]) == "string" then
        local choice = args[1]
        for k, v in pairs(module.menu.item._characterMap) do
            if choice:lower() == k then
                choice = v
                break
            end
        end
        return _originalMenuItemMTkeyEquivalent(self, choice)
    else
        return _originalMenuItemMTkeyEquivalent(self, ...) -- allow normal error to occur
    end
end

-- Return Module Object --------------------------------------------------

return module
