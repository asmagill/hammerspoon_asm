hs._asm.consolepipe
===================

Tap into Hammerspoon's stderr and stdout streams.

`stdout` is challenging... do **NOT** print in your callback or you create a feedback loop that locks Hammerspoon up.  And an error in your callback does the same.  Need to figure out where all of the rawprint's and output to stdout specifically are occurring within Hammerspoon and see if they can be worked around or if this looping can be detected.

`stderr` contains the messages from Hammerspoon which are sent to the system logs and are traditionally viewed from the Console application.

### To-do/Wish list

1. See if we can detect loops and exit them gracefully rather than lock up
2. Review Hammerspoon source more closely for use of lua's built in print and see what removing them might break
3. Revisit use of shared NSPipe's in `internal.m`... I may have been chasing the wrong error last time I tried this
4. Can we add a corresponding mechanism for stdin to allow Hammerspoon to produce its own input?
5. Determine if delay in example below is because of io latency/memory caching or if its something else

### Installation

A precompiled version of this module can be found in this directory with a name along the lines of `consolepipe-v0.x.tar.gz`. This can be installed by downloading the file and then expanding it as follows:

~~~sh
$ cd ~/.hammerspoon # or wherever your Hammerspoon init.lua file is located
$ tar -xzf ~/Downloads/consolepipe-v0.x.tar.gz # or wherever your downloads are located
~~~

If you wish to build this module yourself, and have XCode installed on your Mac, the best way (you are welcome to clone the entire repository if you like, but no promises on the current state of anything) is to download `init.lua`, `internal.m`, and `Makefile` (at present, nothing else is required) into a directory of your choice and then do the following:

~~~sh
$ cd wherever-you-downloaded-the-files
$ [HS_APPLICATION=/Applications] [PREFIX=~/.hammerspoon] make install
~~~

If your Hammerspoon application is located in `/Applications`, you can leave out the `HS_APPLICATION` environment variable, and if your Hammerspoon files are located in their default location, you can leave out the `PREFIX` environment variable.  For most people it will be sufficient to just type `make install`.

As always, whichever method you chose, if you are updating from an earlier version it is recommended to fully quit and restart Hammerspoon after installing this module to ensure that the latest version of the module is loaded into memory.

### Usage
~~~lua
consolepipe = require("hs._asm.consolepipe")
~~~

### Module Constructors

<a name="new"></a>
~~~lua
consolepipe.new(stream) -> consolePipe object
~~~
Create a stream watcher.

Parameters:
 * stream - a string of "stdout" or "stderr" specifying which stream to create the watcher for.

Returns:
 * the consolePipe object

### Module Methods

<a name="delete"></a>
~~~lua
consolepipe:delete() -> none
~~~
Deletes the stream callback and releases the callback function.  This method is called automatically during reload.

Parameters:
 * None

Returns:
 * None

- - -

<a name="setCallback"></a>
~~~lua
consolepipe:setCallback(fn | nil) -> consolePipe object
~~~
Set or remove the callback function for the stream.

Parameters:
 * fn - a function, or an explicit nil to remove, to be installed as the callback when data is available on the stream.  The callback should expect one parameter -- a string containing the data which has been sent to the stream.

Returns:
 * the consolePipe object

- - -

<a name="start"></a>
~~~lua
consolepipe:start() -> consolePipe object
~~~
Starts calling the callback function when data becomes available on the attached stream.

Parameters:
 * None

Returns:
 * the consolePipe object

- - -

<a name="stop"></a>
~~~lua
consolepipe:stop() -> consolePipe object
~~~
Suspends calling the callback function when data becomes available on the attached stream.

Parameters:
 * None

Returns:
 * the consolePipe object

- - -

### Example

1. Save this code as "dumpStdout.lua" in ~/.hammerspoon/
2. In the Hammerspoon console, type the following: `dump = require("dumpStdout")`
3. In a terminal window, type `tail -f ~/.hammerspoon/dump.txt`
4. When done, type `dump.stop()` in the Hammerspoon console to stop (or just reload/restart Hammerspoon).

Now, anything which is sent to Hammerspoon's stdout will be replicated with a timestamp in the text file.  Currently this means anything which is printed to the Hammerspoon console with the `print` command... this includes log messages handled with `hs.logger` and at least some error messages, but I don't think all... a deeper investigation of the Hammerspoon source is required to determine why the difference when I get the time.

You may need to wait a few seconds after printing something in the console (you can speed this up a little with `io.output():flush()`) -- it's not quite immediate.  Not sure why yet.

Note that some third party code doesn't seem to generate output via the print command (the LuaRocks code itself is a good example).  Instead, they use something along the lines of `io.output():write(...)` or something similar... this watcher will catch that while the Hammerspoon console won't.

Note that because Hammerspoon *does* invoke the builtin `print` command as part of its  routines to replicate output to the console, I cannot stress enough that you should **NEVER** use the `print` command in your callback... this will cause a death spiral and you'll have to type `killall Hammerspoon` into a terminal window.


~~~lua
--
-- Sample use of capturing Hammerspoon's stdout
--
-- (1) Save this code as "dumpStdout.lua" in ~/.hammerspoon/
-- (2) In the Hammerspoon console, type the following: `dump = require("dumpStdout")`
-- (3) In a terminal window, type `tail -f ~/.hammerspoon/dump.txt`
-- (4) When done, type `dump.stop()` to close the replicator.
--

local module = {}
local consolepipe = require("hs._asm.consolepipe")
local timer       = require("hs.timer")

local err

local timestamp = function(date)
    date = date or timer.secondsSinceEpoch()
    return os.date("%F %T" .. string.format("%-5s", ((tostring(date):match("(%.%d+)$")) or "")), math.floor(date))
end

module.file, err = io.open("dump.txt", "w+")
if not module.file or err then error(err) end

module.replicator = consolepipe.new("stdout"):setCallback(function(stuff)
    if io.type(module.file) == "file" then
        local file, err = module.file:write(timestamp() .. ": " .. stuff)
        if not file or err then
            module.file:close()
            module.replicator:stop()
            error(err) -- do not throw until replicator is stopped
        end
    else
        module.replicator:stop()
        error("file handle not valid") -- do not throw until replicator is stopped
    end
end):start()

module.stop = function()
    module.replicator:stop()
    if io.type(module.file) == "file" then module.file:close() end
end

return module
~~~

### License

> Released under MIT license.
>
> Copyright (c) 2017 Aaron Magill
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
