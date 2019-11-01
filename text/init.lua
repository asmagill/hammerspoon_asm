--- === hs.text ===
---
--- Stuff about the module

local USERDATA_TAG = "hs.text"
local module       = require(USERDATA_TAG..".internal")

local textMT = hs.getObjectMetatable(USERDATA_TAG)

-- local log = require("hs.logger").new(USERDATA_TAG, require"hs.settings".get(USERDATA_TAG .. ".logLevel") or "warning")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

textMT.UTF8String = function(self, ...)
    return self:asEncoding("UTF8", ...):rawData()
end

module.encodingTypes = ls.makeConstantsTable(module.encodingTypes)

-- Return Module Object --------------------------------------------------

return module
