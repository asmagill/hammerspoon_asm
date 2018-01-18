hs._asm.bonjour
===============

Initial attempts at creating a bonjour module for Hammerspoon. Very experimental and prone to changes.

See [Examples](Examples). I got tired of Safari's removal of the Bonjour browser for HTTP servers on the network.

### TODO (in no particular order):
1. Document
2. Add list of common types; I think I came across a link in Apple's docs that listed common types used by Apple, so include that in a table in the main module.
3. Examine dns-sd... it looks a whole crap-ton more complex, but would allow adding the ability to publish proxy records for other things on the network that don't directly support Bonjour/ZeroConf
4. Test
5. Re-examine `hs.doc.hsdocs`... the built in document browser shouldn't advertise via Bonjour if the interface is set to localhost only (the default). Are there other hidden weirdnesses?

### Installation

If you wish to build this module yourself, and have XCode installed on your Mac, the best way (you are welcome to clone the entire repository if you like, but no promises on the current state of anything else) is to do the following:

~~~sh
$ svn export https://github.com/asmagill/hammerspoon_asm/trunk/bonjour
$ cd bonjour
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
