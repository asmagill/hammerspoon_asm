--- === hs._asm.toolbar ===
---
--- Create and manipulate toolbars which can be attached to the Hammerspoon console or hs.webview objects.
---
--- Toolbars are attached to titled windows and provide buttons which can be used to perform various actions within the application.  Hammerspoon can use this module to add toolbars to the console or `hs.webview` objects which have a title bar (see `hs.webview.windowMasks` and `hs.webview:windowStyle`).  Toolbars are identified by a unique identifier which is used by OS X to identify information which can be auto saved in the application's user defaults to reflect changes the user has made to the toolbar button order or active button list (this requires setting [hs._asm.toolbar:autosaves](#autosaves) and [hs._asm.toolbar:canCustomize](#canCustomize) both to true).
---
--- Multiple copies of the same toolbar can be made with the [hs._asm.toolbar:copy](#copy) method so that multiple webview windows use the same toolbar, for example.  If the user customizes a copied toolbar, changes to the active buttons or their order will be reflected in all copies of the toolbar.
---
--- You cannot add items to an existing toolbar, but you can delete it and re-create it with the same identifier, adding new button items to the new instance.  If the toolbar identifier matches autosaved preferences, the new toolbar will look like it did before, but the user will be able to add the new items by customizing the toolbar or by using the [hs._asm.toolbar:insertItem](#insertItem) method.
---
--- Example:
--- ~~~lua
--- t = require("hs._asm.toolbar")
--- a = t.new("myConsole", {
---         { id = "select1", selectable = true, image = hs.image.imageFromName("NSStatusAvailable") },
---         { id = "NSToolbarSpaceItem" },
---         { id = "select2", selectable = true, image = hs.image.imageFromName("NSStatusUnavailable") },
---         { id = "notShown", default = false, image = hs.image.imageFromName("NSBonjour") },
---         { id = "NSToolbarFlexibleSpaceItem" },
---         { id = "navGroup", label = "Navigation",
---             { id = "navLeft", image = hs.image.imageFromName("NSGoLeftTemplate") },
---             { id = "navRight", image = hs.image.imageFromName("NSGoRightTemplate") }
---         },
---         { id = "NSToolbarFlexibleSpaceItem" },
---         { id = "cust", label = "customize", fn = function(t, w, i) t:customizePanel() end, image = hs.image.imageFromName("NSAdvanced") }
---     }):canCustomize(true)
---       :autosaves(true)
---       :selectedItem("select2")
---       :setCallback(function(...)
---                         print("a", inspect(table.pack(...)))
---                    end)
---
--- t.attachToolbar(a)
--- ~~~
---
local USERDATA_TAG = "hs._asm.toolbar"
local module       = require(USERDATA_TAG..".internal")

-- required for image support
require("hs.image")

-- targets we want to be able to add toolbars to
require("hs.drawing")
require("hs.webview")

local drawingMT = hs.getObjectMetatable("hs.drawing")
local webviewMT = hs.getObjectMetatable("hs.webview")

-- private variables and methods -----------------------------------------

local _kMetaTable = {}
_kMetaTable._k = setmetatable({}, {__mode = "k"})
_kMetaTable._t = setmetatable({}, {__mode = "k"})
_kMetaTable.__index = function(obj, key)
        if _kMetaTable._k[obj] then
            if _kMetaTable._k[obj][key] then
                return _kMetaTable._k[obj][key]
            else
                for k,v in pairs(_kMetaTable._k[obj]) do
                    if v == key then return k end
                end
            end
        end
        return nil
    end
_kMetaTable.__newindex = function(obj, key, value)
        error("attempt to modify a table of constants",2)
        return nil
    end
_kMetaTable.__pairs = function(obj) return pairs(_kMetaTable._k[obj]) end
_kMetaTable.__len = function(obj) return #_kMetaTable._k[obj] end
_kMetaTable.__tostring = function(obj)
        local result = ""
        if _kMetaTable._k[obj] then
            local width = 0
            for k,v in pairs(_kMetaTable._k[obj]) do width = width < #tostring(k) and #tostring(k) or width end
            for k,v in require("hs.fnutils").sortByKeys(_kMetaTable._k[obj]) do
                if _kMetaTable._t[obj] == "table" then
                    result = result..string.format("%-"..tostring(width).."s %s\n", tostring(k),
                        ((type(v) == "table") and "{ table }" or tostring(v)))
                else
                    result = result..((type(v) == "table") and "{ table }" or tostring(v)).."\n"
                end
            end
        else
            result = "constants table missing"
        end
        return result
    end
_kMetaTable.__metatable = _kMetaTable -- go ahead and look, but don't unset this

local _makeConstantsTable
_makeConstantsTable = function(theTable)
    if type(theTable) ~= "table" then
        local dbg = debug.getinfo(2)
        local msg = dbg.short_src..":"..dbg.currentline..": attempting to make a '"..type(theTable).."' into a constant table"
        if module.log then module.log.ef(msg) else print(msg) end
        return theTable
    end
    for k,v in pairs(theTable) do
        if type(v) == "table" then
            local count = 0
            for a,b in pairs(v) do count = count + 1 end
            local results = _makeConstantsTable(v)
            if #v > 0 and #v == count then
                _kMetaTable._t[results] = "array"
            else
                _kMetaTable._t[results] = "table"
            end
            theTable[k] = results
        end
    end
    local results = setmetatable({}, _kMetaTable)
    _kMetaTable._k[results] = theTable
    local count = 0
    for a,b in pairs(theTable) do count = count + 1 end
    if #theTable > 0 and #theTable == count then
        _kMetaTable._t[results] = "array"
    else
        _kMetaTable._t[results] = "table"
    end
    return results
end

-- Public interface ------------------------------------------------------

module.systemToolbarItems = _makeConstantsTable(module.systemToolbarItems)
module.itemPriorities     = _makeConstantsTable(module.itemPriorities)

drawingMT.attachToolbar = module.attachToolbar
webviewMT.attachToolbar = module.attachToolbar

-- Return Module Object --------------------------------------------------

return module
