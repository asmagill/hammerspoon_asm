--- === hs._asm.bonjour ===
---
--- Stuff about the module

local USERDATA_TAG = "hs._asm.bonjour"
local module       = {}
module.browser     = require(USERDATA_TAG .. ".browser")
module.service     = require(USERDATA_TAG .. ".service")

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
