hs._asm.touchbar
================

A module to display an on-screen representation of the Apple Touch Bar, even on machines which do not have the touch bar.

This code is based heavily on code found at https://github.com/bikkelbroeders/TouchBarDemoApp.  Unlike the code found at the provided link, this module only supports displaying the touch bar window on your computer screen - it does not support display on an attached iDevice.

This module requires that you are running macOS 10.12.1 build 16B2657 or greater.  Most people who have received the 10.12.1 update have an earlier build, which you can check by selecting "About this Mac" from the Apple menu and then clicking the mouse pointer on the version number displayed in the dialog box.  If you require an update, you can find it at https://support.apple.com/kb/dl1897.

If you wish to use this module in an environment where the end-user's machine may not have the correct macOS release version, you should always check the value of `hs._asm.touchbar.supported` before trying to create the Touch Bar and provide your own fallback or message.  Failure to do so will cause your code to break to the Hammerspoon Console when you attempt to create and use the Touch Bar.

Because this module is only supported on machines running a specific build of macOS 10.12.1 or later, you should always co
Check out [Examples/touchbar.lua](Examples/touchbar.lua) for an example of how you might use this module.

### Installation

A precompiled version of this module can be found in this directory with a name along the lines of `touchbar-v0.x.tar.gz`. This can be installed by downloading the file and then expanding it as follows:

~~~sh
$ cd ~/.hammerspoon # or wherever your Hammerspoon init.lua file is located
$ tar -xzf ~/Downloads/touchbar-v0.x.tar.gz # or wherever your downloads are located
~~~

If you wish to build this module yourself, and have XCode installed on your Mac, the best way (you are welcome to clone the entire repository if you like, but no promises on the current state of anything) is to download `init.lua`, `internal.m`, `supported.m` and `Makefile` (at present, nothing else is required) into a directory of your choice and then do the following:

~~~sh
$ cd wherever-you-downloaded-the-files
$ [HS_APPLICATION=/Applications] [PREFIX=~/.hammerspoon] make install
~~~

If your Hammerspoon application is located in `/Applications`, you can leave out the `HS_APPLICATION` environment variable, and if your Hammerspoon files are located in their default location, you can leave out the `PREFIX` environment variable.  For most people it will be sufficient to just type `make install`.

As always, whichever method you chose, if you are updating from an earlier version it is recommended to fully quit and restart Hammerspoon after installing this module to ensure that the latest version of the module is loaded into memory.

### Usage
~~~lua
touchbar = require("hs._asm.touchbar")
~~~

### Contents


##### Module Functions
* <a href="#enabled">touchbar.enabled([state]) -> boolean</a>
* <a href="#new">touchbar.new() -> touchbarObject | nil</a>
* <a href="#supported">touchbar.supported([showLink]) -> boolean</a>

##### Module Methods
* <a href="#acceptsMouseEvents">touchbar:acceptsMouseEvents([state]) -> boolean | touchbarObject</a>
* <a href="#atMousePosition">touchbar:atMousePosition() -> touchbarObject</a>
* <a href="#backgroundColor">touchbar:backgroundColor([color]) -> color | touchbarObject</a>
* <a href="#centered">touchbar:centered([top]) -> touchbarObject</a>
* <a href="#getFrame">touchbar:getFrame() -> table</a>
* <a href="#hide">touchbar:hide([duration]) -> touchbarObject</a>
* <a href="#inactiveAlpha">touchbar:inactiveAlpha([alpha]) -> number | touchbarObject</a>
* <a href="#isVisible">touchbar:isVisible() -> boolean</a>
* <a href="#movable">touchbar:movable([state]) -> boolean | touchbarObject</a>
* <a href="#setCallback">touchbar:setCallback(fn | nil) -> touchbarObject</a>
* <a href="#show">touchbar:show([duration]) -> touchbarObject</a>
* <a href="#toggle">touchbar:toggle([duration]) -> touchbarObject</a>
* <a href="#topLeft">touchbar:topLeft([point]) -> table | touchbarObject</a>

- - -

### Module Functions

~~~lua
touchbar.enabled([state]) -> boolean
~~~
Get or set whether or not the Touch Bar can be used by applications.

Parameters:
 * `state` - an optional boolean specifying whether applications can put items into the touch bar (true) or if this is limited only to the system items (false).

Returns:
 * if an argument is provided, returns a boolean indicating whether or not the change was successful; otherwise returns the current value

Notes:
 * Checking the value of this function does not indicate whether or not the machine *can* support the Touch Bar but rather if it *is* supporting the Touch Bar; Use [hs._asm.touchbar.supported](#supported) to check whether or not the machine *can* support the Touch Bar.

 * Setting this to false will remove all application items from the Touch Bar.

 * On a machine that does not have a physical Touch Bar, this will default to false until the first touch bar is created, after which it will default to true.
 * This function has not been tested on a MacBook Pro with an *actual* Touch Bar, so it is a guess that this will always default to true on such a machine.

- - -

<a name="new"></a>
~~~lua
touchbar.new() -> touchbarObject | nil
~~~
Creates a new touchbarObject representing a window which displays the Apple Touch Bar.

Parameters:
 * None

Returns:
 * the touchbarObject or nil if one could not be created

Notes:
 * The most common reason a touchbarObject cannot be created is if your macOS version is not new enough. Type the following into your Hammerspoon console to check: `require("hs._asm.touchbar").supported(true)`.

- - -

<a name="supported"></a>
~~~lua
touchbar.supported([showLink]) -> boolean
~~~
Returns a boolean value indicathing whether or not the Apple Touch Bar is supported on this Macintosh.

Parameters:
 * `showLink` - a boolean, default false, specifying whether a dialog prompting the user to download the necessary update is presented if Apple Touch Bar support is not found in the current Operating System.

Returns:
 * true if Apple Touch Bar support is found in the current Operating System or false if it is not.

Notes:
 * the link in the prompt is https://support.apple.com/kb/dl1897

### Module Methods

<a name="acceptsMouseEvents"></a>
~~~lua
touchbar:acceptsMouseEvents([state]) -> boolean | touchbarObject
~~~
Get or set whether or not the touch bar accepts mouse events.

Parameters:
 * `state` - an optional boolean which specifies whether the touch bar accepts mouse events (true) or not (false).  Default true.

Returns:
 * if an argument is provided, returns the touchbarObject; otherwise returns the current value.

Notes:
 * This method can be used to prevent mouse clicks in the touch bar from triggering the touch bar buttons.
 * This can be useful when [hs._asm.touchbar:movable](#movable) is set to true to prevent accidentally triggering an action.

- - -

<a name="atMousePosition"></a>
~~~lua
touchbar:atMousePosition() -> touchbarObject
~~~
Moves the touch bar window so that it is centered directly underneath the mouse pointer.

Parameters:
 * None

Returns:
 * the touchbarObject

Notes:
 * This method mimics the display location as set by the sample code this module is based on.  See https://github.com/bikkelbroeders/TouchBarDemoApp for more information.
 * The touch bar position will be adjusted so that it is fully visible on the screen even if this moves it left or right from the mouse's current position.

- - -

<a name="backgroundColor"></a>
~~~lua
touchbar:backgroundColor([color]) -> color | touchbarObject
~~~
Get or set the background color for the touch bar window.

Parameters:
 * `color` - an optional color table as defined in `hs.drawing.color` specifying the background color for the touch bar window.  Defaults to black, i.e. `{ white = 0.0, alpha = 1.0 }`.

Returns:
 * if an argument is provided, returns the touchbarObject; otherwise returns the current value.

Notes:
 * The visual effect of this method is to change the border color around the touch bar -- the touch bar itself remains the color as defined by the application which is providing the current touch bar items for display.

- - -

<a name="centered"></a>
~~~lua
touchbar:centered([top]) -> touchbarObject
~~~
Moves the touch bar window to the top or bottom center of the main screen.

Parameters:
 * `top` - an optional boolean, default false, specifying whether the touch bar should be centered at the top (true) of the screen or at the bottom (false).

Returns:
 * the touchbarObject

- - -

<a name="getFrame"></a>
~~~lua
touchbar:getFrame() -> table
~~~
Gets the frame of the touch bar window

Parameters:
 * None

Returns:
 * a frame table with key-value pairs specifying the top left corner of the touch bar window and its width and height.

Notes:
 * A frame table is a table with at least `x`, `y`, `h` and `w` key-value pairs which specify the coordinates on the computer screen of the window and its width (w) and height(h).
 * This allows you to get the frame so that you can include its height and width in calculations - it does not allow you to change the size of the touch bar window itself.

- - -

<a name="hide"></a>
~~~lua
touchbar:hide([duration]) -> touchbarObject
~~~
Display the touch bar window with an optional fade-out delay.

Parameters:
 * `duration` - an optional number, default 0.0, specifying the fade-out time for the touch bar window.

Returns:
 * the touchbarObject

Notes:
 * This method does nothing if the window is already hidden.
 * The value used in the sample code referenced in the module header is 0.1.

- - -

<a name="inactiveAlpha"></a>
~~~lua
touchbar:inactiveAlpha([alpha]) -> number | touchbarObject
~~~
Get or set the alpha value for the touch bar window when the mouse is not hovering over it.

Parameters:
 * alpha - an optional number between 0.0 and 1.0 inclusive specifying the alpha value for the touch bar window when the mouse is not over it.  Defaults to 0.5.

Returns:
 * if a value is provided, returns the touchbarObject; otherwise returns the current value

- - -

<a name="isVisible"></a>
~~~lua
touchbar:isVisible() -> boolean
~~~
Returns a boolean indicating whether or not the touch bar window is current visible.

Parameters:
 * None

Returns:
 * a boolean specifying whether the touch bar window is visible (true) or not (false).

- - -

<a name="movable"></a>
~~~lua
touchbar:movable([state]) -> boolean | touchbarObject
~~~
Get or set whether or not the touch bar window is movable by clicking on it and holding down the mouse button while moving the mouse.

Parameters:
 * `state` - an optional boolean which specifies whether the touch bar window is movable (true) or not (false).  Default false.

Returns:
 * if an argument is provided, returns the touchbarObject; otherwise returns the current value.

Notes:
 * While the touch bar is movable, actions which require moving the mouse while clicking on the touch bar are not accessible.
 * See also [hs._asm.touchbar:acceptsMouseEvents](#acceptsMouseEvents).

- - -

<a name="setCallback"></a>
~~~lua
touchbar:setCallback(fn | nil) -> touchbarObject
~~~
Sets the callback function for the touch bar window.

Parameters:
 * `fn` - a function to set as the callback for the touch bar window, or nil to remove the existing callback function.

Returns:
 * the touchbarObject

Notes:
 * The function should expect 2 arguments and return none.  The arguments will be one of the following:

   * obj, "didEnter" - indicates that the mouse pointer has entered the window containing the touch bar
     * `obj`     - the touchbarObject the callback is for
     * `message` - the message to the callback, in this case "didEnter"

   * obj, "didExit" - indicates that the mouse pointer has exited the window containing the touch bar
     * `obj`     - the touchbarObject the callback is for
     * `message` - the message to the callback, in this case "didEnter"

- - -

<a name="show"></a>
~~~lua
touchbar:show([duration]) -> touchbarObject
~~~
Display the touch bar window with an optional fade-in delay.

Parameters:
 * `duration` - an optional number, default 0.0, specifying the fade-in time for the touch bar window.

Returns:
 * the touchbarObject

Notes:
 * This method does nothing if the window is already visible.

- - -

<a name="toggle"></a>
~~~lua
touchbar:toggle([duration]) -> touchbarObject
~~~
Toggle's the visibility of the touch bar window.

Parameters:
 * `duration` - an optional number, default 0.0, specifying the fade-in/out time when changing the visibility of the touch bar window.

Returns:
 * the touchbarObject

- - -

<a name="topLeft"></a>
~~~lua
touchbar:topLeft([point]) -> table | touchbarObject
~~~
Get or set the top-left of the touch bar window.

Parameters:
 * `point` - an optional table specifying where the top left of the touch bar window should be moved to.

Returns:
 * if a value is provided, returns the touchbarObject; otherwise returns the current value.

Notes:
 * A point table is a table with at least `x` and `y` key-value pairs which specify the coordinates on the computer screen where the window should be moved to.  Hammerspoon considers the upper left corner of the primary screen to be { x = 0.0, y = 0.0 }.

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

