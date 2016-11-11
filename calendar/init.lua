--- === hs._asm.calendar ===
---
--- Retrieve events and reminders from the system calendars.
---
--- This module allows you to retrieve events and reminders from the calendars defined for your system.  The calendars available are those which are enabled within the Internet Accounts Preferences Panel and are accessible through the OS X Calendar application or Reminders application.
---
--- This module does not allow you to create or modify events or reminders in any of the calendars at this time.  It is uncertain if this will be added in the future or not.
---
--- The first time you attempt to access events or reminders with [hs._asm.calendar.events()](#events) or [hs._asm.calendar.reminders()](#reminders), you will be prompted to grant or deny access to Hammerspoon for the corresponding data.  Your answer will be remembered for subsequent access attempts.  You can revoke access at any time by going to the Security & Privacy Preferences Panel.
---
--- This module is very much a work in progress and may change before reaching the point of having formal documentation.

local USERDATA_TAG = "hs._asm.calendar"
local module       = require(USERDATA_TAG..".internal")
require("hs.location") -- import CLLocation conversions

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

module.events    = function(...) return module._new("events", ...) end
module.reminders = function(...) return module._new("reminders", ...) end

module.startOfDay = function(date)
    local t = os.date("*t", date or os.time())
    return os.time({ month = t.month, day = t.day, year = t.year, hour = 0 })
end

module.endOfDay = function(date)
    local t = os.date("*t", date or os.time())
    return os.time({ month = t.month, day = t.day + 1, year = t.year, hour = 0, sec = -1 })
end

module.startOfWeek = function(date)
    local t = os.date("*t", date or os.time())
    return os.time({ month = t.month, day = t.day - t.wday + 1, year = t.year, hour = 0 })
end

module.endOfWeek = function(date)
    local t = os.date("*t", date or os.time())
    return os.time({ month = t.month, day = t.day + (7 - t.wday) + 1, year = t.year, hour = 0, sec = -1 })
end

module.startOfMonth = function(date)
    local t = os.date("*t", date or os.time())
    return os.time({ month = t.month, day = 1, year = t.year, hour = 0 })
end

module.endOfMonth = function(date)
    local t = os.date("*t", date or os.time())
    return os.time({ month = t.month + 1, day = 1, year = t.year, hour = 0, sec = -1 })
end

-- Return Module Object --------------------------------------------------

return module
