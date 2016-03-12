Examples for `hs._asm.objc`
===========================

This is a dumping ground for short snippets of what is possible with this module.  It's very experimental and basic, and unfortunately requires some features that have not quite made it into a core Hammerspoon release yet, but hopefully that will change with the next formal release... I'll update this as and when...

Currently, you must be running a development version of Hammerspoon and have applied the in progress Pull Request #825 for full support.  Primarily this is required for the support of structures (specifically NSRect, in the example provided next).

~~~lua
-- from within the Hammerspoon console, this moves the Console window
> o = require("hs._asm.objc")
> inspect(o.class("NSApplication")("sharedApplication")("mainWindow")("frame"))
-- NSRect myRect = [[[NSApplication sharedApplication] mainWindow] frame]

{
  __luaSkinType = "NSRect",
  h = 362.0,
  w = 1020.0,
  x = 420.0,
  y = 35.0
}

> o.class("NSApplication")("sharedApplication")("mainWindow")("setFrame:display:", {__luaSkinType="NSRect", x = 20, y = 100, h = 386, w = 669}, true)
-- [[[NSApplication sharedApplication] mainWindow] setFrame:NSMakeRect(20, 100, 386, 669) display:YES]
-- note also that these coordinates are in the native screen coordinates, where (0,0) is the lower left
-- corner of your primary display

nil

> inspect(o.class("NSApplication")("sharedApplication")("mainWindow")("frame"))

{
  __luaSkinType = "NSRect",
  h = 386.0,
  w = 669.0,
  x = 20.0,
  y = 100.0
}
~~~

The following does not require pull #825, but does require a development build if you wish to leave out the debugging messages (leave off the `hs.luaSkinLog.level = 4`)

~~~lua
> hs.luaSkinLog.level = 4 ; o = require("hs._asm.objc")

-- multiple ways to allocate and initialize an NSString object... note that since Lua/Hammerspoon
-- deals with 8-bit bytes which correspond to UTF8 encoded character strings, we have to initialize
-- our NSStrings with the UTF8String initializers.

> ns1 = o.class("NSString")("alloc")("initWithUTF8String:", "hello")
02:38:01    LuaSkin:     @ = [NSString alloc] with 0 arguments
                         @ = [<NSPlaceholderString> initWithUTF8String:] with 1 arguments

-- uses one of the flags settable in the actual message invocation function `o.objc_msgSend` and
-- actually reduces the number of messages sent through NSInvocation... faster than the above, if
-- we are really worried about speed
> ns2 = o.class("NSString"):allocAndMsgSend("initWithUTF8String:", "hello")
02:38:37                 @ = [<NSString> initWithUTF8String:] with 1 arguments


> ns3 = o.class("NSString")("stringWithUTF8String:", "hello")
02:38:56                 @ = [NSString stringWithUTF8String:] with 1 arguments


> ns4 = o.class("NSString")("alloc")("initWithUTF8String:", "not hello")
02:39:42                 @ = [NSString alloc] with 0 arguments
                         @ = [<NSPlaceholderString> initWithUTF8String:] with 1 arguments

-- When you know that both are strings, this is the preferred comparison method
> ns1("isEqualToString:", ns2)
02:40:06                 c = [<NSTaggedPointerString> isEqualToString:] with 1 arguments
true

-- though this works, too.  Supposedly it's slower than `isEqualToString` when both objects are
-- NSStrings
> ns1("isEqualTo:", ns3)
02:40:17                 c = [<NSTaggedPointerString> isEqualTo:] with 1 arguments
true

> ns1("isEqualToString:", ns4)
02:40:26                 c = [<NSTaggedPointerString> isEqualToString:] with 1 arguments
false

-- an object instance remains a userdata so we can easily use it with other methods, etc.
> ns4
hs._asm.objc.id: NSTaggedPointerString (0xb0c43d500208395)

-- but we can always turn it into a "native" Hammerspoon/Lua type, if such exists...
> ns4:value()
not hello
~~~

We can also work with other Hammerspoon types, if they have the necessary conversion helper functions installed (this also requires #825 for the NSRange support):

~~~lua
> o = require("hs._asm.objc")

-- this is the drawing of a CPU/Memory/Battery monitor I have displayed on my background
> obj = _asm._actions.geeklets.geeklets.cpu.drawings[1]:getStyledText()

-- it's an `hs.styledtext` object
> obj
hs.styledtext: CPU |||             ... (0x7fc1d36b17b8)

> obj:getString()
CPU |||                  18% Utilisation
RAM |||||||||||||||||||  99% Used, .03GB Free
Bat |||||||||||||||||||| 100% charged, 6269(mAh) Remain

> attributedString = o.object.fromLuaObject(obj)

-- and now, we have it back as it's native NSAttributedString Objective-C type
-- (well, a mutable subclass of it at any rate)
> attributedString
hs._asm.objc.id: NSConcreteMutableAttributedString (0x7fc1d3a125d0)

-- another way to get at a string's Lua equivalent value, since we know UTF8String will return a
-- C-String that Lua can accept directly...
> attributedString("string")("UTF8String")
CPU |||                  18% Utilisation
RAM |||||||||||||||||||  99% Used, .03GB Free
Bat |||||||||||||||||||| 100% charged, 6269(mAh) Remain

-- we can't support pointers to objects/structs yet for the effectiveRange: portion of this
-- method, but since it allows passing NULL (nil) to indicate that we don't care about it...
> hs.inspect(attributedString("attributesAtIndex:effectiveRange:", 5, nil):value())
{
  NSColor = {
    __luaSkinType = "NSColor",
    alpha = 1.0,
    blue = 0.0,
    green = 1.0,
    red = 0.0
  },
  NSFont = {
    __luaSkinType = "NSFont",
    name = "Menlo-Bold",
    size = 12.0
  }
}

-- replace a chunk of the string
> attributedString("replaceCharactersInRange:withString:", {__luaSkinType="NSRange", location=4, length=14}, o.class("NSString")("stringWithUTF8String:", "something else"))
nil

> attributedString("string")("UTF8String")
CPU something else       51% Utilisation
RAM |||||||||||||||||||  98% Used, .05GB Free
Bat |||||||||||||||||||| 100% charged, 6269(mAh) Remain
~~~

More examples will be provided as the module matures.  It does have limitations, many of which are described in the [README.md file](README.md).