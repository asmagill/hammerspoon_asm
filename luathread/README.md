hs._asm.luathread
=================

Launch an independant lua thread from within Hammerspoon to execute non-blocking lua code.

At present, any Hammerspoon module which uses LuaSkin (i.e. most of them) will not work within the background thread without modification, so background processing is limited to strictly Lua, LuaRock modules, and the few modules which have been modified in the `modules/` sub-directory.  Attempting to load a Hammerspoon module which is incompatible will result in an error, but will not terminate Hammerspoon or the background thread.  For a list of what is currently supported, check `SupportedHammerspoonModules.md`.

### Installation

A compiled version of this module can (usually) be found in this folder named `luathread-vX.Y.tar.gz` .  You can download the release and install it by expanding it in your `~/.hammerspoon/` directory (or any other directory in your `package.path` and `package.cpath` search paths):

The v0.2 bundle is the first to provide experimental support for some LuaSkin based Hammerspoon modules.  Adding this support does require changes (usually minor) to the module, so only those modules which make the most sense in a background thread are likely to be converted.  If you have specific requests, or wish to submit your own modified modules, please feel free to do so.  I will keep the binary bundle up to date as changes occur.

~~~bash
cd ~/.hammerspoon
tar -xzf ~/Downloads/luathread-vX.Y.tar.gz # or wherever your downloads are saved
~~~

If this doesn't work for you, or you want to build the latest and greatest, follow the directions below:

This does require that you have XCode or the XCode Command Line Tools installed.  See the App Store application or https://developer.apple.com to install these if necessary.

~~~bash
$ git clone https://github.com/asmagill/hammerspoon_asm
$ cd hammerspoon_asm/luathread
$ [HS_APPLICATION=/Applications] [PREFIX=~/.hammerspoon] make install
~~~

If Hammerspoon.app is in your /Applications folder, you may leave `HS_APPLICATION=/Applications` out and if you are fine with the module being installed in your Hammerspoon configuration directory, you may leave `PREFIX=~/.hammerspoon` out as well.  For most people, it will probably be sufficient to just type `make install`.

In either case, if you are upgrading over a previous installation of this module, you must completely quit and restart Hammerspoon before the new version will be fully recognized.

### Usage
~~~lua
luathread = require("hs._asm.luathread")
~~~

### Module Constructors

<a name="new"></a>
~~~lua
luathread.new([name]) -> threadObj
~~~
Create a new lua thread instance.

Parameters:
 * name - an optional name for the thread instance.  If no name is provided, a randomly generated one is used.

Returns:
 * the thread object

Notes:
 * the name does not have to be unique.  If a file with the name `_init.*name*.lua` is located in the users Hammerspoon configuration directory (`~/.hammerspoon` by default), then it will be executed at thread startup.

### Module Methods

<a name="cancel"></a>
~~~lua
luathread:cancel([_, close]) -> threadObject
~~~
Cancel the lua thread, interrupting any lua code currently executing on the thread.

Parameters:
 * The first argument is always ignored
 * if two arguments are specified, the true/false value of the second argument is used to indicate whether or not the lua thread should exit cleanly with a formal lua_close (i.e. `__gc` metamethods will be invoked) or if the thread should just stop with no formal close.  Defaults to true (i.e. perform the formal close).

Returns:
 * the thread object

Notes:
 * the two argument format specified above is included to follow the format of the lua builtin `os.exit` function.

- - -

<a name="flush"></a>
~~~lua
luathread:flush() -> threadObject
~~~
Clears the output buffer.

Parameters:
 * None

Returns:
 * the thread object

- - -

<a name="get"></a>
~~~lua
luathread:get([key]) -> value
~~~
Get the value for a keyed entry from the shared thread dictionary for the lua thread.

Parameters:
 * key - an optional key specifying the specific entry in the shared dictionary to return a value for.  If no key is specified, returns the entire shared dictionary as a table.

Returns:
 * the value of the specified key.

Notes:
 * If the key does not exist, then this method returns nil.
 * This method is used in conjunction with [hs._asm.luathread:set](#set) to pass data back and forth between the thread and Hammerspoon.
 * see also [hs._asm.luathread:sharedTable](#sharedTable)

- - -

<a name="getOutput"></a>
~~~lua
luathread:getOutput([cached]) -> string
~~~
Returns the output currently available from the last submission to the lua thread.

Parameters:
 * cached - a boolean value, defaulting to false, indicating whether the function should return the output currently cached by the thread but not yet submitted because the lua code is still executing (true) or whether the function should return the output currently in the completed output buffer.

Returns:
 * a string containing the output specified

Notes:
 * this method does not clear the output buffer; see [hs._asm.luathread:flush](#flush).
 * if you are using a callback function, this method will return an empty string when `cached` is not set or is false.  You can still set `cached` to true to check on the output of a long running lua process, however.

- - -

<a name="isExecuting"></a>
~~~lua
luathread:isExecuting() -> boolean
~~~
Determines whether or not the thread is executing or if execution has ended.

Parameters:
 * None

Returns:
 * a boolean indicating whether or not the thread is still active.

- - -

<a name="isIdle"></a>
~~~lua
luathread:isIdle() -> boolean
~~~
Determines whether or not the thread is currently busy executing Lua code.

Parameters:
 * None

Returns:
 * a boolean indicating whether or not the thread is executing Lua code.

Notes:
 * if you are not using a callback function, you can periodically check this value to determine if submitted lua code has completed so you know when to check the results or output with [hs._asm.luathread:getOutput](#getOutput).

- - -

<a name="keys"></a>
~~~lua
luathread:keys() -> table
~~~
Returns the names of all keys that currently have values in the shared dictionary of the lua thread.

Parameters:
 * None

Returns:
 * a table containing the names of the keys as an array

Notes:
 * see also [hs._asm.luathread:get](#get) and [hs._asm.luathread:set](#set)

- - -

<a name="name"></a>
~~~lua
luathread:name() -> string
~~~
Returns the name assigned to the lua thread.

Parameters:
 * None

Returns:
 * the name specified or dynamically assigned at the time of the thread's creation.

- - -

<a name="set"></a>
~~~lua
luathread:set(key, value) -> threadObject
~~~
Set the value for a keyed entry in the shared thread dictionary for the lua thread.

Parameters:
 * key   - a key specifying the specific entry in the shared dictionary to set the value of.
 * value - the value to set the key to.  May be `nil` to clear or remove a key from the shared dictionary.

Returns:
 * the value of the specified key.

Notes:
 * This method is used in conjunction with [hs._asm.luathread:get](#get) to pass data back and forth between the thread and Hammerspoon.
 * see also [hs._asm.luathread:sharedTable](#sharedTable)

- - -

<a name="setCallback"></a>
~~~lua
luathread:setCallback(function | nil) -> threadObject
~~~
Set or remove a callback function to be invoked when the thread has completed executing lua code.

Parameters:
 * a function, to set or change the callback function, or nil to remove the callback function.

Returns:
 * the thread object

Notes:
 * The callback function will be invoked whenever the lua thread goes idle (i.e. is not executing lua code) or when [hs._asm.luathread._instance:flush](#flush2) is invoked from within executing lua code in the thread.
 * the callback function should expect two arguments and return none: the thread object and a string containing all output cached since the callback function was last invoked or the output queue was last cleared with [hs._asm.luathread:flush](#flush).

- - -

<a name="sharedTable"></a>
~~~lua
luathread:sharedTable() -> table
~~~
Returns a table which uses meta methods to allow almost seamless access to the thread's shared data dictionary from Hammerspoon.

Parameters:
 * None

Returns:
 * a table which uses metamethods to access the thread's shared data dictionary.  Data can be shared between the thread and Hammerspoon by setting or reading key-value pairs within this table.

Notes:
 * you can assign the result of this function to a variable and treat it like any other table to retrieve or pass data to and from the thread.  Currently only strings, numbers, boolean, and tables can be shared -- functions, threads, and userdata are not yet supported (threads and c-functions probably never will be, but purely lua functions and userdata is being looked into)
 * because the actual data is stored in the NSThread dictionary, the lua representation is provided dynamically through metamethods.  For many uses, this distinction is unimportant, but it does have a couple of implications which should be kept in mind:
   * if you store a table value (i.e. a sub-table or entry from the method's returned table) from the shared dictionary in another variable, you are actually capturing a copy of the data at a specific point in time; if the table contents change in the shared dictionary, your stored copy will not reflect the new changes unless you re-acquire them from this method or from the specific table that it returns.
   * A sub-table or entry in this dynamic table is actually created each time it is accessed -- tools like `hs.inspect` have problems with this if you try to inspect the entire dictionary from its root because they rely on a specific table having a unique instance over multiple requests.  Inspecting a specific key from the returned table works as expected, however.

Consider the following code:

~~~lua
shared = hs._asm.luathread:sharedTable()
shared.sampleTable = { 1, 2, 3, 4 }
hs.inspect(shared)             -- this will generate an error
hs.inspect(shared.sampleTable) -- this works as expected
~~~

   * The meta-methods provided for the returned table are: `__index`, `__newindex`, `__len`, and `__pairs`.

- - -

<a name="submit"></a>
~~~lua
luathread:submit(code) -> threadObject
~~~
Submits the specified lua code for execution in the lua thread.

Parameters:
 * code - a string containing the lua code to execute in the thread.

Returns:
 * the thread object

* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

hs._asm.luathread._instance
===========================

This submodule provides functions within the background thread for controlling the thread and sharing data between Hammerspoon and the background thread.

When a lua thread is first created, it will look for an initialization file in your Hammerspoon configuration directory named `_init.*name*.lua`, where *name* is the name assigned to the thread when it is created.  If this file is not found, then `_init.lua` will be looked for.  If neither exist, then no custom initialization occurs.

The luathread instance is a complete lua environment with the following differences:

 * `package.path` and `package.cpath` take on their current values from Hammerspoon.
 * a special global variable named `_instance` is created and contains a userdata with methods for sharing data with Hammerspoon and returning output.  See the methods of this sub-module for specific information about these methods.
 * a special global variable named `_sharedTable` is created as a table.  Any key-value pairs stored in this special table are shared with Hammerspoon.  See [hs._asm.luathread:sharedTable](#sharedTable) for more information about this table -- this table is the thread side of that Hammerspoon method.
   * `_sharedTable._results` will contain a table with the following keys, updated after each submission to the thread:
     * `start`   - a time stamp specifying the time that the submitted code was started.
     * `stop`    - a time stamp specifying the time that the submitted code completed execution.
     * `results` - a table containing the results as an array of the submitted code.  Like `table.pack(...)`, a keyed entry of `n` contains the number of results returned.
 * `debug.sethook` is used within the thread to determine if the thread has been cancelled from the outside (i.e. Hammerspoon) and will terminate any lua processing within the thread immediately when this occurs.
 * `print` within the thread has been over-ridden so that output is cached and returned to Hammerspoon (through a callback function or the [hs._asm.luathread:getOutput](#getOutput) method) once the current lua code has completed (i.e. the thread is idle).
 * `os.exit` has been overridden to cleanly terminate the thread if/when invoked.
 * `hs.printf`, `hs.configdir`, `hs._exit`, and `hs.execute` have been replicated.

### Usage
The `_instance` variable is automatically created for you within the independant lua thread.

### Module Methods

<a name="cancel2"></a>
~~~lua
_instance:cancel([_, close]) -> threadObject
~~~
Cancel the lua thread, interrupting any lua code currently executing on the thread.

Parameters:
 * The first argument is always ignored
 * if two arguments are specified, the true/false value of the second argument is used to indicate whether or not the lua thread should exit cleanly with a formal lua_close (i.e. `__gc` metamethods will be invoked) or if the thread should just stop with no formal close.  Defaults to true (i.e. perform the formal close).

Returns:
 * the thread object

Notes:
 * the two argument format specified above is included to follow the format of the lua builtin `os.exit`

- - -

<a name="flush2"></a>
~~~lua
_instance:flush([push]) -> threadObject
~~~
Clears the cached output buffer.

Parameters:
 * push - an optional boolean argument, defaults to true, specifying whether or not the output currently in the buffer should be pushed to Hammerspoon before clearing the local cache.

Returns:
 * the thread object

Notes:
 * if `push` is not specified or is true, the output will be sent to Hammerspoon and any callback function will be invoked with the current output.  This can be used to submit partial output for a long running process and invoke the function periodically rather than just once at the end of the process.

- - -

<a name="get2"></a>
~~~lua
_instance:get([key]) -> value
~~~
Get the value for a keyed entry from the shared thread dictionary for the lua thread.

Parameters:
 * key - an optional key specifying the specific entry in the shared dictionary to return a value for.  If no key is specified, returns the entire shared dictionary as a table.

Returns:
 * the value of the specified key.

Notes:
 * If the key does not exist, then this method returns nil.
 * This method is used in conjunction with [hs._asm.luathread._instance:set](#set2) to pass data back and forth between the thread and Hammerspoon.
 * see also [hs._asm.luathread:sharedTable](#sharedTable) and the description of the global `_sharedTable` in this sub-module's description.

- - -

<a name="isCancelled"></a>
~~~lua
_instance:isCancelled() -> boolean
~~~
Returns true if the thread has been marked for cancellation.

Parameters:
 * None

Returns:
 * true or false specifying whether or not the thread has been marked for cancellation.

Notes:
 * this method is used by a handler set with `debug.sethook` to determine if lua code execution should be terminated so that the thread can be formally closed.

- - -

<a name="keys2"></a>
~~~lua
_instance:keys() -> table
~~~
Returns the names of all keys that currently have values in the shared dictionary of the lua thread.

Parameters:
 * None

Returns:
 * a table containing the names of the keys as an array

Notes:
 * see also [hs._asm.luathread._instance:get](#get2) and [hs._asm.luathread._instance:set](#set2)

- - -

<a name="name2"></a>
~~~lua
_instance:name() -> string
~~~
Returns the name assigned to the lua thread.

Parameters:
 * None

Returns:
 * the name specified or dynamically assigned at the time of the thread's creation.

- - -

<a name="print"></a>
~~~lua
_instance:print(...) -> threadObject
~~~
Adds the specified values to the output cache for the thread.

Parameters:
 * ... - zero or more values to be added to the output cache for the thread and ultimately returned to Hammerspoon with a lua processes results.

Returns:
 * the thread object

Notes:
 * this method is used to replace the lua built-in function `print` and mimics its behavior as closely as possible -- objects with a `__tostring` meta method are honored, arguments separated by comma's are concatenated with a tab in between them, the output line terminates with a `\\n`, etc.

- - -

<a name="reload"></a>
~~~lua
_instance:reload() -> None
~~~
Destroy's and recreates the lua state for the thread, reloading the configuration files and starting over.

Parameters:
 * None

Returns:
 * None

Notes:
 * this method is used to mimic the Hammerspoon `hs.reload` function, but for the luathread instance instead of Hammerspoon itself.

- - -

<a name="set2"></a>
~~~lua
_instance:set(key, value) -> threadObject
~~~
Set the value for a keyed entry in the shared thread dictionary for the lua thread.

Parameters:
 * key   - a key specifying the specific entry in the shared dictionary to set the value of.
 * value - the value to set the key to.  May be `nil` to clear or remove a key from the shared dictionary.

Returns:
 * the value of the specified key.

Notes:
 * This method is used in conjunction with [hs._asm.luathread._instance:get](#get2) to pass data back and forth between the thread and Hammerspoon.
 * see also [hs._asm.luathread:sharedTable](#sharedTable) and the description of the global `_sharedTable` in this sub-module's description.

- - -

<a name="timestamp"></a>
~~~lua
_instance:timestamp() -> number
~~~
Returns the current time as the number of seconds since Jan 1, 1970 (one of the conventional computer "Epochs" used for representing time).

Parameters:
 * None

Returns:
 * the number of seconds, including fractions of a second as the decimal portion of the number

Notes:
 * this differs from the built in lua `os.time` function in that it returns fractions of a second as the decimal portion of the number.
 * this is used when generating the `_sharedTable._results.start` and `_sharedTable._results.stop` values
 * the time values returned by this method can be used to calculate execution times in terms of clock time (i.e. other activity on the computer can cause wide fluctuations in the actual time a specific process takes).  To get a better idea of actual cpu time used by a process, check out the lua builtin `os.clock`.

### LICENSE

> The MIT License (MIT)
>
> Copyright (c) 2016 Aaron Magill
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
