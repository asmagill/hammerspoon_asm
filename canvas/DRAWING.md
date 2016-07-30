hs._asm.canvas.drawing
======================

An experimental wrapper, to replace `hs.drawing` with `hs._asm.canvas`.

### Overview

The intention is for this wrapper to provide all of the same functionality that `hs.drawing` does without requiring any additional changes to your currently existing code.

### Known issues/differences between this module and `hs.drawing`:

 * images which are "template images" (i.e. some of the images with names in `hs.image.systemImageNames` and any image retrieved from an `hs.menubar` object) are displayed with an implicit `imageAlpha` of 0.5.  This closely mimics the NSImageView behavior observed with `hs.drawing`, but since Apple has not provided full details on how a template image is rendered when it is *not* used as a template, this is just a guess.

 * image frames from `hs.drawing` are approximated with additional canvas elements inserted into the canvas... the frames always looked semi-ugly to me, and since this module now allows you to create as complex a frame as you like... consider these as "examples", and poor ones at that.  Plus I'm not sure anyone used them anyways -- at the time I only really wanted rotation, the others (frame, alignment, and scaling) were just tacked on because they were available.

### Usage

This submodule is not loaded as part of the `hs._asm.canvas` module and has to be loaded explicitly. You can test the use of this wrapper with your Hammerspoon configuration by adding the following to the ***top*** of `~/.hammerspoon/init.lua` -- this needs to be executed before any other code has a chance to load `hs.drawing` first.

~~~lua
local R, M = pcall(require,"hs._asm.canvas.drawing")
if R then
   print()
   print("**** Replacing internal hs.drawing with experimental wrapper.")
   print()
   hs.drawing = M
   package.loaded["hs.drawing"] = M   -- make sure require("hs.drawing") returns us
   package.loaded["hs/drawing"] = M   -- make sure require("hs/drawing") returns us
   debug.getregistry()["hs.drawing"] = hs.getObjectMetatable("hs._asm.canvas.drawing")
else
   print()
   print("**** Error with experimental hs.drawing wrapper: "..tostring(M))
   print()
end
~~~

If you wish to load both for side-by-side comparisons, you can access the built in drawing module temporarily with: `drawing = dofile(hs.processInfo.resourcePath .. "/extensions/hs/drawing/init.lua")`

To return to using the officially included version of `hs.drawing`, remove or comment out the code that was added to your `init.lua` file.

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

