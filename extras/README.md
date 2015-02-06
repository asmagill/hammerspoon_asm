_asm.extras
-----------

This module provides extras that will someday be a real boy.  But for now I want them in a consistent place before I have decided where they belong.

I include these here for my convenience but they will be moved if a proper home is discovered for them where inclusion as a public function makes sense.  I will try to make it clear if something moves on the github repo where this ends up, but expect to need to make changes as these functions/tools become real.

### Local Install
~~~bash
$ git clone https://github.com/asmagill/hammerspoon_asm
$ cd hammerspoon_asm/extras
$ [PREFIX=/usr/local/share/lua/5.2/] [TARGET=`Hammerspoon|Mjolnir`] make install
~~~

Note that if you do not provide `TARGET`, then it defaults to `Hammerspoon`, and if you do not provide `PREFIX`, then it defaults to your particular environments home directory (~/.hammerspoon or ~/.mjolnir).

### Require

~~~lua
extras = require("`base`._asm.extras")
~~~

Where `base` is `hs` for Hammerspoon, and `mjolnir` for Mjolnir.

### Functions

~~~lua
extras.accessibility(shouldprompt) -> isenabled
~~~
Returns whether accessibility is enabled. If passed `true`, prompts the user to enable it.

~~~lua
extras.asciiOnly(string[, all]) -> string
~~~
Returns the provided string with all non-printable ascii characters (except for Return, Linefeed, and Tab unless `all` is provided and is true) escaped as \x## so that it can be safely printed in the console, rather than result in an uninformative '(null)'.  Note that this will break up Unicode characters into their individual bytes.

~~~lua
extras.autoLaunch([arg]) -> bool
~~~
When argument is absent or not a boolean value, this function returns true or false indicating whether or not the environment is set to launch when you first log in.  When a boolean argument is provided, it's true or false value is used to set the auto-launch status.

~~~lua
extras.exec(command[, with_user_env]) -> output, status, type, rc
~~~
Runs a shell command and returns stdout as a string (may include a trailing newline), followed by true or nil indicating if the command completed successfully, the exit type ("exit" or "signal"), and the result code.

If `with_user_env` is `true`, then invoke the user's default shell as an interactive login shell in which to execute the provided command in order to make sure their setup files are properly evaluated so extra path and environment variables can be set.  This is not done, if `with_user_env` is `false` or not provided, as it does add some overhead and is not always strictly necessary.

~~~lua
extras.fileExists(path) -> exists, isdir
~~~
Checks if a file exists, and whether it's a directory.

~~~lua
extras.fnutils_every(table, fn) -> bool
~~~
Returns true if the application of fn on every entry in table is truthy.

~~~lua
extras.fnutils_some(table, fn) -> bool
~~~
Returns true if the application of fn on entries in table are truthy for at least one of the members.

~~~lua
extras.hexDump(string [, count]) -> string
~~~
Treats the input string as a binary blob and returns a prettied up hex dump of it's contents. By default, a newline character is inserted after every 16 bytes, though this can be changed by also providing the optional count argument.  This is useful with the results of `extras.userDataToString` or `string.dump` for debugging and the curious, and may also provide some help with troubleshooting utf8 data that is being mis-handled or corrupted.

~~~lua
extras.NSLog(luavalue)
~~~
Send a representation of the lua value passed in to the Console application via NSLog.

~~~lua
extras.restart()
~~~
Completely restart {TARGET} by actually quitting the application and then reopening it.  Default pause to allow for a complete shutdown of {TARGET}  is 2 seconds, but you can adjust this by using the `settings` module to set "_asm.sleepCount" to your desired wait time.

~~~lua
extras.showAbout()
~~~
Displays the standard OS X about panel.

~~~lua
extras.sortedKeys(table[ , function]) -> function
~~~
Iterator for getting keys from a table in a sorted order. Provide function 'f' as per _Programming_In_Lua,_3rd_ed_, page 52; otherwise order is ascii order ascending. (e.g. `function(m,n) return not (m < n) end` would result in reverse order.

Similar to Perl's sort(keys %hash).  Use like this: `for i,v in extras.sortedKeys(t[, f]) do ... end`

~~~lua
extras.split(div, string) -> { ... }
~~~
Convert string to an array of strings, breaking at the specified divider(s), similar to "split" in Perl.

~~~lua
extras.userDataToString(userdata) -> string
~~~
Returns the userdata object as a binary string. Usually userdata is pretty boring -- containing c pointers, etc.  However, for some of the more complex userdata blobs for callbacks and such this can be useful with extras.hexdump for debugging to see what parts of the structure are actually getting set, etc.

~~~lua
extras.uuid() -> string
~~~
Returns a newly generated UUID as a string

~~~lua
extras.versionCompare(v1, v2) -> bool
~~~
Compare version strings and return `true` if v1 < v2, otherwise false.

Note that this started out for comparing luarocks version numbers, but should work for many cases. The basics are listed below.

    Luarocks version numbers: x(%.y)*-z
    x and y are probably numbers... but maybe not... z is a number

More generically, we actually accept _ or . as a separator, but only 1 - to keep with the luarocks spec.

Our rules for testing:

1. if a or b start with "v" or "r" followed immediately by a number, drop the letter.
2. break apart into x(%.y)* and z (we actually allow the same rules on z as we do for the first part, but if I understand the rockspec correctly, this should never actually happen)
3. first compare the x(%.y)* part.  If they are the same, only then compare the z part.

Repeat the following for each part:

1. if the version matches so far, and a has more components, then return a > b. e.g. 3.0.1 > 3.0 (of course 3.0.0 > 3.0 as well... should that change?)
2. If either part n of a or part n of b cannot be successfully changed to a number, compare as strings. Otherwise compare as numbers.

This does mean that the following probably won't work correctly, but at
least with luarocks, none have been this bad yet...

    3.0 "should" be > then a release candidate: 3.0rc
    3.0rc2 and 3.0.rc1 (inconsistent lengths of parts)
    3.0.0 aren't 3.0 "equal" (should they be?)
    "dev" should be before "alpha" or "beta"
    "final" should be after "rc" or "release"
    dates as version numbers that aren't yyyymmdd
    runs of 0's (tonumber("00") == tonumber("000"))
    "1a" and "10a"

    others?

### Variables

~~~lua
extras._version
~~~
The current application version as a string.

~~~lua
extras._paths[]
~~~
A table containing the resourcePath, the bundlePath, and the executablePath for the application.

~~~lua
extras.appleKeys[...]
~~~
Array of symbols representing special keys in the mac environment, as per http://macbiblioblog.blogspot.com/2005/05/special-key-symbols.html.  Where there are alternatives, I've tried to verify that the first is Apple's preference for their own documentation.  I found a dev file concerning this once, but forgot to link it, so I'll add that here when I find it again.

~~~lua
extras.mods[...]
~~~
Table of key modifier maps for `hotkey.bind`. It's a 16 element table of keys containing differing cased versions of the key "casc" where the letters stand for Command, Alt/Option, Shift, and Control.

     extras.mods = {
       casc = {                     }, casC = {                       "ctrl"},
       caSc = {              "shift"}, caSC = {              "shift", "ctrl"},
       cAsc = {       "alt"         }, cAsC = {       "alt",          "ctrl"},
       cASc = {       "alt", "shift"}, cASC = {       "alt", "shift", "ctrl"},
       Casc = {"cmd"                }, CasC = {"cmd",                 "ctrl"},
       CaSc = {"cmd",        "shift"}, CaSC = {"cmd",        "shift", "ctrl"},
       CAsc = {"cmd", "alt"         }, CAsC = {"cmd", "alt",          "ctrl"},
       CASc = {"cmd", "alt", "shift"}, CASC = {"cmd", "alt", "shift", "ctrl"},
     }

What fun if we ever differentiate between left, right, either, and both!

~~~lua
extras.mtTools[...]
~~~
An array containing useful functions for metatables in a single location for reuse.  Use as `setmetatable(myTable, { __index = extras.mtTools })`
 Currently defined:
 
     myTable:get("path.key" [, default])      -- Retrieve a value for key at the specified path in (possibly nested) table, or a default value, if it doesn't exist.  Note that "path" can be arbitrarily deeply nested tables (e.g. path.p2.p3. ... .pN).
     myTable:set("path.key", value [, build]) -- Set value for key at the specified path in table, building up the tables along the way, if build argument is true.   Note that "path" can be arbitrarily deeply nested tables (e.g. path.p2.p3. ... .pN).

### License

> Released under MIT license.
>
> Copyright (c) 2014 Aaron Magill
>
> Permission is hereby granted, free of charge, to any person obtaining a copy
> of this software and associated documentation files (the "Software"), to deal
> in the Software without restriction, including without limitation the rights
> to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
> copies of the Software, and to permit persons to whom the Software is
> furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in
> all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
> THE SOFTWARE.
