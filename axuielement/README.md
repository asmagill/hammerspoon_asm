> Note to self: need to look closer at hs.uielement and see if there is any way to merge/combine... initial review seemed to suggest approaches are too widely divergent, but that was before I had a handle, tentative though it may still be, on what exactly was going on with AXUIElement objects.

Playing around with AXUIElements in Hammerspoon...

Don't know if this will become a module or not; its mainly for playing around right now.

Some interesting things of note:

~~~lua
ax = require("hs._asm.axuielement")
~~~

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
