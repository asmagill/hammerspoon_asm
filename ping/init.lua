--- === hs.network.ping ===
---
--- This sub-module provides functions to use ICMP send and receive messages to test host availability.

local USERDATA_TAG = "hs.network.ping"
local module       = require(USERDATA_TAG..".internal")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

-- Return Module Object --------------------------------------------------

return module
