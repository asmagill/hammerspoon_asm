--- === hs.fenestra ===
---
--- In architecture, a window-like opening. A basic container within which complex windows and graphical elements can be combined.
---
--- This module provides a basic container within which Hammerspoon can build more complex windows and graphical elements. The approach taken with this module is to create a "window" or rectangular space within which a content manager from one of the submodules of `hs.fenestra` can be assigned. Canvas, WebView, and other visual or GUI elements can then be assigned to the content manager and will be positioned and auto-arranged as determined by the rules governing the chosen manager.
---
--- This approach allows concentrating the common code necessary for managing macOS window and panel containers in one place while leveraging content view managers within macOS to easily encorporate different GUI elements. This will allow the creation of significantly more complex and varied displays and input mechanisms than are currently difficult or impossible to create with just `hs.canvas` or `hs.webview`.
---
--- This is a work in progress and is still extremely experimental.

local USERDATA_TAG = "hs.fenestra"
local module       = require(USERDATA_TAG..".internal")

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

module.behaviors     = ls.makeConstantsTable(module.behaviors)
module.levels        = ls.makeConstantsTable(module.levels)
module.masks         = ls.makeConstantsTable(module.masks)
module.notifications = ls.makeConstantsTable(module.notifications)

-- Return Module Object --------------------------------------------------

return module
