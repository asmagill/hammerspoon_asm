hs._asm.axuielement
===================

This is still very much a work in progress, and whether or not it makes it into Hammerspoon core in its current form is still undecided.  However, as there has been some interest expressed in the module, I have finally gotten around to cleaning it up some and creating a [reference document](Reference.md) for it.

I am leaving the rest of the Readme.md file as is for now, while I determine which examples are worth keeping and decide on a proper way to show what I have figured out, what I haven't, what still needs to be done, etc...

A precompiled version of this module can be found in this directory with a name along the lines of `axuielement-v0.x.tar.gz`. This can be installed by downloading the file and then expanding it as follows:

~~~sh
$ cd ~/.hammerspoon # or wherever your Hammerspoon init.lua file is located
$ tar -xzf ~/Downloads/axuielement-v0.x.tar.gz # or wherever your downloads are located
~~~

If you wish to build this module yourself, and have XCode installed on your Mac, the best way (you are welcome to clone the entire repository if you like, but no promises on the current state of anything) is to download `init.lua`, `internal.m`, and `Makefile` (at present, nothing else is required) into a directory of your choice and then do the following:

~~~sh
$ cd wherever-you-downloaded-the-files
$ [HS_APPLICATION=/Applications] [PREFIX=~/.hammerspoon] make install
~~~

If your Hammerspoon application is located in `/Applications`, you can leave out the `HS_APPLICATION` environment variable, and if your Hammerspoon files are located in their default location, you can leave out the `PREFIX` environment variable.  For most people it will be sufficient to just type `make install`.

As always, whichever method you chose, if you are updating from an earlier version it is recommended to fully quit and restart Hammerspoon after installing this module to ensure that the latest version of the module is loaded into memory.

- - -

### Previous Documentation, untouched (for now)

> Note to self: need to look closer at hs.uielement and see if there is any way to merge/combine... initial review seemed to suggest approaches are too widely divergent, but that was before I had a handle, tentative though it may still be, on what exactly was going on with AXUIElement objects.

Playing around with AXUIElements in Hammerspoon...

Don't know if this will become a module or not; its mainly for playing around right now.

Some interesting things of note:

~~~lua
ax = require("hs._asm.axuielement")
~~~

### 2016-01-09 additions:

~~~lua
ax.log.level = 0 -- turn off log output for missing Safari types (believed to be AXTextMarkerRef, and AXTextMarkerRangeRef, but they are private as far as I can determine so far, so... no joy for now.)

print(os.date()) ; z1 = ax.applicationElement(hs.appfinder.appFromName("Safari")):elementSearch({}) ; print(os.date(), #z1)


print(os.date()) ; z2 = ax.applicationElement(hs.appfinder.appFromName("Safari")):getAllChildElements() ; print(os.date(), #z2)
~~~

* z1 - uses lua based elementSearch to grab all AXUIelements from the starting point and put them into an array.
* z2 - uses Objective-C function to do the same.  Runs an average of 3-4 times faster (15 seconds vs 60 seconds for one test)

Array returned from either can be used in further refinement searches that only search within the array, rather than recurse through AXUIelements the slow way each time -- e.g. `z2:elementSearch({role="AXWindow"})` to get just the window AXUIElements from the z2 array.

Considering putting z2 version in a separate thread and callback with the array so doesn't block Hammerspoon even for the reduced time period.

### Latest Examples:

~~~lua
btn = ax.applicationElement(hs.appfinder.appFromName("Hammerspoon")):
          elementSearch({role="AXWindow", subrole="AXStandardWindow"})[1]:
          elementSearch({subrole="AXZoomButton"})[1]

a = hs.drawing.rectangle(btn:frame()):setFill(false):setStroke(true):setStrokeColor{red=1}:show()

btn:doPress() ; a:setFrame(btn:frame())
~~~


_ _ _

Check out `inspect(ax.browse(ax.systemWideElement()))`... it's really quite interesting... and long.  Working on more targeted query wrappers/functions.

Can perform actions: move mouse pointer over desktop background (i.e. the Finder background) and type:

~~~lua
ax.systemWideElement():elementAtPosition(hs.mouse.getAbsolutePosition()):performAction("AXShowMenu")
~~~

Older (Menubar) examples:

~~~lua
> for i,v in ipairs(ax.systemWideElement():attributeValue("AXFocusedApplication"):attributeValue("AXMenuBar"):attributeValue("AXChildren")) do print(v:attributeValue("AXTitle")) end
Apple
Hammerspoon
File
Edit
Window
Help

> for i,v in ipairs(ax.systemWideElement():attributeValue("AXFocusedApplication"):attributeValue("AXMenuBar"):attributeValue("AXChildren")[2]:attributeValue("AXChildren")[1]:attributeValue("AXChildren")) do print(v:attributeValue("AXTitle")) end
About Hammerspoon
Check for Updates...

Preferences…

Services

Hide Hammerspoon
Hide Others
Show All
Quit Hammerspoon
~~~
