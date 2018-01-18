hs._asm.diskarbitration
=======================

Initial attempts at creating a diskarbitration module for Hammerspoon. Very experimental and prone to changes.

Provides a better interface to mounting/dismounting volumes then `hs.fs.volume`. I'm hoping it will eventually also allow intercepting the auto-mounting of newly inserted devices (SD Cards, etc.) that are intended for use within a virtual machine that isn't running yet (so capturing the device doesn't occur) and prevent the creation of the hidden files macOS uses for volume services.

I'm a little disappointed that the current unmount/eject callbacks don't tell me *why* the operation failed (e.g. "Terminal is using the device"), but it's still asynchronous and non-blocking unlike `hs.fs.volume`, so that's a plus.

### TODO (in no particular order):
1. Document
2. Add watchers for mount/unmount
3. Add callbacks for mount/unmount approval?
4. For watchers/callbacks figure out matching criteria and probably include either a list of common keys in a constants table or helper functions to build common scenarios (e.g. only SD cards, devices with a certain name, etc.)
5. Test

### Installation

If you wish to build this module yourself, and have XCode installed on your Mac, the best way (you are welcome to clone the entire repository if you like, but no promises on the current state of anything else) is to do the following:

~~~sh
$ svn export https://github.com/asmagill/hammerspoon_asm/trunk/diskarbitration
$ cd diskarbitration
$ [HS_APPLICATION=/Applications] [PREFIX=~/.hammerspoon] make install
~~~

If your Hammerspoon application is located in `/Applications`, you can leave out the `HS_APPLICATION` environment variable, and if your Hammerspoon files are located in their default location, you can leave out the `PREFIX` environment variable.  For most people it will be sufficient to just type `make docs install`.

As always, if you are updating from an earlier version it is recommended to fully quit and restart Hammerspoon after installing this module to ensure that the latest version of the module is loaded into memory.

### License

> Released under MIT license.
>
> Copyright (c) 2018 Aaron Magill
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
>
