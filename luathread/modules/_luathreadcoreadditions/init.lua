-- some stuff from the core hs module and hs._coresetup that don't easily fit
-- in the _threadinit.lua file or require additional compiled code.

local USERDATA_TAG = "hs._luathreadcoreadditions"
local module       = require(USERDATA_TAG..".internal")

if not hs then hs = {} end -- shouldn't be necessary, but lets be safe
for i,v in pairs(module) do
    if hs[i] then
        error("hs."..i.." already exists in hs!")
    else
        hs[i] = v
    end
end

return module
