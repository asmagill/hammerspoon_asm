Playing around with AXUIElements in Hammerspoon...

Don't know if this will become a module or not; its mainly for playing around right now.

Some interesting things of note:

~~~lua
a = require("hs._asm.axuielement")
~~~

~~~lua
> for i,v in ipairs(a.systemWideElement():attributeValue("AXFocusedApplication"):attributeValue("AXMenuBar"):attributeValue("AXChildren")) do print(v:attributeValue("AXTitle")) end
Apple
Hammerspoon
File
Edit
Window
Help


> for i,v in ipairs(s:attributeValue("AXFocusedApplication"):attributeValue("AXMenuBar"):attributeValue("AXChildren")[2]:attributeValue("AXChildren")[1]:attributeValue("AXChildren")) do print(v:attributeValue("AXTitle")) end
About Hammerspoon
Check for Updates...

Preferences…

Services

Hide Hammerspoon
Hide Others
Show All
Quit Hammerspoon
~~~
