hs._asm.consolepipe
===================

Tap into Hammerspoon's stderr and stdout streams.

`stdout` seems to be constantly outputting a stream of characters, but I haven't determined what they represent yet, if anything.

`stderr` contains the messages from Hammerspoon which are sent to the system logs and are traditionally viewed from the Console application.

Probably not that useful, but interesting none-the-less.

### Installation

This does require that you have XCode or the XCode Command Line Tools installed.  See the App Store application or https://developer.apple.com to install these if necessary.

~~~bash
$ git clone https://github.com/asmagill/hammerspoon_asm
$ cd hammerspoon_asm/consolepipe
$ [HS_APPLICATION=/Applications] [PREFIX=~/.hammerspoon] make install
~~~

If Hammerspoon.app is in your /Applications folder, you may leave `HS_APPLICATION=/Applications` out and if you are fine with the module being installed in your Hammerspoon configuration directory, you may leave `PREFIX=~/.hammerspoon` out as well.  For most people, it will probably be sufficient to just type `make install`.

### Usage
~~~lua
consolepipe = require("hs._asm.consolepipe")
~~~

### Module Constructors

<a name="new"></a>
~~~lua
consolepipe.new(stream) -> consolePipe object
~~~
Create a stream watcher.

Parameters:
 * stream - a string of "stdout" or "stderr" specifying which stream to create the watcher for.

Returns:
 * the consolePipe object

### Module Methods

<a name="delete"></a>
~~~lua
consolepipe:delete() -> none
~~~
Deletes the stream callback and releases the callback function.  This method is called automatically during reload.

Parameters:
 * None

Returns:
 * None

- - -

<a name="setCallback"></a>
~~~lua
consolepipe:setCallback(fn | nil) -> consolePipe object
~~~
Set or remove the callback function for the stream.

Parameters:
 * fn - a function, or an explicit nil to remove, to be installed as the callback when data is available on the stream.  The callback should expect one parameter -- a string containing the data which has been sent to the stream.

Returns:
 * the consolePipe object

- - -

<a name="start"></a>
~~~lua
consolepipe:start() -> consolePipe object
~~~
Starts calling the callback function when data becomes available on the attached stream.

Parameters:
 * None

Returns:
 * the consolePipe object

- - -

<a name="stop"></a>
~~~lua
consolepipe:stop() -> consolePipe object
~~~
Suspends calling the callback function when data becomes available on the attached stream.

Parameters:
 * None

Returns:
 * the consolePipe object

### License

> Released under MIT license.
>
> Copyright (c) 2016 Aaron Magill
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
