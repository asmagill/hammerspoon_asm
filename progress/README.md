hs._asm.progress
================

This module provides access to progress indicators used by the operating system to show progress and when an application is busy.


This is still a work in progress, but is stable.  Documentation and installation instructions will be updated in the near future.

### Installation

Compiled versions of this module can be found in the _`releases` folder at the top-level of this repository.  You can download the release and install it by expanding it in your `~/.hammerspoon/` directory (or any other directory in your `package.path` and `package.cpath` search paths):

~~~bash
cd ~/.hammerspoon
tar -xzf ~/Downloads/progress-vX.Y.tar.gz # or wherever your downloads are saved
~~~

If this doesn't work for you, or you want to build the latest and greatest, follow the directions below:

This does require that you have XCode or the XCode Command Line Tools installed.  See the App Store application or https://developer.apple.com to install these if necessary.

~~~bash
$ git clone https://github.com/asmagill/hammerspoon_asm
$ cd hammerspoon_asm/progress
$ [HS_APPLICATION=/Applications] [PREFIX=~/.hammerspoon] make install
~~~

If Hammerspoon.app is in your /Applications folder, you may leave `HS_APPLICATION=/Applications` out and if you are fine with the module being installed in your Hammerspoon configuration directory, you may leave `PREFIX=~/.hammerspoon` out as well.  For most people, it will probably be sufficient to just type `make install`.

In either case, if you are upgrading over a previous installation of this module, you must completely quit and restart Hammerspoon before the new version will be fully recognized.

### Usage
~~~lua
progress = require("hs._asm.progress")
~~~

### Module Functions

~~~lua
progress.new(rect) -> progressObject
~~~
Create a new progress indicator object at the specified location and size.

Parameters:
 * rect - a table containing the rectangular coordinates of the progress indicator and its background.

Returns:
 * a progress indicator object

Notes:
 * Depending upon the type and size of the indicator, the actual indicator's size varies.  As of 10.11, the observed sizes are:
   * circular - between 10 and 32 for width and height, depending upon size
   * bar      - between 12 and 20 for height, depending upon size.
 * The rectangle defined in this function reflects a rectangle in which the indicator is centered.  This is to facilitate drawing an opaque or semi-transparent "shade" over content, if desired, while performing some task for which the indicator is being used to indicate activity.  This shade is set to a light grey semi-transparent color (defined in `hs.drawing.color` as { white = 0.75, alpha = 0.75 }).

### Module Methods

~~~lua
progress:backgroundColor([color]) -> progressObject
~~~
Get or set the color of the progress indicator's background.

Parameters:
 * color - an optional table specifying a color as defined in `hs.drawing.color` for the progress indicator's background.

Returns:
 * if a value is provided, returns the progress indicator object ; otherwise returns the current value.

_ _ _

~~~lua
progress:bezeled([flag]) -> progressObject | current value
~~~
Get or set whether or not the progress indicator’s frame has a three-dimensional bezel.

Parameters:
 * flag - an optional boolean indicating whether or not the indicator's frame is bezeled.

Returns:
 * if a value is provided, returns the progress indicator object ; otherwise returns the current value.

Notes:
 * The default setting for this is true.
 * In my testing, this setting does not seem to have much, if any, effect on the visual aspect of the indicator and is provided in this module in case this changes in a future OS X update (there are some indications that it may have had an effect in previous versions).

_ _ _

~~~lua
progress:delete() -> none
~~~
Close and remove a progress indicator.

Parameters:
 * None

Returns:
 * None

Notes:
 * This method is called automatically during garbage collection (most notably, when Hammerspoon is exited or the Hammerspoon configuration is reloaded).

_ _ _

~~~lua
progress:circular([flag]) -> progressObject | current value
~~~
Get or set whether or not the progress indicator is circular or a in the form of a progress bar.

Parameters:
 * flag - an optional boolean indicating whether or not the indicator is circular (true) or a progress bar (false)

Returns:
 * if a value is provided, returns the progress indicator object ; otherwise returns the current value.

Notes:
 * The default setting for this is false.
 * An indeterminate circular indicator is displayed as the spinning star seen during system startup.
 * A determinate circular indicator is displayed as a pie chart which fills up as its value increases.
 * An indeterminate progress indicator is displayed as a rounded rectangle with a moving pulse.
 * A determinate progress indicator is displayed as a rounded rectangle that fills up as its value increases.

_ _ _

~~~lua
progress:displayWhenStopped([flag]) -> progressObject | current value
~~~
Get or set whether or not the progress indicator is visible when animation has been stopped.

Parameters:
 * flag - an optional boolean indicating whether or not the progress indicator is visible when animation has stopped.

Returns:
 * if a value is provided, returns the progress indicator object ; otherwise returns the current value.

Notes:
 * The default setting for this is true.
 * The background is not hidden by this method when animation is not running, only the indicator itself.

_ _ _

~~~lua
progress:frame([rect]) -> progressObject
~~~
Get or set the frame of the the progress indicator and its background.

Parameters:
 * rect - an optional table containing the rectangular coordinates of the progress indicator and its background.

Returns:
 * if a value is provided, returns the progress indicator object ; otherwise returns the current value.

_ _ _

~~~lua
progress:hide() -> progressObject
~~~
Hides the progress indicator and its background.

Parameters:
 * None

Returns:
 * the progress indicator object

_ _ _

~~~lua
progress:indeterminate([flag]) -> progressObject | current value
~~~
Get or set whether or not the progress indicator is indeterminate.  A determinate indicator displays how much of the task has been completed. An indeterminate indicator shows simply that the application is busy.

Parameters:
 * flag - an optional boolean indicating whether or not the indicator is indeterminate.

Returns:
 * if a value is provided, returns the progress indicator object ; otherwise returns the current value.

Notes:
 * The default setting for this is true.
 * If this setting is set to false, you should also take a look at [hs._asm.progress:min](#min) and [hs._asm.progress:max](#max), and periodically update the status with [hs._asm.progress:value](#value) or [hs._asm.progress:increment](#increment)

_ _ _

~~~lua
progress:increment(value) -> progressObject | current value
~~~
Increment the current value of a progress indicator's progress by the amount specified.

Parameters:
 * value - the value by which to increment the progress indicator's current value.

Returns:
 * the progress indicator object

Notes:
 * Programmatically, this is equivalent to `hs._asm.progress:value(hs._asm.progress:value() + value)`, but is faster.

_ _ _

~~~lua
progress:indicatorSize([size]) -> progressObject | current value
~~~
Get or set the indicator's size.

Parameters:
 * size - an optional integer matching one of the values in [hs._asm.progress.controlSize](#controlSize), which indicates the desired size of the indicator.

Returns:
 * if a value is provided, returns the progress indicator object ; otherwise returns the current value.

Notes:
 * The default setting for this is 0, which corresponds to `hs._asm.progress.controlSize.regular`.
 * For circular indicators, the sizes seem to be 32x32, 16x16, and 10x10 in 10.11.
 * For bar indicators, the height seems to be 20 and 12; the mini size seems to be ignored, at least in 10.11.

_ _ _

~~~lua
progress:level([level]) -> progressObject | current value
~~~
Get or set the window level of the progress indicator.

Parameters:
 * level - an optional integer representing the window level, as defined in `hs.drawing.windowLevels`, you wish the progress indicator to be moved to.

Returns:
 * if a value is provided, returns the progress indicator object ; otherwise returns the current value.

Notes:
 * the default level is defined as `hs.drawing.windowLevels.screenSaver`

_ _ _

~~~lua
progress:max([value]) -> progressObject | current value
~~~
Get or set the maximum value (the value at which the progress indicator should display as full) for the progress indicator.

Parameters:
 * value - an optional number indicating the maximum value.

Returns:
 * if a value is provided, returns the progress indicator object ; otherwise returns the current value.

Notes:
 * The default value for this is 100.0
 * This value has no effect on the display of an indeterminate progress indicator.
 * For a determinate indicator, the behavior is undefined if this value is less than [hs._asm.progress:min](#min).

_ _ _

~~~lua
progress:min([value]) -> progressObject | current value
~~~
Get or set the minimum value (the value at which the progress indicator should display as empty) for the progress indicator.

Parameters:
 * value - an optional number indicating the minimum value.

Returns:
 * if a value is provided, returns the progress indicator object ; otherwise returns the current value.

Notes:
 * The default value for this is 0.0
 * This value has no effect on the display of an indeterminate progress indicator.
 * For a determinate indicator, the behavior is undefined if this value is greater than [hs._asm.progress:max](#max).

_ _ _

~~~lua
progress:setFillColor(color) -> progressObject
~~~
Sets the fill color for a progress indicator.

Parameters:
 * color - a table specifying a color as defined in `hs.drawing.color` indicating the color to use for the progress indicator.

Returns:
 * the progress indicator object

Notes:
 * This method is not based upon the methods inherent in the NSProgressIndicator Objective-C class, but rather on code found at http://stackoverflow.com/a/32396595 utilizing a CIFilter object to adjust the view's output.
 * For circular and determinate bar progress indicators, this method works as expected.
 * For indeterminate bar progress indicators, this method will set the entire bar to the color specified and no animation effect is apparent.  Hopefully this is a temporary limitation.

_ _ _

~~~lua
progress:setSize(size) -> progressObject
~~~
Sets the size of the indicator's background.

Parameters:
 * size - a table containing a keys for h and w, specifying the size of the indicators background.

Returns:
 * the progress indicator object

_ _ _

~~~lua
progress:setTopLeft(point) -> progressObject
~~~
Sets the top left point of the progress objects background.

Parameters:
 * point - a table containing a keys for x and y, specifying the top left point to move the indicator and its background to.

Returns:
 * the progress indicator object

_ _ _

~~~lua
progress:show() -> progressObject
~~~
Displays the progress indicator and its background.

Parameters:
 * None

Returns:
 * the progress indicator object

_ _ _

~~~lua
progress:start() -> progressObject
~~~
If the progress indicator is indeterminate, starts the animation for the indicator.

Parameters:
 * None

Returns:
 * the progress indicator object

Notes:
 * This method has no effect if the indicator is not indeterminate.

_ _ _

~~~lua
progress:stop() -> progressObject
~~~
If the progress indicator is indeterminate, stops the animation for the indicator.

Parameters:
 * None

Returns:
 * the progress indicator object

Notes:
 * This method has no effect if the indicator is not indeterminate.

_ _ _

~~~lua
progress:threaded([flag]) -> progressObject | current value
~~~
Get or set whether or not the animation for an indicator occurs in a separate process thread.

Parameters:
 * flag - an optional boolean indicating whether or not the animation for the indicator should occur in a separate thread.

Returns:
 * if a value is provided, returns the progress indicator object ; otherwise returns the current value.

Notes:
 * The default setting for this is true.
 * If this flag is set to false, the indicator animation speed will fluctuate as Hammerspoon performs other activities, though not consistently enough to provide a reliable "activity level" feedback indicator.

_ _ _

~~~lua
progress:tint([tint]) -> progressObject | current value
~~~
Get or set the indicator's tint.

Parameters:
 * tint - an optional integer matching one of the values in [hs._asm.progress.controlTint](#controlTint), which indicates the tint of the progress indicator.

Returns:
 * if a value is provided, returns the progress indicator object ; otherwise returns the current value.

Notes:
 * The default setting for this is 0, which corresponds to `hs._asm.progress.controlTint.default`.
 * In my testing, this setting does not seem to have much, if any, effect on the visual aspect of the indicator and is provided in this module in case this changes in a future OS X update (there are some indications that it may have had an effect in previous versions).

_ _ _

~~~lua
progress:value([value]) -> progressObject | current value
~~~
Get or set the current value of the progress indicator's completion status.

Parameters:
 * value - an optional number indicating the current extent of the progress.

Returns:
 * if a value is provided, returns the progress indicator object ; otherwise returns the current value.

Notes:
 * The default value for this is 0.0
 * This value has no effect on the display of an indeterminate progress indicator.
 * For a determinate indicator, this will affect how "filled" the bar or circle is.  If the value is lower than [hs._asm.progress:min](#min), then it will be reset to that value.  If the value is greater than [hs._asm.progress:max](#max), then it will be reset to that value.

### Module Constants

~~~lua
progress.controlSize[]
~~~
A table containing key-value pairs defining recognized sizes which can be used with the [hs._asm.progress:indicatorSize](#indicatorSize) method.

Contents:
 * regular - display the indicator at its regular size
 * small   - display a smaller version of the indicator
 * mini    - for circular indicators, display an even smaller version; for bar indicators, this setting has no effect.

_ _ _

~~~lua
progress.controlTint[]
~~~
A table containing key-value pairs defining recognized tints which can be used with the [hs._asm.progress:tint](#tint) method.

Contents:
 * default
 * blue
 * graphite
 * clear

Notes:
 * In my testing, setting `hs._asm.progress:tint` does not seem to have much, if any, effect on the visual aspect of an indicator and this table is provided in this module in case this changes in a future OS X update (there are some indications that it may have had an effect in previous versions).

### License

> The MIT License (MIT)
>
> Copyright (c) 2015 Aaron Magill
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
