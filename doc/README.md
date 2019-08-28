hs.doc
======

HS.DOC, The Rewrite: Bigger, bolder, and coming to a theater near you... In Smell-O-Vision!!!!!


Create documentation objects for interactive help within Hammerspoon

The documentation object created is a table with tostring metamethods allowing access to a specific functions documentation by appending the path to the method or function to the object created.

From the Hammerspoon console:

      doc = require("hs.doc")
      doc.hs.application

Results in:

      Manipulate running applications

      [submodules]
      hs.application.watcher

      [subitems]
      hs.application:activate([allWindows]) -> bool
      hs.application:allWindows() -> window[]
          ...
      hs.application:visibleWindows() -> win[]

By default, the internal core documentation and portions of the Lua 5.3 manual, located at http://www.lua.org/manual/5.3/manual.html, are already registered for inclusion within this documentation object, but you can register additional documentation from 3rd party modules with `hs.registerJSONFile(...)`.

### Testing Out With your System

* Follow the installation instructions which follow. The module will be installed in your Hammerspoon config directory and be loaded instead of the stock version of `hs.doc`
* Restart Hammerspoon

You can revert to the stock `hs.doc` by either executing `[PREFIX=~/.hammerspoon] make uninstall` from the installation directory or by renaming the `init.lua` file in `~/.hammerspoon/hs/doc` so that this module is no longer detected as a valid module, (e.g. `mv ~/.hammerspoon/hs/doc/init.lua ~/.hammerspoon/hs/doc/init.off`) and restarting Hammerspoon.

### Installation

To build this module, you must have XCode installed on your Mac. The best way (you are welcome to clone the entire repository if you like, but no promises on the current state of anything) is to do the following:

~~~sh
$ svn export https://github.com/asmagill/hammerspoon_asm/trunk/doc
$ cd doc
$ [HS_APPLICATION=/Applications] [PREFIX=~/.hammerspoon] make docs install
~~~

If your Hammerspoon application is located in `/Applications`, you can leave out the `HS_APPLICATION` environment variable, and if your Hammerspoon files are located in their default location, you can leave out the `PREFIX` environment variable.  For most people it will be sufficient to just type `make docs install` in each of the directories specified above.

As always, whichever method you chose, if you are updating from an earlier version it is recommended to fully quit and restart Hammerspoon after installing this module to ensure that the latest version of the module is loaded into memory.

### Usage
~~~lua
doc = require("hs.doc")
~~~

### Contents


##### Module Functions
* <a href="#help">doc.help(identifier)</a>
* <a href="#locateJSONFile">doc.locateJSONFile(module) -> path | false, message</a>
* <a href="#preloadSpoonDocs">doc.preloadSpoonDocs()</a>
* <a href="#registerJSONFile">doc.registerJSONFile(jsonfile, [isSpoon]) -> status[, message]</a>
* <a href="#registeredFiles">doc.registeredFiles() -> table</a>
* <a href="#unregisterJSONFile">doc.unregisterJSONFile(jsonfile) -> status[, message]</a>

- - -

### Module Functions

<a name="help"></a>
~~~lua
doc.help(identifier)
~~~
Prints the documentation for some part of Hammerspoon's API and Lua 5.3.  This function has also been aliased as `hs.help` and `help` as a shorthand for use within the Hammerspoon console.

Parameters:
 * identifier - A string containing the signature of some part of Hammerspoon's API (e.g. `"hs.reload"`)

Returns:
 * None

Notes:
 * This function is mainly for runtime API help while using Hammerspoon's Console

 * Documentation files registered with [hs.doc.registerJSONFile](#registerJSONFile) or [hs.doc.preloadSpoonDocs](#preloadSpoonDocs) that have not yet been actually loaded will be loaded when this command is invoked in any of the forms described below.

 * You can also access the results of this function by the following methods from the console:
   * help("prefix.path") -- quotes are required, e.g. `help("hs.reload")`
   * help.prefix.path -- no quotes are required, e.g. `help.hs.reload`
     * `prefix` can be one of the following:
       * `hs`    - provides documentation for Hammerspoon's builtin commands and modules
       * `spoon` - provides documentation for the Spoons installed on your system
       * `lua`   - provides documentation for the version of lua Hammerspoon is using, currently 5.3
         * `lua._man` - provides the table of contents for the Lua 5.3 manual.  You can pull up a specific section of the lua manual by including the chapter (and subsection) like this: `lua._man._3_4_8`.
         * `lua._C`   - provides documentation specifically about the Lua C API for use when developing modules which require external libraries.
     * `path` is one or more components, separated by a period specifying the module, submodule, function, or moethod you wish to view documentation for.

- - -

<a name="locateJSONFile"></a>
~~~lua
doc.locateJSONFile(module) -> path | false, message
~~~
Locates the JSON file corresponding to the specified third-party module or Spoon by searching package.path and package.cpath.

Parameters:
 * module - the name of the module to locate a JSON file for

Returns:
 * the path to the JSON file, or `false, error` if unable to locate a corresponding JSON file.

Notes:
 * The JSON should be named 'docs.json' and located in the same directory as the `lua` or `so` file which is used when the module is loaded via `require`.

 * The documentation for core modules is stored in the JSON file specified by the `hs.docstrings_json_file` variable; this function is intended for use in locating the documentation file for third party modules and Spoons.

- - -

<a name="preloadSpoonDocs"></a>
~~~lua
doc.preloadSpoonDocs()
~~~
Locates all installed Spoon documentation files and and marks them for loading the next time the [hs.doc.help](#help) function is invoked.

Parameters:
 * None

Returns:
 * None

- - -

<a name="registerJSONFile"></a>
~~~lua
doc.registerJSONFile(jsonfile, [isSpoon]) -> status[, message]
~~~
Register a JSON file for inclusion when Hammerspoon generates internal documentation.

Parameters:
 * jsonfile - A string containing the location of a JSON file
 * isSpoon  - an optional boolean, default false, specifying that the documentation should be added to the `spoons` sub heading in the documentation hierarchy.

Returns:
 * status - Boolean flag indicating if the file was registered or not.  If the file was not registered, then a message indicating the error is also returned.

Notes:
 * this function just registers the documentation file; it won't actually be loaded and parsed until [hs.doc.help](#help) is invoked.

- - -

<a name="registeredFiles"></a>
~~~lua
doc.registeredFiles() -> table
~~~
Returns the list of registered JSON files.

Parameters:
 * None

Returns:
 * a table containing the list of registered JSON files

Notes:
 * The table returned by this function has a metatable including a __tostring method which allows you to see the list of registered files by simply typing `hs.doc.registeredFiles()` in the Hammerspoon Console.

 * By default, the internal core documentation and portions of the Lua 5.3 manual, located at http://www.lua.org/manual/5.3/manual.html, are already registered for inclusion within this documentation object.

 * You can unregister these defaults if you wish to start with a clean slate with the following commands:
   * `hs.doc.unregisterJSONFile(hs.docstrings_json_file)` -- to unregister the Hammerspoon API docs
   * `hs.doc.unregisterJSONFile((hs.docstrings_json_file:gsub("/docs.json$","/extensions/hs/doc/lua.json")))` -- to unregister the Lua 5.3 Documentation.

- - -

<a name="unregisterJSONFile"></a>
~~~lua
doc.unregisterJSONFile(jsonfile) -> status[, message]
~~~
Remove a JSON file from the list of registered files.

Parameters:
 * jsonfile - A string containing the location of a JSON file

Returns:
 * status - Boolean flag indicating if the file was unregistered or not.  If the file was not unregistered, then a message indicating the error is also returned.

Notes:
 * This function requires the rebuilding of the entire documentation tree for all remaining registered files, so the next time help is queried with [hs.doc.help](#help), there may be a slight one-time delay.

- - -

### License

>     The MIT License (MIT)
>
> Copyright (c) 2019 Aaron Magill
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
>


