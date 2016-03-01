hs._asm.luaskinpokeytool
========================

Access LuaSkin directly from Hammerspoon to examine things like registered conversion functions, etc.

This is probably a very bad idea.

If you're not comfortable poking around in the Hammerspoon and LuaSkin source code, this probably won't be of any use or interest.

**THIS MODULE IS NOT THREAD SAFE!!!**
If you use this module to examine or modify a LuaSkin object outside of it's primary thread (the application thread for Hammerspoon's LuaSkin object or the `hs._asm.luathread` instance for a LuaSkinThread object) and there is any lua activity currently occurring on that thread, that thread's lua state *may* become inconsistent.

You have been warned!  This is purely for experimental and informational purposes.  And because I'm curious just how far I can push things to see what's actually happening under the hood.  But if you use this and break anything, it's on you, not me.  Best bet is just to not use it.  Unless you're curious.  Or crazy.  It helps to be both.

I'm hoping it will help with tracking some things down during `hs._asm.luathread` development and *should* work in both environments... we'll see...

You're welcome to see if you can get any use out of it as well, but remember, we're dealing directly with the very object which maintains the Lua state for all of Hammerspoon.  Earth shattering kabooms are not out of the question...

"This will all end in tears, I Just know it..." -- Marvin / Alan Rickman

### Usage
~~~lua
luaskinpokeytool = require("hs._asm.luaskinpokeytool")
~~~

### Module Constructors

<a name="skin"></a>
~~~lua
luaskinpokeytool.skin() -> luaSkin object
~~~
Returns a reference to the LuaSkin object for the current Lua environment.

Parameters:
 * None

Returns:
 * a luaSkin object

Notes:
 * Because Hammerspoon itself runs a single-threaded Lua instance, there is only ever one LuaSkin instance available without using `hs._asm.luathread`.  Generally, in this situation, the available methods should be thread-safe, but remember you are dealing directly with the underpinnings of the Lua state for Hammerspoon -- there are other ways to screw things up if you're not careful!

 * To access a LuaSkin object for a different thread, you *must* be using `hs._asm.luathread` and copy it with the `hs._asm.luathread:get` method or shared dictionary table support.

 * It is **HIGHLY** recommended that you do not try to do things in the other direction (i.e. copy the Hammerspoon LuaSkin object into an `hs._asm.luathread` one with `hs._asm.luathread:set`) because the Hammerspoon LuaSkin instance is in use for every timer, hotkey invocation, callback function, etc.  Even submitting or receiving results from a threaded lua causes some LuaSkin activity on Hammerspoon's main thread, so the primary Hammerspoon LuaSkin instance can **NEVER** be considered inactive enough to be even *some-times* safe to examine or modify from another thread.

### Module Methods

<a name="NSHelperFunctions"></a>
~~~lua
luaskinpokeytool:NSHelperFunctions() -> table
~~~
Returns a table containing the registered helper functions LuaSkin uses for converting NSObjects into a Lua usable form.

Parameters:
 * None

Returns:
 * a table with keys matching the NSObject classes registered as convertible into a form usable within the Lua environment of Hammerspoon.

Notes:
 * The value for each key in the returned table contains a reference to the C-function behind the conversion tool and is probably not generally useful from the Lua side.
 * This function does not invoke the targeted LuaSkin instance so this method should be thread-safe if examining a LuaSkin instance other than the one running on the current thread.

- - -

<a name="NSHelperLocations"></a>
~~~lua
luaskinpokeytool:NSHelperLocations() -> table
~~~
Returns a table containing the registered helper functions LuaSkin uses for converting NSObjects into a Lua usable form and information about the file/module which registered the function.

Parameters:
 * None

Returns:
 * a table with keys matching the NSObject classes registered as convertible into a form usable within the Lua environment of Hammerspoon.  The value of each key is the short-path captured in the lua traceback at the time at which the function was registered.

Notes:
 * This function does not invoke the targeted LuaSkin instance so this method should be thread-safe if examining a LuaSkin instance other than the one running on the current thread.
 * If you have modified the lua `require` function in a fashion other than what Hammerspoon does by default, the location information may be blank or wrong.  You can try adjusting the stack level used to capture this information by adjusting the undocumented Hammerspoon setting `HSLuaSkinRegisterRequireLevel` from its default value of 3 with `hs.settings`.  Generally, if you have "undone" the wrapping of `require` to include crashlytic log messages each time the function is invoked, you should try reducing this number, and if you have added your own wrapper to the `require` function, you should try increasing this number.

- - -

<a name="classLogMessage"></a>
~~~lua
luaskinpokeytool.classLogMessage(level, message, [asClass]) -> None
~~~
Uses the class methods of LuaSkin to log a message

Parameters:
 * `level`   - an integer value from the `hs._asm.luaskinpokeytool.logLevels` table specifying the level of the log message.
 * `message` - a string containing the message to log.

Returns:
 * None

Notes:
 * This is wrapped in init.lua to provide the following shortcuts:
   * `hs._asm.luaskinpokeytool.logBreadcrumb(msg)`
   * `hs._asm.luaskinpokeytool.logVerbose(msg)`
   * `hs._asm.luaskinpokeytool.logDebug(msg)`
   * `hs._asm.luaskinpokeytool.logInfo(msg)`
   * `hs._asm.luaskinpokeytool.logWarn(msg)`
   * `hs._asm.luaskinpokeytool.logError(msg)`

 * No matter what thread this function is invoked in, it will always send the logs to the primary LuaSkin (i.e. the Hammerspoon main LuaSkin instance).

- - -

<a name="countNatIndex"></a>
~~~lua
luaskinpokeytool:countNatIndex(table | index) -> integer
~~~
Returns the number of keys of any type in the table specified.

Parameters:
 * a table or index to a table in the target LuaSkin's stack

Returns:
 * an integer specifying the number of keys in the table

Notes:
 * If `hs._asm.luaskinpokeytool:maxNatIndex(X) == hs._asm.luaskinpokeytool:countNatIndex(X)` and neither is equal to zero, then it is safe to assume the table is a non-sparse array starting at index 1.  This logic is used within LuaSkin to determine if a lua table is best represented as an NSDictionary or NSArray during conversions.

 * If the targetSkin and the currently active LuaSkin are identical, then a table argument is examined in place (i.e. as the method argument).
 * If the targetSkin and the currently active LuaSkin are not the same, then a table argument causes the table to be copied into the targetSkin at the current global stack top and examined in the target skin.  Depending upon the conversion support functions currently available in the targetSkin, the table may not be identical to the table you supply.

 * If you specify an index, then the index location in the targetSkin is verified to be a table, and if it is, this method examines that table.  Otherwise, an error is returned.

- - -

<a name="logMessage"></a>
~~~lua
luaskinpokeytool:logMessage(level, message, [asClass]) -> None
~~~
Uses the target LuaSkin's logging methods to log a message.

Parameters:
 * `level`   - an integer value from the `hs._asm.luaskinpokeytool.logLevels` table specifying the level of the log message.
 * `message` - a string containing the message to log.

Returns:
 * None

Notes:
 * This is wrapped in init.lua to provide the following shortcuts:
   * `hs._asm.luaskinpokeytool:logBreadcrumb(msg)`
   * `hs._asm.luaskinpokeytool:logVerbose(msg)`
   * `hs._asm.luaskinpokeytool:logDebug(msg)`
   * `hs._asm.luaskinpokeytool:logInfo(msg)`
   * `hs._asm.luaskinpokeytool:logWarn(msg)`
   * `hs._asm.luaskinpokeytool:logError(msg)`

 * I'm not sure how well this is going to work, since the same thread issue that `hs._asm.luaskinpokeytool:requireModule` has will come up with respect to the lua portion of the logging delegate.  However, I will test and ponder because this is another thing that seems like it might be useful to include in `hs._asm.luathread`.

- - -

<a name="luaHelperFunctions"></a>
~~~lua
luaskinpokeytool:luaHelperFunctions() -> table
~~~
Returns a table containing the registered helper functions LuaSkin uses for converting lua objects and tables into NSObjects.

Parameters:
 * None

Returns:
 * a table with keys matching the NSObject types which are convertible from a lua format upon request by a module.

Notes:
 * The value for each key in the returned table contains a reference to the C-function behind the conversion tool and is probably not generally useful from the Lua side.
 * This function does not invoke the targeted LuaSkin instance so this method should be thread-safe if examining a LuaSkin instance other than the one running on the current thread.

- - -

<a name="luaHelperLocations"></a>
~~~lua
luaskinpokeytool:luaHelperLocations() -> table
~~~
Returns a table containing the registered helper functions LuaSkin uses for converting lua objects and tables into NSObjects and information about the file/module which registered the function.

Parameters:
 * None

Returns:
 * a table with keys matching the NSObject types which are convertible from a lua format upon request by a module.  The value of each key is the short-path captured in the lua traceback at the time at which the function was registered.

Notes:
 * This function does not invoke the targeted LuaSkin instance so this method should be thread-safe if examining a LuaSkin instance other than the one running on the current thread.
 * If you have modified the lua `require` function in a fashion other than what Hammerspoon does by default, the location information may be blank or wrong.  You can try adjusting the stack level used to capture this information by adjusting the undocumented Hammerspoon setting `HSLuaSkinRegisterRequireLevel` from its default value of 3 with `hs.settings`.  Generally, if you have "undone" the wrapping of `require` to include crashlytic log messages each time the function is invoked, you should try reducing this number, and if you have added your own wrapper to the `require` function, you should try increasing this number.

- - -

<a name="luaUserdataMapping"></a>
~~~lua
luaskinpokeytool:luaUserdataMapping() -> table
~~~
Returns a table containing userdata types which have a registered conversion function that can be automatically identified by LuaSkin during conversion, rather than requiring the module's coder to explicitly request the conversion function.

Parameters:
 * None

Returns:
 * a table with keys matching the userdata types which can be automatically identified by LuaSkin and value is the NSObject class that the userdata can be automatically converted to without explicit request by a module developer.

Notes:
 * This function does not invoke the targeted LuaSkin instance so this method should be thread-safe if examining a LuaSkin instance other than the one running on the current thread.

- - -

<a name="maxNatIndex"></a>
~~~lua
luaskinpokeytool:maxNatIndex(table | index) -> integer
~~~
Returns the maximum consecutive integer key, starting at 1, in the table specified.

Parameters:
 * a table or index to a table in the target LuaSkin's stack

Returns:
 * an integer specifying the largest integer key in the table, or 0 if there are no integer keys

Notes:
 * If `hs._asm.luaskinpokeytool:maxNatIndex(X) == hs._asm.luaskinpokeytool:countNatIndex(X)` and neither is equal to zero, then it is safe to assume the table is a non-sparse array starting at index 1.  This logic is used within LuaSkin to determine if a lua table is best represented as an NSDictionary or NSArray during conversions.

 * If the targetSkin and the currently active LuaSkin are identical, then a table argument is examined in place (i.e. as the method argument).
 * If the targetSkin and the currently active LuaSkin are not the same, then a table argument causes the table to be copied into the targetSkin at the current global stack top and examined in the target skin.  Depending upon the conversion support functions currently available in the targetSkin, the table may not be identical to the table you supply.

 * If you specify an index, then the index location in the targetSkin is verified to be a table, and if it is, this method examines that table.  Otherwise, an error is returned.

- - -

<a name="requireModule"></a>
~~~lua
luaskinpokeytool:requireModule(moduleName) -> boolean
~~~
Attempts to load the specified module into the target LuaSkin.

Parameters:
 * the module to load

Returns:
 * A boolean indicating whether or not the module was successfully loaded (true) or not (false)

Notes:
 * This is probably a bad idea to use on a target LuaSkin other than the one that is currently active where this method is being invoked because some modules which are designed to work with a threaded LuaSkin use the current thread at the time of loading to store state information that is required for proper functioning when used in multiple environments.  If the module had not already been loaded, it may misidentify the proper thread.  I'm pondering possible work-arounds, since this actually seems like a useful tool to add to `hs._asm.luathread` proper...
