--- === hs._asm.module ===
---
--- Stuff about the module

local USERDATA_TAG = "hs._asm.canvas.matrix"
local module       = require(USERDATA_TAG.."_internal")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

-- store this in the registry so we can easily set it both from Lua and from C functions
debug.getregistry()[USERDATA_TAG] = {
    __type  = USERDATA_TAG,
    __index = module,
    __tostring = function(_)
        return string.format("[ % 10.4f % 10.4f 0 ]\n[ % 10.4f % 10.4f 0 ]\n[ % 10.4f % 10.4f 1 ]",
            _.m11, _.m12, _.m21, _.m22, _.tX, _.tY)
    end,
}

-- Return Module Object --------------------------------------------------

return module
