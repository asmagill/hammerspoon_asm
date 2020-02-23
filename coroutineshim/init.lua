--- === hs._asm.coroutineshim ===
---
--- A shim to inject methods into LuaSkin which will allow coroutine friendly modules to run on a Hammerspoon installation that does not yet have the coroutine fixes applied.
---
--- This module should be the very first thing loaded in your `init.lua` file; e.g. `require ("hs._asm.coroutineshim")`.
---
--- If you are running a coroutine friendly version of Hammerspoon, then this module does nothing. If your version of Hammerspoon is not coroutine friendly, constructor methods are inejcted into LuaSkin so that coroutine friendly modules can still be loaded. Note that this does not make a given instance of Hammerspoon any friendlier to coroutines; it just allows modules compiled against a friendly version to load in an unfriendly one.
---

local USERDATA_TAG = "hs._asm.coroutineshim"
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
