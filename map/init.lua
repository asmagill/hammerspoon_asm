--- === hs._asm.module ===
---
--- Functions for module
---
--- A description of module.

package.loadlib("/System/Library/Frameworks/MapKit.framework/Resources/BridgeSupport/MapKit.dylib","*")
local module      = require("hs._asm.map.internal")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

-- Return Module Object --------------------------------------------------

return module
