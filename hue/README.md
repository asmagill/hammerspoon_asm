hs._asm.hue
===========

Manage Philips Hue Hubs on your local network.


### Installation

A precompiled version of this module can be found in this directory with a name along the lines of `hue-v0.x.tar.gz`. This can be installed by downloading the file and then expanding it as follows:

~~~sh
$ cd ~/.hammerspoon # or wherever your Hammerspoon init.lua file is located
$ tar -xzf ~/Downloads/hue-v0.x.tar.gz # or wherever your downloads are located
~~~

If you wish to build this module yourself, and have XCode installed on your Mac, the best way (you are welcome to clone the entire repository if you like, but no promises on the current state of anything else) is to download `init.lua` and `Makefile` (at present, nothing else is required) into a directory of your choice and then do the following:

~~~sh
$ cd wherever-you-downloaded-the-files
$ [HS_APPLICATION=/Applications] [PREFIX=~/.hammerspoon] make docs install
~~~

If your Hammerspoon application is located in `/Applications`, you can leave out the `HS_APPLICATION` environment variable, and if your Hammerspoon files are located in their default location, you can leave out the `PREFIX` environment variable.  For most people it will be sufficient to just type `make docs install`.

As always, whichever method you chose, if you are updating from an earlier version it is recommended to fully quit and restart Hammerspoon after installing this module to ensure that the latest version of the module is loaded into memory.

### Usage
~~~lua
hue = require("hs._asm.hue")
~~~

### Contents


##### Module Constructors
* <a href="#connect">hue.connect(bridgeID, userID) -> hueObject</a>

##### Module Functions
* <a href="#beginDiscovery">hue.beginDiscovery([queryTime], [callback]) -> none</a>
* <a href="#createUser">hue.createUser(bridgeID, userName) -> results</a>
* <a href="#hueColor">hue.hueColor(color) -> table</a>
* <a href="#setDefault">hue.setDefault(bridgeID, userID, [force]) -> boolean</a>

##### Module Methods
* <a href="#delete">hue:delete(queryString) -> table</a>
* <a href="#get">hue:get(queryString) -> table</a>
* <a href="#makeDefault">hue:makeDefault([force]) -> boolean</a>
* <a href="#post">hue:post(queryString, body) -> table</a>
* <a href="#put">hue:put(queryString, body) -> table</a>

##### Module Variables
* <a href="#default">hue.default</a>
* <a href="#defaultRetryTime">hue.defaultRetryTime</a>
* <a href="#log">hue.log</a>

##### Module Constants
* <a href="#discovered">hue.discovered</a>

- - -

### Module Constructors

<a name="connect"></a>
~~~lua
hue.connect(bridgeID, userID) -> hueObject
~~~
Connect to the specified Hue bridge with the specified user hash.

Parameters:
 * bridgeID - a string specifying the bridge id of the bridge to connect to. See [hs._asm.hue.discovered](#discovered).
 * userID   - a string specifying the user hash as provided by [hs._asm.hue.createUser](#createUser).

Returns:
 * the hueObject if the bridge is available or nil if it is not

Notes:
 * if you have set a default with [hs._asm.hue.setDefault](#setDefault) then a connection will be attempted automatically when this module is loaded. See [hs._asm.hue.default](#default).

### Module Functions

<a name="beginDiscovery"></a>
~~~lua
hue.beginDiscovery([queryTime], [callback]) -> none
~~~
Perform an SSDP M-SEARCH query to discover Philips Hue bridges on the current network.

Parameters:
 * queryTime - the number of seconds, default 3.0, to query for bridges on the local network.
 * callback   - an optional function to execute after the query has completed.  Defaults to an empty function.

Returns:
 * None

Notes:
 * This function will clear current entries in [hs._asm.hue.discovered](#discovered) before performing the query and then populate it with bridges discovered on the current local networks.

- - -

<a name="createUser"></a>
~~~lua
hue.createUser(bridgeID, userName) -> results
~~~
Attempts to create a new user ID on the specified Philips Hue bridge

Parameters:
 * bridgeID - a string specifying the id of the discovered bridge on which you wish to create a new user. See [hs._asm.hue.discovered](#discovered).
 * userID   - a string specifying a human readable name for the new user identification string

Returns:
 * a table containing the results of the request.
   * If the link button on your Philips Hue bridge has not been pressed, the table will contain the following:
 ~~~
{ {
    error = {
      address = "/",
      description = "link button not pressed",
      type = 101
    }
  } }
~~~
   * If you have pressed the link button and issue this function within 30 seconds, the table will contain the following:
 ~~~
{ {
    success = {
      username = "string-contaning-letters-and-numbers"
    }
  } }
~~~
   * Note the value of `username` as you will need it for [hs._asm.hue.connect](#connect)

Notes:
 * The Philips Hue bridge does not support usernames directly; instead, you must specify an application name and a device or user for that application which are used to construct a unique hashed value in your bridge which is added to its whitelist. Internally this function prepends "hammerspoon" as the application name, so you only provide the user portion. The returned hash is how you authenticate yourself for future communication with the bridge.

 * The table returned uses `hs.inspect` as it's __tostring metamethod; this means that you can issue the command in the Hammerspoon console and see the results without having to capture the return value and viewing it with `hs.inspect` yourself.

- - -

<a name="hueColor"></a>
~~~lua
hue.hueColor(color) -> table
~~~
Returns a table containing the hue, sat, and bri properties recognizable by the Philips Hue bridge representing the color specified.

Parameters:
 * color - a table specifying a color as defined by the `hs.drawing.color` module

Returns:
 * a table containing the `hue`, `sat`, and `bri` key-value pairs recognizable by the Philips Hue bridge representing the color specified. If no conversion is possible, returns an empty table, which if provided to the bridge, will result in no change.

- - -

<a name="setDefault"></a>
~~~lua
hue.setDefault(bridgeID, userID, [force]) -> boolean
~~~
Set or clear the default bridge and user used for automatic connection when this module loads.

Parameters:
 * bridgeID - a string (or explicit nil if you wish to remove the current default) specifying the bridge id of the bridge to connect to by default. See [hs._asm.hue.discovered](#discovered).
 * userID   - a string (or explicit nil if you wish to remove the current default) specifying the user hash as provided by [hs._asm.hue.createUser](#createUser).
 * force    - an optional boolean, default false, specifying if an existing default should be replaced by the new values.

Returns:
 * true if the new settings have been saved or false if they were not.

Notes:
 * If a default is set then this module will automatically discover available bridges when loaded and connect to the specified bridge if it is available. See [hs._asm.hue.default](#default).
 * On a successful change, [hs._asm.hue.default](#default) will be reset to reflect the new defaults.

 * See also [hs._asm.hue:makeDefault](#makeDefault).

### Module Methods

<a name="delete"></a>
~~~lua
hue:delete(queryString) -> table
~~~
Sends a DELETE query to the Hue bridge using its REST API.

Parameters:
 * queryString - a string specifying the query for the Hue bridge.

Returns:
 * a table of the decoded json data returned by the Hue bridge in response to this query

Notes:
 * The table returned uses `hs.inspect` as it's __tostring metamethod; this means that you can issue the command in the Hammerspoon console and see the results without having to capture the return value and viewing it with `hs.inspect` yourself.

- - -

<a name="get"></a>
~~~lua
hue:get(queryString) -> table
~~~
Sends a GET query to the Hue bridge using its REST API.

Parameters:
 * queryString - a string specifying the query for the Hue bridge.

Returns:
 * a table of the decoded json data returned by the Hue bridge in response to this query

Notes:
 * The table returned uses `hs.inspect` as it's __tostring metamethod; this means that you can issue the command in the Hammerspoon console and see the results without having to capture the return value and viewing it with `hs.inspect` yourself.

- - -

<a name="makeDefault"></a>
~~~lua
hue:makeDefault([force]) -> boolean
~~~
Set this current connection as the module's default connection to be attempted on module load.

Parameters:
 * force - an optional boolean, default false, specifying whether or not this connection should overwrite any existing default connection.

Returns:
 * true if the change was successful or false if it was not

Notes:
 * This is a wrapper for [hs._asm.hue.setDefault](#setDefault) providing the bridgeID and userID from this connection.  It's return value and behavior are described in the documentation for `setDefault`.

- - -

<a name="post"></a>
~~~lua
hue:post(queryString, body) -> table
~~~
Sends a POST query to the Hue bridge using its REST API.

Parameters:
 * queryString - a string specifying the query for the Hue bridge.
 * body        - the data for the query.  This should be a string specifying json encoded data, a table which will be converted to json encoded data, or nil

Returns:
 * a table of the decoded json data returned by the Hue bridge in response to this query

Notes:
 * The table returned uses `hs.inspect` as it's __tostring metamethod; this means that you can issue the command in the Hammerspoon console and see the results without having to capture the return value and viewing it with `hs.inspect` yourself.

- - -

<a name="put"></a>
~~~lua
hue:put(queryString, body) -> table
~~~
Sends a PUT query to the Hue bridge using its REST API.

Parameters:
 * queryString - a string specifying the query for the Hue bridge.
 * body        - the data for the query.  This should be a string specifying json encoded data, a table which will be converted to json encoded data, or nil

Returns:
 * a table of the decoded json data returned by the Hue bridge in response to this query

Notes:
 * The table returned uses `hs.inspect` as it's __tostring metamethod; this means that you can issue the command in the Hammerspoon console and see the results without having to capture the return value and viewing it with `hs.inspect` yourself.

### Module Variables

<a name="default"></a>
~~~lua
hue.default
~~~
The hueObject representing the default bridge connection set by [hs._asm.hue.setDefault](#setDefault).

If you have not set a default, or if the default is not available when this module is first loaded, this value will be nil. If you change the default with [hs._asm.hue.setDefault](#setDefault) then this value will be set to nil and a connection attempt to the new bridge will be attempted.  On success, this variable will then contain the hueObject for the new connection.

- - -

<a name="defaultRetryTime"></a>
~~~lua
hue.defaultRetryTime
~~~
The retry interval when a default is set with [hs._asm.hue.setDefault](#setDefault) but the specified bridge was not discovered.  Defaults to 60 seconds.

To effect a persistent change to this value, set your desired timeout with `hs.settings.set("hs._asm.hue.defaultRetryTime", value)`.

- - -

<a name="log"></a>
~~~lua
hue.log
~~~
hs.logger object used within this module.

### Module Constants

<a name="discovered"></a>
~~~lua
hue.discovered
~~~
A table containing key-value pairs for the Philips Hue bridges discovered on the current network by this module.

This table is initially empty until [hs._asm.hue.beginDiscovery](#beginDiscovery) has been executed.  If you have a default defined with [hs._asm.hue.setDefault](#setDefault), then this process will occur automatically when the module is loaded.

The keys represent the bridge ID's of Hue bridges discovered and the value will be a table containing the name of the bridge, the time it last responded to a discovery query, and the root URL to use for queries.  A __tostring metatable method has been added so you can view the table in the console by just referencing this variable.

- - -

### License

>     The MIT License (MIT)
>
> Copyright (c) 2017 Aaron Magill
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
>

