hs._asm.progress
================

This module provides access to progress indicators used by the operating system to show progress and when an application is busy.


This is still a work in progress, but is stable.  Documentation and installation instructions will be updated in the near future.



#pragma mark - Module Functions

/// hs._asm.progress.new(rect) -> progressObject
/// Constructor
/// Create a new progress indicator object at the specified location and size.
///
/// Parameters:
///  * rect - a table containing the rectangular coordinates of the progress indicator and its background.
///
/// Returns:
///  * a progress indicator object
///
/// Notes:
///  * Depending upon the type and size of the indicator, the actual indicator's size varies.  As of 10.11, the observed sizes are:
///    * circular - between 10 and 32 for width and height, depending upon size
///    * bar      - between 12 and 20 for height, depending upon size.
///  * The rectangle defined in this function reflects a rectangle in which the indicator is centered.  This is to facilitate drawing an opaque or semi-transparent "shade" over content, if desired, while performing some task for which the indicator is being used to indicate activity.  This shade is set to a light grey semi-transparent color (defined in `hs.drawing.color` as { white = 0.75, alpha = 0.75 }).

#pragma mark - Module Methods

/// hs._asm.progress:show() -> progressObject
/// Method
/// Displays the progress indicator and its background.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the progress indicator object



/// hs._asm.progress:level([level]) -> progressObject | current value
/// Method
/// Get or set the window level of the progress indicator.
///
/// Parameters:
///  * level - an optional integer representing the window level, as defined in `hs.drawing.windowLevels`, you wish the progress indicator to be moved to.
///
/// Returns:
///  * if a value is provided, returns the progress indicator object ; otherwise returns the current value.
///
/// Notes:
///  * the default level is defined as `hs.drawing.windowLevels.screenSaver`



/// hs._asm.progress:hide() -> progressObject
/// Method
/// Hides the progress indicator and its background.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the progress indicator object



/// hs._asm.progress:start() -> progressObject
/// Method
/// If the progress indicator is indeterminate, starts the animation for the indicator.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the progress indicator object
///
/// Notes:
///  * This method has no effect if the indicator is not indeterminate.



/// hs._asm.progress:stop() -> progressObject
/// Method
/// If the progress indicator is indeterminate, stops the animation for the indicator.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the progress indicator object
///
/// Notes:
///  * This method has no effect if the indicator is not indeterminate.



/// hs._asm.progress:threaded([flag]) -> progressObject | current value
/// Method
/// Get or set whether or not the animation for an indicator occurs in a separate process thread.
///
/// Parameters:
///  * flag - an optional boolean indicating whether or not the animation for the indicator should occur in a separate thread.
///
/// Returns:
///  * if a value is provided, returns the progress indicator object ; otherwise returns the current value.
///
/// Notes:
///  * The default setting for this is true.
///  * If this flag is set to false, the indicator animation speed will fluctuate as Hammerspoon performs other activities, though not consistently enough to provide a reliable "activity level" feedback indicator.



/// hs._asm.progress:indeterminate([flag]) -> progressObject | current value
/// Method
/// Get or set whether or not the progress indicator is indeterminate.  A determinate indicator displays how much of the task has been completed. An indeterminate indicator shows simply that the application is busy.
///
/// Parameters:
///  * flag - an optional boolean indicating whether or not the indicator is indeterminate.
///
/// Returns:
///  * if a value is provided, returns the progress indicator object ; otherwise returns the current value.
///
/// Notes:
///  * The default setting for this is true.
///  * If this setting is set to false, you should also take a look at [hs._asm.progress:min](#min) and [hs._asm.progress:max](#max), and periodically update the status with [hs._asm.progress:value](#value) or [hs._asm.progress:increment](#increment)



/// hs._asm.progress:bezeled([flag]) -> progressObject | current value
/// Method
/// Get or set whether or not the progress indicator’s frame has a three-dimensional bezel.
///
/// Parameters:
///  * flag - an optional boolean indicating whether or not the indicator's frame is bezeled.
///
/// Returns:
///  * if a value is provided, returns the progress indicator object ; otherwise returns the current value.
///
/// Notes:
///  * The default setting for this is true.
///  * In my testing, this setting does not seem to have much, if any, effect on the visual aspect of the indicator and is provided in this module in case this changes in a future OS X update (there are some indications that it may have had an effect in previous versions).



/// hs._asm.progress:displayWhenStopped([flag]) -> progressObject | current value
/// Method
/// Get or set whether or not the progress indicator is visible when animation has been stopped.
///
/// Parameters:
///  * flag - an optional boolean indicating whether or not the progress indicator is visible when animation has stopped.
///
/// Returns:
///  * if a value is provided, returns the progress indicator object ; otherwise returns the current value.
///
/// Notes:
///  * The default setting for this is true.
///  * The background is not hidden by this method when animation is not running, only the indicator itself.



/// hs._asm.progress:circular([flag]) -> progressObject | current value
/// Method
/// Get or set whether or not the progress indicator is circular or a in the form of a progress bar.
///
/// Parameters:
///  * flag - an optional boolean indicating whether or not the indicator is circular (true) or a progress bar (false)
///
/// Returns:
///  * if a value is provided, returns the progress indicator object ; otherwise returns the current value.
///
/// Notes:
///  * The default setting for this is false.
///  * An indeterminate circular indicator is displayed as the spinning star seen during system startup.
///  * A determinate circular indicator is displayed as a pie chart which fills up as its value increases.
///  * An indeterminate progress indicator is displayed as a rounded rectangle with a moving pulse.
///  * A determinate progress indicator is displayed as a rounded rectangle that fills up as its value increases.



/// hs._asm.progress:value([value]) -> progressObject | current value
/// Method
/// Get or set the current value of the progress indicator's completion status.
///
/// Parameters:
///  * value - an optional number indicating the current extent of the progress.
///
/// Returns:
///  * if a value is provided, returns the progress indicator object ; otherwise returns the current value.
///
/// Notes:
///  * The default value for this is 0.0
///  * This value has no effect on the display of an indeterminate progress indicator.
///  * For a determinate indicator, this will affect how "filled" the bar or circle is.  If the value is lower than [hs._asm.progress:min](#min), then it will be reset to that value.  If the value is greater than [hs._asm.progress:max](#max), then it will be reset to that value.



/// hs._asm.progress:min([value]) -> progressObject | current value
/// Method
/// Get or set the minimum value (the value at which the progress indicator should display as empty) for the progress indicator.
///
/// Parameters:
///  * value - an optional number indicating the minimum value.
///
/// Returns:
///  * if a value is provided, returns the progress indicator object ; otherwise returns the current value.
///
/// Notes:
///  * The default value for this is 0.0
///  * This value has no effect on the display of an indeterminate progress indicator.
///  * For a determinate indicator, the behavior is undefined if this value is greater than [hs._asm.progress:max](#max).



/// hs._asm.progress:max([value]) -> progressObject | current value
/// Method
/// Get or set the maximum value (the value at which the progress indicator should display as full) for the progress indicator.
///
/// Parameters:
///  * value - an optional number indicating the maximum value.
///
/// Returns:
///  * if a value is provided, returns the progress indicator object ; otherwise returns the current value.
///
/// Notes:
///  * The default value for this is 100.0
///  * This value has no effect on the display of an indeterminate progress indicator.
///  * For a determinate indicator, the behavior is undefined if this value is less than [hs._asm.progress:min](#min).



/// hs._asm.progress:increment(value) -> progressObject | current value
/// Method
/// Increment the current value of a progress indicator's progress by the amount specified.
///
/// Parameters:
///  * value - the value by which to increment the progress indicator's current value.
///
/// Returns:
///  * the progress indicator object
///
/// Notes:
///  * Programmatically, this is equivalent to `hs._asm.progress:value(hs._asm.progress:value() + value)`, but is faster.



/// hs._asm.progress:tint([tint]) -> progressObject | current value
/// Method
/// Get or set the indicator's size/
///
/// Parameters:
///  * tint - an optional integer matching one of the values in [hs._asm.progress.controlTint](#controlTint), which indicates the tint of the progress indicator.
///
/// Returns:
///  * if a value is provided, returns the progress indicator object ; otherwise returns the current value.
///
/// Notes:
///  * The default setting for this is 0, which corresponds to `hs._asm.progress.controlTint.default`.
///  * In my testing, this setting does not seem to have much, if any, effect on the visual aspect of the indicator and is provided in this module in case this changes in a future OS X update (there are some indications that it may have had an effect in previous versions).



/// hs._asm.progress:indicatorSize([size]) -> progressObject | current value
/// Method
/// Get or set the indicator's size/
///
/// Parameters:
///  * size - an optional integer matching one of the values in [hs._asm.progress.controlSize](#controlSize), which indicates the desired size of the indicator.
///
/// Returns:
///  * if a value is provided, returns the progress indicator object ; otherwise returns the current value.
///
/// Notes:
///  * The default setting for this is 0, which corresponds to `hs._asm.progress.controlSize.regular`.
///  * For circular indicators, the sizes seem to be 32x32, 16x16, and 10x10 in 10.11.
///  * For bar indicators, the height seems to be 20 and 12; the mini size seems to be ignored, at least in 10.11.



/// hs._asm.progress:setTopLeft(point) -> progressObject
/// Method
/// Sets the top left point of the progress objects background.
///
/// Parameters:
///  * point - a table containing a keys for x and y, specifying the top left point to move the indicator and its background to.
///
/// Returns:
///  * the progress indicator object



/// hs._asm.progress:setSize(size) -> progressObject
/// Method
/// Sets the size of the indicator's background.
///
/// Parameters:
///  * size - a table containing a keys for h and w, specifying the size of the indicators background.
///
/// Returns:
///  * the progress indicator object



/// hs._asm.progress:frame([rect]) -> progressObject
/// Method
/// Get or set the frame of the the progress indicator and its background.
///
/// Parameters:
///  * rect - an optional table containing the rectangular coordinates of the progress indicator and its background.
///
/// Returns:
///  * if a value is provided, returns the progress indicator object ; otherwise returns the current value.



/// hs._asm.progress:setFillColor(color) -> progressObject
/// Method
/// Sets the fill color for a progress indicator.
///
/// Parameters:
///  * color - a table specifying a color as defined in `hs.drawing.color` indicating the color to use for the progress indicator.
///
/// Returns:
///  * the progress indicator object
///
/// Notes:
///  * This method is not based upon the methods inherent in the NSProgressIndicator Objective-C class, but rather on code found at http://stackoverflow.com/a/32396595 utilizing a CIFilter object to adjust the view's output.
///  * For circular and determinate bar progress indicators, this method works as expected.
///  * For indeterminate bar progress indicators, this method will set the entire bar to the color specified and no animation effect is apparent.  Hopefully this is a temporary limitation.



/// hs._asm.progress:backgroundColor([color]) -> progressObject
/// Method
/// Get or set the color of the progress indicator's background.
///
/// Parameters:
///  * color - an optional table specifying a color as defined in `hs.drawing.color` for the progress indicator's background.
///
/// Returns:
///  * if a value is provided, returns the progress indicator object ; otherwise returns the current value.



/// hs._asm.progress:delete() -> none
/// Method
/// Close and remove a progress indicator.
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
///
/// Notes:
///  * This method is called automatically during garbage collection (most notably, when Hammerspoon is exited or the Hammerspoon configuration is reloaded).

#pragma mark - Module Constants

/// hs._asm.progress.controlSize[]
/// Constant
/// A table containing key-value pairs defining recognized sizes which can be used with the [hs._asm.progress:indicatorSize](#indicatorSize) method.
///
/// Contents:
///  * regular - display the indicator at its regular size
///  * small   - display a smaller version of the indicator
///  * mini    - for circular indicators, display an even smaller version; for bar indicators, this setting has no effect.



/// hs._asm.progress.controlTint[]
/// Constant
/// A table containing key-value pairs defining recognized tints which can be used with the [hs._asm.progress:tint](#tint) method.
///
/// Contents:
///  * default
///  * blue
///  * graphite
///  * clear
///
/// Notes:
///  * In my testing, setting `hs._asm.progress:tint` does not seem to have much, if any, effect on the visual aspect of an indicator and this table is provided in this module in case this changes in a future OS X update (there are some indications that it may have had an effect in previous versions).

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
