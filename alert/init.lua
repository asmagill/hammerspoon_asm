--- === hs._asm.alert ===
---
--- Display warning or critical alert dialogs from within Hammerspoon
---
--- This module allows you to create warning or critical alert dialog boxes from within Hammerspoon.  These dialogs are modal (meaning that no other Hammerspoon activity can occur while they are being displayed) and are currently limited to just providing one or more buttons for user interaction. Attempts to remove or mitigate these limitations are being examined.

local USERDATA_TAG = "hs._asm.alert"
local module       = require(USERDATA_TAG..".internal")

local basePath = package.searchpath(USERDATA_TAG, package.path)
if basePath then
    basePath = basePath:match("^(.+)/init.lua$")
    if require"hs.fs".attributes(basePath .. "/docs.json") then
        require"hs.doc".registerJSONFile(basePath .. "/docs.json")
    end
end

-- load for dependancies
require("hs.image")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

-- Return Module Object --------------------------------------------------

return module
