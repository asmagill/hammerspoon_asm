hs._asm.canvas.progress
=======================

A Hammerspoon module which allows the creation and manipulation of progress indicators for use as a `view` element in `hs._asm.canvas`.

This sub-module provides a new type of view which can be assigned to the `view` attribute of and `hs._asm.canvas` element of type `view`.  This module requires `hs._asm.canvas` to actual display the content, but all control of this view type is provided by this module.

This submodule is provided as an example of providing external content for use within `hs._asm.canvas`.  A more thorough HOW-TO is being considered, as this example does not take advantage of any of the special method calls that Canvas can support.

### Installation

This submodule requires that you have `hs._asm.canvas` version 0.10 or newer already installed.

A precompiled version of this module may be found in this directory with the name `progress-v0.x.tar.gz`. This can be installed by downloading the file and then expanding it as follows:

~~~sh
$ cd ~/.hammerspoon # or wherever your Hammerspoon init.lua file is located
$ tar -xzf ~/Downloads/progress-v0.x.tar.gz # or wherever your downloads are located
~~~

If you wish to build this module yourself, and have XCode installed on your Mac, the best way (you are welcome to clone the entire repository if you like, but no promises on the current state of anything else) is to download `init.lua`, `internal.m`, and `Makefile` into a directory of your choice and then do the following:

~~~sh
$ cd wherever-you-downloaded-the-files
$ [HS_APPLICATION=/Applications] [PREFIX=~/.hammerspoon] make install
~~~

If your Hammerspoon application is located in `/Applications`, you can leave out the `HS_APPLICATION` environment variable, and if your Hammerspoon files are located in their default location, you can leave out the `PREFIX` environment variable.  For most people it will be sufficient to just type `make install`.

As always, whichever method you chose, if you are updating from an earlier version it is recommended to fully quit and restart Hammerspoon after installing this module to ensure that the latest version of the module is loaded into memory.


### Usage
~~~lua
progress = require("hs._asm.canvas.progress")
~~~

### Contents


##### Module Methods
* <a href="#bezeled">progress:bezeled([flag]) -> progressObject | current value</a>
* <a href="#circular">progress:circular([flag]) -> progressObject | current value</a>
* <a href="#color">progress:color(color) -> progressObject</a>
* <a href="#increment">progress:increment(value) -> progressObject | current value</a>
* <a href="#indeterminate">progress:indeterminate([flag]) -> progressObject | current value</a>
* <a href="#indicatorSize">progress:indicatorSize([size]) -> progressObject | current value</a>
* <a href="#max">progress:max([value]) -> progressObject | current value</a>
* <a href="#min">progress:min([value]) -> progressObject | current value</a>
* <a href="#start">progress:start() -> progressObject</a>
* <a href="#stop">progress:stop() -> progressObject</a>
* <a href="#threaded">progress:threaded([flag]) -> progressObject | current value</a>
* <a href="#tint">progress:tint([tint]) -> progressObject | current value</a>
* <a href="#value">progress:value([value]) -> progressObject | current value</a>
* <a href="#visibleWhenStopped">progress:visibleWhenStopped([flag]) -> progressObject | current value</a>

- - -

### Module Methods

<a name="bezeled"></a>
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

- - -

<a name="circular"></a>
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

- - -

<a name="color"></a>
~~~lua
progress:color(color) -> progressObject
~~~
Sets the fill color for a progress indicator.

Parameters:
 * color - a table specifying a color as defined in `hs.drawing.color` indicating the color to use for the progress indicator.

Returns:
 * the progress indicator object

Notes:
 * This method is not based upon the methods inherent in the NSProgressIndicator Objective-C class, but rather on code found at http://stackoverflow.com/a/32396595 utilizing a CIFilter object to adjust the view's output.
 * Because the filter must be applied differently depending upon the progress indicator style, make sure to invoke this method *after* [hs._asm.canvas.progress:circular](#circular).

- - -

<a name="increment"></a>
~~~lua
progress:increment(value) -> progressObject | current value
~~~
Increment the current value of a progress indicator's progress by the amount specified.

Parameters:
 * value - the value by which to increment the progress indicator's current value.

Returns:
 * the progress indicator object

Notes:
 * Programmatically, this is equivalent to `hs._asm.canvas.progress:value(hs._asm.canvas.progress:value() + value)`.

- - -

<a name="indeterminate"></a>
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
 * If this setting is set to false, you should also take a look at [hs._asm.canvas.progress:min](#min) and [hs._asm.canvas.progress:max](#max), and periodically update the status with [hs._asm.canvas.progress:value](#value) or [hs._asm.canvas.progress:increment](#increment)

- - -

<a name="indicatorSize"></a>
~~~lua
progress:indicatorSize([size]) -> progressObject | current value
~~~
Get or set the indicator's size.

Parameters:
 * size - an optional string specifying the size of the progress indicator object.  May be one of "regular", "small", or "mini".

Returns:
 * if a value is provided, returns the progress indicator object ; otherwise returns the current value.

Notes:
 * The default setting for this is "regular".
 * For circular indicators, the sizes seem to be 32x32, 16x16, and 10x10 in 10.11.
 * For bar indicators, the height seems to be 20 and 12; the mini size seems to be ignored, at least in 10.11.

- - -

<a name="max"></a>
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
 * For a determinate indicator, the behavior is undefined if this value is less than [hs._asm.canvas.progress:min](#min).

- - -

<a name="min"></a>
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
 * For a determinate indicator, the behavior is undefined if this value is greater than [hs._asm.canvas.progress:max](#max).

- - -

<a name="start"></a>
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

- - -

<a name="stop"></a>
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

- - -

<a name="threaded"></a>
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

- - -

<a name="tint"></a>
~~~lua
progress:tint([tint]) -> progressObject | current value
~~~
Get or set the indicator's tint.

Parameters:
 * tint - an optional string specifying the tint of the progress indicator.  May be one of "Default", "blue", "graphite", or "clear".

Returns:
 * if a value is provided, returns the progress indicator object ; otherwise returns the current value.

Notes:
 * The default setting for this is "default".
 * In my testing, this setting does not seem to have much, if any, effect on the visual aspect of the indicator and is provided in this module in case this changes in a future OS X update (there are some indications that it may have had an effect in previous versions).

- - -

<a name="value"></a>
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
 * For a determinate indicator, this will affect how "filled" the bar or circle is.  If the value is lower than [hs._asm.canvas.progress:min](#min), then it will be reset to that value.  If the value is greater than [hs._asm.canvas.progress:max](#max), then it will be reset to that value.

- - -

<a name="visibleWhenStopped"></a>
~~~lua
progress:visibleWhenStopped([flag]) -> progressObject | current value
~~~
Get or set whether or not the progress indicator is visible when animation has been stopped.

Parameters:
 * flag - an optional boolean indicating whether or not the progress indicator is visible when animation has stopped.

Returns:
 * if a value is provided, returns the progress indicator object ; otherwise returns the current value.

Notes:
 * The default setting for this is true.

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

