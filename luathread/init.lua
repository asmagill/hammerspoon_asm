--- === hs._asm.luathread ===
---
--- Launch an independant lua thread from within Hammerspoon to execute non-blocking lua code.
---
--- At present, any Hammerspoon module which uses LuaSkin (i.e. most of them) will not work within the background thread, so background processing is limited to strictly Lua or LuaRock modules.  Attempting to load a Hammerspoon module which is incompatible will result in an error, but will not terminate Hammerspoon or the background thread.  Possible work arounds for at least some of the modules are being investigated.

--- === hs._asm.luathread._instance ===
---
--- This submodule provides functions within the background thread for controlling the thread and sharing data between Hammerspoon and the background thread.
---
--- When a lua thread is first created, it will look for an initialization file in your Hammerspoon configuration directory named `_init.*name*.lua`, where *name* is the name assigned to the thread when it is created.  If this file is not found, then `_init.lua` will be looked for.  If neither exist, then no custom initialization occurs.
---
--- The luathread instance is a complete lua environment with the following differences:
---
---  * `package.path` and `package.cpath` take on their current values from Hammerspoon.
---  * a special global variable named `_instance` is created and contains a userdata with methods for sharing data with Hammerspoon and returning output.  See the methods of this sub-module for specific information about these methods.
---  * a special global variable named `_sharedTable` is created as a table.  Any key-value pairs stored in this special table are shared with Hammerspoon.  See [hs._asm.luathread:sharedTable](#sharedTable) for more information about this table -- this table is the thread side of that Hammerspoon method.
---    * `_sharedTable._results` will contain a table with the following keys, updated after each submission to the thread:
---      * `start`   - a time stamp specifying the time that the submitted code was started.
---      * `stop`    - a time stamp specifying the time that the submitted code completed execution.
---      * `results` - a table containing the results as an array of the submitted code.  Like `table.pack(...)`, a keyed entry of `n` contains the number of results returned.
---  * `debug.sethook` is used within the thread to determine if the thread has been cancelled from the outside (i.e. Hammerspoon) and will terminate any lua processing within the thread immediately when this occurs.
---  * `print` within the thread has been over-ridden so that output is cached and returned to Hammerspoon (through a callback function or the [hs._asm.luathread:getOutput](#getOutput) method) once the current lua code has completed (i.e. the thread is idle).
---  * `os.exit` has been overridden to cleanly terminate the thread if/when invoked.
---  * `hs.printf`, `hs.configdir`, `hs._exit`, and `hs.execute` have been replicated.

local USERDATA_TAG = "hs._asm.luathread"
local module       = require(USERDATA_TAG..".internal")
local internal     = hs.getObjectMetatable(USERDATA_TAG)

-- private variables and methods -----------------------------------------

local threadInitFile = package.searchpath(USERDATA_TAG.."._threadinit", package.path)
local configdir      = threadInitFile:gsub("/_threadinit.lua$", "")
module._assignments({
    initfile             = threadInitFile,
    configdir            = hs.configdir,
    docstrings_json_file = hs.docstrings_json_file,
    path                 = configdir.."/?.lua"..";"..configdir.."/?/init.lua"..";"..package.path,
    cpath                = configdir.."/?.so"..";"..package.cpath,
    processInfo          = hs.processInfo,
})
module._assignments = nil -- should only be called once, then never again

-- Public interface ------------------------------------------------------

--- hs._asm.luathread:sharedTable() -> table
--- Method
--- Returns a table which uses meta methods to allow almost seamless access to the thread's shared data dictionary from Hammerspoon.
---
--- Parameters:
---  * None
---
--- Returns:
---  * a table which uses metamethods to access the thread's shared data dictionary.  Data can be shared between the thread and Hammerspoon by setting or reading key-value pairs within this table.
---
--- Notes:
---  * you can assign the result of this function to a variable and treat it like any other table to retrieve or pass data to and from the thread.  Currently only strings, numbers, boolean, and tables can be shared -- functions, threads, and userdata are not yet supported (threads and c-functions probably never will be, but purely lua functions and userdata is being looked into)
---  * because the actual data is stored in the NSThread dictionary, the lua representation is provided dynamically through metamethods.  For many uses, this distinction is unimportant, but it does have a couple of implications which should be kept in mind:
---    * if you store a table value (i.e. a sub-table or entry from the method's returned table) from the shared dictionary in another variable, you are actually capturing a copy of the data at a specific point in time; if the table contents change in the shared dictionary, your stored copy will not reflect the new changes unless you re-acquire them from this method or from the specific table that it returns.
---    * A sub-table or entry in this dynamic table is actually created each time it is accessed -- tools like `hs.inspect` have problems with this if you try to inspect the entire dictionary from its root because they rely on a specific table having a unique instance over multiple requests.  Inspecting a specific key from the returned table works as expected, however.
---
--- Consider the following code:
---
--- ~~~lua
--- shared = hs._asm.luathread:sharedTable()
--- shared.sampleTable = { 1, 2, 3, 4 }
--- hs.inspect(shared)             -- this will generate an error
--- hs.inspect(shared.sampleTable) -- this works as expected
--- ~~~
---
---    * The meta-methods provided for the returned table are: `__index`, `__newindex`, `__len`, and `__pairs`.
internal.sharedTable = function(self)
    local _sharedTable = {}
    return setmetatable(_sharedTable, {
        __index    = function(t, k) return self:get(k) end,
        __newindex = function(t, k, v) self:set(k, v) end,
        __pairs    = function(t)
            local keys, values = self:keys(), {}
            for k, v in ipairs(keys) do values[v] = self:get(v) end
            return function(t, i)
                i = table.remove(keys, 1)
                if i then
                    return i, values[i]
                else
                    return nil
                end
            end, _sharedTable, nil
        end,
        __len      = function(t)
            local len, pos = 0, 1
            while self:get(pos) do
                len = pos
                pos = pos + 1
            end
            return len
        end,
        __metatable = "shared data:"..self:name()
    })
end

-- Return Module Object --------------------------------------------------

return module
