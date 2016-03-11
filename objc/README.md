hs._asm.objc
============

The very early attempts at something approaching a "bridge" between Hammerspoon/Lua and Objective-C Classes.

It's extremely buggy, experimental, and probably a few other pejoratives, but it's an ongoing thing I've been poking at off and on for a while.

Sample output from the latest run (I just got basic arguments to work, but not structures or arrays, and union and variable argument length methods will never work due to limitations in NSInvocation -- though I've read that libFFI has issues with them as well):

Latest has some support for structures, but requires development Hammerspoon with pull request #825 applied:

~~~lua
-- from within the Hammerspoon console, this moves the Console window
> hs.luaSkinLog.level = 4 ; o = require("hs._asm.objc")

> inspect(o.class("NSApplication")("sharedApplication")("mainWindow")("frame"))
19:17:21                 @ = [NSApplication sharedApplication] with 0 arguments
                         @ = [<NSApplication> mainWindow] with 0 arguments
                         {CGRect={CGPoint=dd}{CGSize=dd}} = [<NSWindow> frame] with 0 arguments
{
  __luaSkinType = "NSRect",
  h = 386.0,
  w = 669.0,
  x = 771.0,
  y = 35.0
}

> inspect(o.class("NSApplication")("sharedApplication")("mainWindow")("setFrame:display:", {__luaSkinType="NSRect", x = 20, y = 35, h = 386, w = 669}, true))
19:18:11                 @ = [NSApplication sharedApplication] with 0 arguments
                         @ = [<NSApplication> mainWindow] with 0 arguments
                         v = [<NSWindow> setFrame:display:] with 2 arguments
nil

> inspect(o.class("NSApplication")("sharedApplication")("mainWindow")("frame"))
19:18:17                 @ = [NSApplication sharedApplication] with 0 arguments
                         @ = [<NSApplication> mainWindow] with 0 arguments
                         {CGRect={CGPoint=dd}{CGSize=dd}} = [<NSWindow> frame] with 0 arguments
{
  __luaSkinType = "NSRect",
  h = 386.0,
  w = 669.0,
  x = 20.0,
  y = 35.0
}
~~~

Previous "show-and-tell"

~~~lua
> hs.luaSkinLog.level = 4 ; o = require("hs._asm.objc")


> ns2 = o.class("NSString")("alloc")("initWithUTF8String:", "goodbye")
21:15:01    LuaSkin:     @ = [NSString alloc] with 0 arguments
                         object: create NSPlaceholderString (0x60200000c350)
                         @ = [<NSPlaceholderString> initWithUTF8String:] with 1 arguments
                         object: create NSTaggedPointerString (0x657962646f6f6775)


> ns = o.class("NSString")("stringWithUTF8String:", "hello")
21:15:14                 @ = [NSString stringWithUTF8String:] with 1 arguments
                         object: create NSTaggedPointerString (0x6f6c6c656855)


> ns3 = o.class("NSString")("alloc")("initWithUTF8String:", "hello")
21:15:24                 @ = [NSString alloc] with 0 arguments
                         object: create NSPlaceholderString (0x60200000c350)
                         @ = [<NSPlaceholderString> initWithUTF8String:] with 1 arguments
                         object: create NSTaggedPointerString (0x6f6c6c656855)


> ns("isEqualToString:", ns2)
21:15:58                 c = [<NSTaggedPointerString> isEqualToString:] with 1 arguments
false

> ns("isEqualToString:", ns3)
21:16:02                 c = [<NSTaggedPointerString> isEqualToString:] with 1 arguments
true
21:16:37                 object: remove NSPlaceholderString (0x60200000c350)
                         object: remove NSPlaceholderString (0x60200000c350)

> ns:value(), ns2:value(), ns3:value()
hello	goodbye	hello
~~~

Use at your own risk!

### License

> The MIT License (MIT)
>
> Copyright (c) 2016 Aaron Magill
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
>
>The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
