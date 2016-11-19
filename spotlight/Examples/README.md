Examples
========

### `altnames.lua`

The original impetus behind this module was the Hammerspoon issue [1043](https://github.com/Hammerspoon/hammerspoon/issues/1043) which noted that some of the `hs.application` methods work well with "alternate" names for applications while others do not.  Under the assumption that Spotlight was being used to identify the alternate names, the example provided in `altnames.lua` was built.

To use this example, download the file into your `~/.hammerspoon` directory (or another place within your search path) and do the following:

~~~lua
alt = require("altnames") -- the path may differ if you've loaded the file somewhere else.  Adjust as necessary.
~~~

After a few seconds, if Spotlight is running on your system, the name map should be built.  It will be kept up to date as you add or remove applications from your system. To test, type in:

~~~lua
alt.realNameFor("AppleScript Editor")
~~~

This will return the actual application name of `Script Editor`.

Like the `hs.application.find` function, it will do partial matches by default:

~~~lua
> alt.realNameFor("AppleScript")
Cocoa-AppleScript Applet	Script Editor	AppleScript Utility

> alt.realNameFor("Script")
Cocoa-AppleScript Applet	Script Editor	ScriptMonitor	AppleScript Utility
~~~

You can also access the name map directly like this:

~~~lua
> alt.nameMap["AppleScript Editor"]
Script Editor.app
~~~

But as you'll note, this doesn't allow pattern matching and returns the name with the `.app` bundle extension, which most of the `hs.application` functions and methods do not like.

Other examples may follow in the future.
