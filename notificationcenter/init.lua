--- === hs._asm.notificationcenter ===
---
--- Listen to notifications sent by the operating system, other applications, and within Hammerspoon itself.
---
--- This module allows creating observers for the various notification centers common in the Macintosh OS:
---
---  * The Distributed Notification Center is used to send messages between different tasks (applications) or to post notifications that may be of interest to other applications.
---  * The Share Workspace Notification Center is used by the operating system to send messages about system events, such as changes in the currently active applications, screens, sleep, etc.
---  * The Hammerspoon Application Notification Center provides a means for objects and threads within Hammerspoon itself to pass messages and information back and forth.  Currently this is read-only, so it's use is somewhat limited, but this may change in the future.
---
--- Many of the Hammerspoon module watchers use more narrowly targeted versions of the same code used in this module.  Usually they have been designed for their specific uses and include any additional support which may be needed to interpret or act on the notifications.  This module provides a more basic interface for accessing messages but can be useful for messages which are unique to your specific Application set or are new to the Mac OS, or just not yet understood or desired by enough users to merit formal inclusion in Hammerspoon.
---
--- This module is compatible with both Hammerspoon itself and the threaded lua instances provided in by `hs._asm.luathread` module.  No changes to your own lua code is required for use of this module in either environment.
---
--- This module is based partially on code from the previous incarnation of Mjolnir by [Steven Degutis](https://github.com/sdegutis/).

local module = require("hs._asm.notificationcenter.internal")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

-- Return Module Object --------------------------------------------------

return module

