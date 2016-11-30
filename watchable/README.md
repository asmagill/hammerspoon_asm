hs._asm.watchable
=================

A minimalistic Key-Value-Observer framework for Lua.

This module allows you to generate a table with a defined label or path that can be used to share data with other modules or code.  Other modules can register as watchers to a specific key-value pair within the watchable object table and will be automatically notified when the key-value pair changes.

The goal is to provide a mechanism for sharing state information between separate and (mostly) unrelated code easily and in an independent fashion.

### Installation

A prepackaged version of this module may be found in this directory with the name `watchable-v0.x.tar.gz`. This can be installed by downloading the file and then expanding it as follows:

~~~sh
$ cd ~/.hammerspoon # or wherever your Hammerspoon init.lua file is located
$ tar -xzf ~/Downloads/watchable-v0.x.tar.gz # or wherever your downloads are located
~~~

If you wish to build this module yourself, and have XCode installed on your Mac, the best way (you are welcome to clone the entire repository if you like, but no promises on the current state of anything else) is to download `init.lua` and `Makefile` (nothing else is required) into a directory of your choice and then do the following:

~~~sh
$ cd wherever-you-downloaded-the-files
$ [PREFIX=~/.hammerspoon] make install
~~~

If your Hammerspoon files are located in their default location, you can leave out the `PREFIX` environment variable.  For most people it will be sufficient to just type `make install`.

As always, whichever method you chose, if you are updating from an earlier version restart or reload Hammerspoon after installing this module to ensure that the latest version of the module being used.

- - -

### Usage
~~~lua
watchable = require("hs._asm.watchable")
~~~

### Contents


##### Module Constructors
* <a href="#new">watchable.new(path, [externalChanges]) -> table</a>
* <a href="#watch">watchable.watch(path, [key], callback) -> watchableObject</a>

##### Module Methods
* <a href="#callback">watchable:callback(fn | nil) -> watchableObject</a>
* <a href="#change">watchable:change([key], value) -> watchableObject</a>
* <a href="#pause">watchable:pause() -> watchableObject</a>
* <a href="#release">watchable:release() -> nil</a>
* <a href="#resume">watchable:resume() -> watchableObject</a>
* <a href="#value">watchable:value([key]) -> currentValue</a>

- - -

### Module Constructors

<a name="new"></a>
~~~lua
watchable.new(path, [externalChanges]) -> table
~~~
Creates a table that can be watched by other modules for key changes

Parameters:
 * `path`            - the global name for this internal table that external code can refer to the table as.
 * `externalChanges` - an optional boolean, default false, specifying whether external code can make changes to keys within this table (bi-directional communication).

Returns:
 * a table with metamethods which will notify external code which is registered to watch this table for key-value changes.

Notes:
 * This constructor is used by code which wishes to share state information which other code may register to watch.

 * You may specify any string name as a path, but it must be unique -- an error will occur if the path name has already been registered.
 * All key-value pairs stored within this table are potentially watchable by external code -- if you wish to keep some data private, do not store it in this table.
 * `externalChanges` will apply to *all* keys within this table -- if you wish to only allow some keys to be externally modifiable, you will need to register separate paths.
 * If external changes are enabled, you will need to register your own watcher with [hs._asm.watchable.watch](#watch) if action is required when external changes occur.

- - -

<a name="watch"></a>
~~~lua
watchable.watch(path, [key], callback) -> watchableObject
~~~
Creates a watcher that will be invoked when the specified key in the specified path is modified.

Parameters:
 * `path`     - a string specifying the path to watch.  If `key` is not provided, then this should be a string of the form "path.key" where the key will be identified as the string after the last "."
 * `key`      - if provided, a string specifying the specific key within the path to watch.
 * `callback` - a function which will be invoked when changes occur to the key specified within the path.  The function should expect the following arguments:
   * `watcher` - the watcher object itself
   * `path`    - the path being watched
   * `key`     - the specific key within the path which invoked this callback
   * `old`     - the old value for this key, may be nil
   * `new`     - the new value for this key, may be nil

Returns:
 * a watchableObject

Notes:
 * This constructor is used by code which wishes to watch state information which is being shared by other code.

 * The callback function is invoked after the new value has already been set -- the callback is a "didChange" notification, not a "willChange" notification.

 * If the key (specified as a separate argument or as the final component of path) is "*", then *all* key-value pair changes that occur for the table specified by the path will invoke a callback.  This is a shortcut for watching an entire table, rather than just a specific key-value pair of the table.
 * It is possible to register a watcher for a path that has not been registered with [hs._asm.watchable.new](#new) yet. Retrieving the current value with [hs._asm.watchable:value](#value) in such a case will return nil.

### Module Methods

<a name="callback"></a>
~~~lua
watchable:callback(fn | nil) -> watchableObject
~~~
Change or remove the callback function for the watchableObject.

Parameters:
 * `fn` - a function, or an explicit nil to remove, specifying the new callback function to receive notifications for this watchableObject

Returns:
 * the watchableObject

Notes:
 * see [hs._asm.watchable.watch](#watch) for a description of the arguments the callback function should expect.

- - -

<a name="change"></a>
~~~lua
watchable:change([key], value) -> watchableObject
~~~
Externally change the value of the key-value pair being watched by the watchableObject

Parameters:
 * `key`   - if the watchableObject was defined with a key of "*", this argument is required and specifies the specific key of the watched table to retrieve the value for.  If a specific key was specified when the watchableObject was defined, this argument must not be provided.
 * `value` - the new value for the key.

Returns:
 * the watchableObject

Notes:
 * if external changes are not allowed for the specified path, this method generates an error

- - -

<a name="pause"></a>
~~~lua
watchable:pause() -> watchableObject
~~~
Temporarily stop notifications about the key-value pair(s) watched by this watchableObject.

Parameters:
 * None

Returns:
 * the watchableObject

- - -

<a name="release"></a>
~~~lua
watchable:release() -> nil
~~~
Removes the watchableObject so that key-value pairs watched by this object no longer generate notifications.

Parameters:
 * None

Returns:
 * nil

- - -

<a name="resume"></a>
~~~lua
watchable:resume() -> watchableObject
~~~
Resume notifications about the key-value pair(s) watched by this watchableObject which were previously paused.

Parameters:
 * None

Returns:
 * the watchableObject

- - -

<a name="value"></a>
~~~lua
watchable:value([key]) -> currentValue
~~~
Get the current value for the key-value pair being watched by the watchableObject

Parameters:
 * `key` - if the watchableObject was defined with a key of "*", this argument is required and specifies the specific key of the watched table to retrieve the value for.  If a specific key was specified when the watchableObject was defined, this argument is ignored.

Returns:
 * The current value for the key-value pair being watched by the watchableObject. May be nil.

- - -

### License

>     The MIT License (MIT)
>
> Copyright (c) 2016 Aaron Magill
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
>

