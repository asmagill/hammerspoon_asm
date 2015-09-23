--- === hs.keychain ===
---
--- Functions for module
---
--- A description of module.
-- package.loadlib(package.searchpath("hs.keychain.SSKeychainQuery", package.cpath), "*")
-- package.loadlib(package.searchpath("hs.keychain.SSKeychain",      package.cpath), "*")
local module      = require("hs.keychain.internal")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

-- Return Module Object --------------------------------------------------

return module
