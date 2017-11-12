--- === hs._asm.guitk.menubar ===
---
--- Stuff about the module

local USERDATA_TAG = "hs._asm.guitk.menubar"
local module       = require(USERDATA_TAG..".internal")
module.menu        = require(USERDATA_TAG..".menu")
module.menu.item   = require(USERDATA_TAG..".menuItem")


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

-- Return Module Object --------------------------------------------------

return module
