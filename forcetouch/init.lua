--- === hs._asm.forcetouch ===
---
--- Some experimentation with force touch devices.
---
--- Requires 10.11 or later.
--- Based in part on code from https://eternalstorms.wordpress.com/2015/11/16/how-to-detect-force-touch-capable-devices-on-the-mac/ and https://github.com/eternalstorms/NSBeginAlertSheet-using-Blocks.

local USERDATA_TAG = "hs._asm.forcetouch"
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

-- Return Module Object --------------------------------------------------

return module
