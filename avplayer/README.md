hs._asm.avplayer
================

Provides an AudioVisual player For Hammerspoon.

Playback of remote or streaming content has not been thoroughly tested; it's not something I do very often.  However, it has been tested against http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8, which is a sample URL provided in the Apple documentation at https://developer.apple.com/library/prerelease/content/documentation/AudioVideo/Conceptual/AVFoundationPG/Articles/02_Playback.html#//apple_ref/doc/uid/TP40010188-CH3-SW4


A precompiled version of this module can be found in this directory with a name along the lines of `avplayer-v0.x.tar.gz`. This can be installed by downloading the file and then expanding it as follows:

~~~sh
$ cd ~/.hammerspoon # or wherever your Hammerspoon init.lua file is located
$ tar -xzf ~/Downloads/avplayer-v0.x.tar.gz # or wherever your downloads are located
~~~

If you wish to build this module yourself, and have XCode installed on your Mac, the best way (you are welcome to clone the entire repository if you like, but no promises on the current state of anything else) is to download `init.lua`, `internal.m`, and `Makefile` (at present, nothing else is required) into a directory of your choice and then do the following:

~~~sh
$ cd wherever-you-downloaded-the-files
$ [HS_APPLICATION=/Applications] [PREFIX=~/.hammerspoon] make docs install
~~~

If your Hammerspoon application is located in `/Applications`, you can leave out the `HS_APPLICATION` environment variable, and if your Hammerspoon files are located in their default location, you can leave out the `PREFIX` environment variable.  For most people it will be sufficient to just type `make docs install`.

As always, whichever method you chose, if you are updating from an earlier version it is recommended to fully quit and restart Hammerspoon after installing this module to ensure that the latest version of the module is loaded into memory.

### Usage
~~~lua
avplayer = require("hs._asm.avplayer")
~~~

### Contents


##### Module Constructors
* <a href="#new">avplayer.new([frame]) -> avplayerObject</a>

##### Module Methods
* <a href="#actionMenu">avplayer:actionMenu(menutable | nil) -> avplayerObject</a>
* <a href="#allowExternalPlayback">avplayer:allowExternalPlayback([state]) -> avplayerObject | current value</a>
* <a href="#alpha">avplayer:alpha([alpha]) -> avplayerObject | currentValue</a>
* <a href="#behavior">avplayer:behavior([behavior]) -> avplayerObject | currentValue</a>
* <a href="#behaviorAsLabels">avplayer:behaviorAsLabels(behaviorTable) -> avplayerObject | currentValue</a>
* <a href="#bringToFront">avplayer:bringToFront([aboveEverything]) -> avplayerObject</a>
* <a href="#ccEnabled">avplayer:ccEnabled([state]) -> avplayerObject | current value</a>
* <a href="#controlsStyle">avplayer:controlsStyle([style]) -> avplayerObject | current value</a>
* <a href="#delete">avplayer:delete() -> nil</a>
* <a href="#duration">avplayer:duration() -> number | nil</a>
* <a href="#externalPlayback">avplayer:externalPlayback() -> Boolean</a>
* <a href="#flashChapterAndTitle">avplayer:flashChapterAndTitle(number, [string]) -> avplayerObject</a>
* <a href="#frame">avplayer:frame([rect]) -> avplayerObject | currentValue</a>
* <a href="#frameSteppingButtons">avplayer:frameSteppingButtons([state]) -> avplayerObject | current value</a>
* <a href="#fullScreenButton">avplayer:fullScreenButton([state]) -> avplayerObject | current value</a>
* <a href="#hide">avplayer:hide() -> avplayerObject</a>
* <a href="#keyboardControl">avplayer:keyboardControl([value]) -> avplayerObject | current value</a>
* <a href="#level">avplayer:level([theLevel]) -> drawingObject | currentValue</a>
* <a href="#load">avplayer:load(path) -> avplayerObject</a>
* <a href="#mute">avplayer:mute([state]) -> avplayerObject | current value</a>
* <a href="#orderAbove">avplayer:orderAbove([avplayer2]) -> avplayerObject</a>
* <a href="#orderBelow">avplayer:orderBelow([avplayer2]) -> avplayerObject</a>
* <a href="#pause">avplayer:pause() -> avplayerObject</a>
* <a href="#pauseWhenHidden">avplayer:pauseWhenHidden([state]) -> avplayerObject | current value</a>
* <a href="#play">avplayer:play([fromBeginning]) -> avplayerObject</a>
* <a href="#playerInformation">avplayer:playerInformation() -> table | nil</a>
* <a href="#rate">avplayer:rate([rate]) -> avplayerObject | current value</a>
* <a href="#seek">avplayer:seek(time, [callback]) -> avplayerObject | nil</a>
* <a href="#sendToBack">avplayer:sendToBack() -> avplayerObject</a>
* <a href="#setCallback">avplayer:setCallback(fn) -> avplayerObject</a>
* <a href="#shadow">avplayer:shadow([value]) -> avplayerObject | current value</a>
* <a href="#sharingServiceButton">avplayer:sharingServiceButton([state]) -> avplayerObject | current value</a>
* <a href="#show">avplayer:show() -> avplayerObject</a>
* <a href="#size">avplayer:size([size]) -> avplayerObject | currentValue</a>
* <a href="#status">avplayer:status() -> status[, error] | nil</a>
* <a href="#time">avplayer:time() -> number | nil</a>
* <a href="#topLeft">avplayer:topLeft([point]) -> avplayerObject | currentValue</a>
* <a href="#trackCompleted">avplayer:trackCompleted([state]) -> avplayerObject | current value</a>
* <a href="#trackProgress">avplayer:trackProgress([number | nil]) -> avplayerObject | current value</a>
* <a href="#trackRate">avplayer:trackRate([state]) -> avplayerObject | current value</a>
* <a href="#trackStatus">avplayer:trackStatus([state]) -> avplayerObject | current value</a>
* <a href="#volume">avplayer:volume([volume]) -> avplayerObject | current value</a>
* <a href="#windowCallback">avplayer:windowCallback(fn) -> avplayerObject</a>
* <a href="#windowStyle">avplayer:windowStyle(mask) -> avplayerObject | currentMask</a>

- - -

### Module Constructors

<a name="new"></a>
~~~lua
avplayer.new([frame]) -> avplayerObject
~~~
Creates a new AVPlayer object which can display audiovisual media for Hammerspoon.

Parameters:
 * `frame` - an optional frame table specifying the position and size of the window for the avplayer object.

Returns:
 * the avplayerObject

### Module Methods

<a name="actionMenu"></a>
~~~lua
avplayer:actionMenu(menutable | nil) -> avplayerObject
~~~
Set or remove the additional actions menu from the media controls for the avplayer.

Parameters:
 * `menutable` - a table containing a menu definition as described in the documentation for `hs.menubar:setMenu`.  If `nil` is specified, any existing menu is removed.

Parameters:
 * the avplayerObject

Notes:
 * All menu keys supported by `hs.menubar:setMenu`, except for the `fn` key, are supported by this method.
 * When a menu item is selected, the callback function (see [hs._asm.avplayer:setCallback](#setCallback)) is invoked with the following 4 arguments:
   * the avplayerObject
   * "actionMenu"
   * the `title` field of the menu item selected
   * a table containing the following keys set to true or false indicating which key modifiers were down when the menu item was selected: "cmd", "shift", "alt", "ctrl", and "fn".

- - -

<a name="allowExternalPlayback"></a>
~~~lua
avplayer:allowExternalPlayback([state]) -> avplayerObject | current value
~~~
Get or set whether or not external playback via AirPlay is allowed for this item.

Parameters:
 * `state` - an optional boolean, default false, specifying whether external playback via AirPlay is allowed for this item.

Returns:
 * if an argument is provided, the avplayerObject; otherwise the current value.

Notes:
 * External playback via AirPlay is only available in macOS 10.11 and newer.

- - -

<a name="alpha"></a>
~~~lua
avplayer:alpha([alpha]) -> avplayerObject | currentValue
~~~
Get or set the alpha level of the window containing the hs._asm.avplayer object.

Parameters:
 * `alpha` - an optional number between 0.0 and 1.0 specifying the new alpha level for the avplayer.

Returns:
 * If a parameter is provided, returns the avplayer object; otherwise returns the current value.

- - -

<a name="behavior"></a>
~~~lua
avplayer:behavior([behavior]) -> avplayerObject | currentValue
~~~
Get or set the window behavior settings for the avplayer object using labels defined in `hs.canvas.windowBehaviors`.

Parameters:
 * `behavior` - if present, the behavior should be a combination of values found in `hs.canvas.windowBehaviors` describing the window behavior.  The behavior should be specified as one of the following:
   * integer - a number representing the behavior which can be created by combining values found in `hs.canvas.windowBehaviors` with the logical or operator.
   * string  - a single key from `hs.canvas.windowBehaviors` which will be toggled in the current window behavior.
   * table   - a list of keys from `hs.canvas.windowBehaviors` which will be combined to make the final behavior by combining their values with the logical or operator.

Returns:
 * if an argument is provided, then the avplayerObject is returned; otherwise the current behavior value is returned.

- - -

<a name="behaviorAsLabels"></a>
~~~lua
avplayer:behaviorAsLabels(behaviorTable) -> avplayerObject | currentValue
~~~
Get or set the window behavior settings for the avplayer object using labels defined in `hs.canvas.windowBehaviors`.

Parameters:
 * behaviorTable - an optional table of strings and/or numbers specifying the desired window behavior for the avplayer object.

Returns:
 * If an argument is provided, the avplayer object; otherwise the current value.

Notes:
 * Window behaviors determine how the avplayer object is handled by Spaces and Exposé. See `hs.canvas.windowBehaviors` for more information.

- - -

<a name="bringToFront"></a>
~~~lua
avplayer:bringToFront([aboveEverything]) -> avplayerObject
~~~
Places the drawing object on top of normal windows

Parameters:
 * `aboveEverything` - An optional boolean value that controls how far to the front the avplayer should be placed. True to place the avplayer on top of all windows (including the dock and menubar and fullscreen windows), false to place the avplayer above normal windows, but below the dock, menubar and fullscreen windows. Defaults to false.

Returns:
 * The avplayer object

- - -

<a name="ccEnabled"></a>
~~~lua
avplayer:ccEnabled([state]) -> avplayerObject | current value
~~~
Get or set whether or not the player can use close captioning, if it is included in the audiovisual content.

Parameters:
 * `state` - an optional boolean, default false, specifying whether or not the player should display closed captioning information, if it is available.

Returns:
 * if an argument is provided, the avplayerObject; otherwise the current value.

- - -

<a name="controlsStyle"></a>
~~~lua
avplayer:controlsStyle([style]) -> avplayerObject | current value
~~~
Get or set the style of controls displayed in the avplayerObject for controlling media playback.

Parameters:
 * `style` - an optional string, default "default", specifying the stye of the controls displayed for controlling media playback.  The string may be one of the following:
   * `none`     - no controls are provided -- playback must be managed programmatically through Hammerspoon Lua code.
   * `inline`   - media controls are displayed in an autohiding status bar at the bottom of the media display.
   * `floating` - media controls are displayed in an autohiding panel which floats over the media display.
   * `minimal`  - media controls are displayed as a round circle in the center of the media display.
   * `none`     - no media controls are displayed in the media display.
   * `default`  - use the OS X default control style; under OS X 10.11, this is the "inline".

Returns:
 * if an argument is provided, the avplayerObject; otherwise the current value.

- - -

<a name="delete"></a>
~~~lua
avplayer:delete() -> nil
~~~
Destroys the avplayer object.

Parameters:
 * None

Returns:
 * nil

Notes:
 * This method is automatically called during garbage collection, notably during a Hammerspoon termination or reload

- - -

<a name="duration"></a>
~~~lua
avplayer:duration() -> number | nil
~~~
Returns the duration, in seconds, of the audiovisual media content currently loaded.

Parameters:
 * None

Returns:
 * the duration, in seconds, of the audiovisual media content currently loaded, if it can be determined, or `nan` (not-a-number) if it cannot.  If no item has been loaded, this method will return nil.

Notes:
 * the duration of an item which is still loading cannot be determined; you may want to use [hs._asm.avplayer:trackStatus](#trackStatus) and wait until it receives a "readyToPlay" state before querying this method.

 * a live stream may not provide duration information and also return `nan` for this method.

 * Lua defines `nan` as a number which is not equal to itself.  To test if the value of this method is `nan` requires code like the following:
 ~~~lua
 duration = avplayer:duration()
 if type(duration) == "number" and duration ~= duration then
     -- the duration is equal to `nan`
 end
~~~

- - -

<a name="externalPlayback"></a>
~~~lua
avplayer:externalPlayback() -> Boolean
~~~
Returns whether or not external playback via AirPlay is currently active for the avplayer object.

Parameters:
 * None

Returns:
 * true, if AirPlay is currently being used to play the audiovisual content, or false if it is not.

Notes:
 * External playback via AirPlay is only available in macOS 10.11 and newer.

- - -

<a name="flashChapterAndTitle"></a>
~~~lua
avplayer:flashChapterAndTitle(number, [string]) -> avplayerObject
~~~
Flashes the number and optional string over the media playback display momentarily.

Parameters:
 * `number` - an integer specifying the chapter number to display.
 * `string` - an optional string specifying the chapter name to display.

Returns:
 * the avplayerObject

Notes:
 * If only a number is provided, the text "Chapter #" is displayed.  If a string is also provided, "#. string" is displayed.

- - -

<a name="frame"></a>
~~~lua
avplayer:frame([rect]) -> avplayerObject | currentValue
~~~
Get or set the frame of the avplayer window.

Parameters:
 * rect - An optional rect-table containing the co-ordinates and size the avplayer window should be moved and set to

Returns:
 * If an argument is provided, the avplayer object; otherwise the current value.

Notes:
 * a rect-table is a table with key-value pairs specifying the new top-left coordinate on the screen of the avplayer window (keys `x`  and `y`) and the new size (keys `h` and `w`).  The table may be crafted by any method which includes these keys, including the use of an `hs.geometry` object.

- - -

<a name="frameSteppingButtons"></a>
~~~lua
avplayer:frameSteppingButtons([state]) -> avplayerObject | current value
~~~
Get or set whether frame stepping or scrubbing controls are included in the media controls.

Parameters:
 * `state` - an optional boolean, default false, specifying whether frame stepping (true) or scrubbing (false) controls are included in the media controls.

Returns:
 * if an argument is provided, the avplayerObject; otherwise the current value.

- - -

<a name="fullScreenButton"></a>
~~~lua
avplayer:fullScreenButton([state]) -> avplayerObject | current value
~~~
Get or set whether or not the full screen toggle button should be included in the media controls.

Parameters:
 * `state` - an optional boolean, default false, specifying whether or not the full screen toggle button should be included in the media controls.

Returns:
 * if an argument is provided, the avplayerObject; otherwise the current value.

- - -

<a name="hide"></a>
~~~lua
avplayer:hide() -> avplayerObject
~~~
Hides the avplayer object

Parameters:
 * None

Returns:
 * The avplayer object

- - -

<a name="keyboardControl"></a>
~~~lua
avplayer:keyboardControl([value]) -> avplayerObject | current value
~~~
Get or set whether or not the avplayer can accept keyboard input for playback control. Defaults to false.

Parameters:
 * `value` - an optional boolean value which sets whether or not the avplayer will accept keyboard input.

Returns:
 * If a value is provided, then this method returns the avplayer object; otherwise the current value

- - -

<a name="level"></a>
~~~lua
avplayer:level([theLevel]) -> drawingObject | currentValue
~~~
Get or set the window level

Parameters:
 * `theLevel` - an optional parameter specifying the desired level as an integer or string. If it is a string, it must match one of the keys in `hs.canvas.windowLevels`.

Returns:
 * if a parameter is specified, returns the avplayer object, otherwise the current value

Notes:
 * see the notes for `hs.drawing.windowLevels`

- - -

<a name="load"></a>
~~~lua
avplayer:load(path) -> avplayerObject
~~~
Load the specified resource for playback.

Parameters:
 * `path` - a string specifying the file path or URL to the audiovisual resource.

Returns:
 * the avplayerObject

Notes:
 * Content will not start autoplaying when loaded - you must use the controls provided in the audiovisual player or one of [hs._asm.avplayer:play](#play) or [hs._asm.avplayer:rate](#rate) to begin playback.

 * If the path or URL are malformed, unreachable, or otherwise unavailable, [hs._asm.avplayer:status](#status) will return "failed".
 * Because a remote URL may not respond immediately, you can also setup a callback with [hs._asm.avplayer:trackStatus](#trackStatus) to be notified when the item has loaded or if it has failed.

- - -

<a name="mute"></a>
~~~lua
avplayer:mute([state]) -> avplayerObject | current value
~~~
Get or set whether or not audio output is muted for the audovisual media item.

Parameters:
 * `state` - an optional boolean, default false, specifying whether or not audio output has been muted for the avplayer object.

Returns:
 * if an argument is provided, the avplayerObject; otherwise the current value.

- - -

<a name="orderAbove"></a>
~~~lua
avplayer:orderAbove([avplayer2]) -> avplayerObject
~~~
Moves avplayer object above avplayer2, or all avplayer objects in the same presentation level, if avplayer2 is not given.

Parameters:
 * `avplayer2` -An optional avplayer object to place the avplayer object above.

Returns:
 * The avplayer object

Notes:
 * If the avplayer object and avplayer2 are not at the same presentation level, this method will will move the avplayer object as close to the desired relationship without changing the avplayer object's presentation level. See [hs._asm.avplayer.level](#level).

- - -

<a name="orderBelow"></a>
~~~lua
avplayer:orderBelow([avplayer2]) -> avplayerObject
~~~
Moves avplayer object below avplayer2, or all avplayer objects in the same presentation level, if avplayer2 is not given.

Parameters:
 * `avplayer2` -An optional avplayer object to place the avplayer object below.

Returns:
 * The avplayer object

Notes:
 * If the avplayer object and avplayer2 are not at the same presentation level, this method will will move the avplayer object as close to the desired relationship without changing the avplayer object's presentation level. See [hs._asm.avplayer.level](#level).

- - -

<a name="pause"></a>
~~~lua
avplayer:pause() -> avplayerObject
~~~
Pause the audiovisual media currently loaded in the avplayer object.

Parameters:
 * None

Returns:
 * the avplayerObject

Notes:
 * this is equivalent to setting the rate to 0.0 (see [hs._asm.avplayer:rate(0.0)](#rate)`)

- - -

<a name="pauseWhenHidden"></a>
~~~lua
avplayer:pauseWhenHidden([state]) -> avplayerObject | current value
~~~
Get or set whether or not playback of media should be paused when the avplayer object is hidden.

Parameters:
 * `state` - an optional boolean, default true, specifying whether or not media playback should be paused when the avplayer object is hidden.

Returns:
 * if an argument is provided, the avplayerObject; otherwise the current value.

- - -

<a name="play"></a>
~~~lua
avplayer:play([fromBeginning]) -> avplayerObject
~~~
Play the audiovisual media currently loaded in the avplayer object.

Parameters:
 * `fromBeginning` - an optional boolean, default false, specifying whether or not the media playback should start from the beginning or from the current location.

Returns:
 * the avplayerObject

Notes:
 * this is equivalent to setting the rate to 1.0 (see [hs._asm.avplayer:rate(1.0)](#rate)`)

- - -

<a name="playerInformation"></a>
~~~lua
avplayer:playerInformation() -> table | nil
~~~
Returns a table containing information about the media playback characteristics of the audiovisual media currently loaded in the avplayerObject.

Parameters:
 * None

Returns:
 * a table containing the following media characteristics, or `nil` if no media content is currently loaded:
   * "playbackLikelyToKeepUp" - Indicates whether the item will likely play through without stalling.  Note that this is only a prediction.
   * "playbackBufferEmpty"    - Indicates whether playback has consumed all buffered media and that playback may stall or end.
   * "playbackBufferFull"     - Indicates whether the internal media buffer is full and that further I/O is suspended.
   * "canPlayReverse"         - A Boolean value indicating whether the item can be played with a rate of -1.0.
   * "canPlayFastForward"     - A Boolean value indicating whether the item can be played at rates greater than 1.0.
   * "canPlayFastReverse"     - A Boolean value indicating whether the item can be played at rates less than –1.0.
   * "canPlaySlowForward"     - A Boolean value indicating whether the item can be played at a rate between 0.0 and 1.0.
   * "canPlaySlowReverse"     - A Boolean value indicating whether the item can be played at a rate between -1.0 and 0.0.

- - -

<a name="rate"></a>
~~~lua
avplayer:rate([rate]) -> avplayerObject | current value
~~~
Get or set the rate of playback for the audiovisual content of the avplayer object.

Parameters:
 * `rate` - an optional number specifying the rate you wish for the audiovisual content to be played.

Returns:
 * if an argument is provided, the avplayerObject; otherwise the current value.

Notes:
 * This method affects the playback rate of both video and audio -- if you wish to mute audio during a "fast forward" or "rewind", see [hs._asm.avplayer:mute](#mute).
 * A value of 0.0 is equivalent to [hs._asm.avplayer:pause](#pause).
 * A value of 1.0 is equivalent to [hs._asm.avplayer:play](#play).

 * Other rates may not be available for all media and will be ignored if specified and the media does not support playback at the specified rate:
   * Rates between 0.0 and 1.0 are allowed if [hs._asm.avplayer:playerInformation](#playerInformation) returns true for the `canPlaySlowForward` field
   * Rates greater than 1.0 are allowed if [hs._asm.avplayer:playerInformation](#playerInformation) returns true for the `canPlayFastForward` field
   * The item can be played in reverse (a rate of -1.0) if [hs._asm.avplayer:playerInformation](#playerInformation) returns true for the `canPlayReverse` field
   * Rates between 0.0 and -1.0 are allowed if [hs._asm.avplayer:playerInformation](#playerInformation) returns true for the `canPlaySlowReverse` field
   * Rates less than -1.0 are allowed if [hs._asm.avplayer:playerInformation](#playerInformation) returns true for the `canPlayFastReverse` field

- - -

<a name="seek"></a>
~~~lua
avplayer:seek(time, [callback]) -> avplayerObject | nil
~~~
Jumps to the specified location in the audiovisual content currently loaded into the player.

Parameters:
 * `time`     - the location, in seconds, within the audiovisual content to seek to.
 * `callback` - an optional boolean, default false, specifying whether or not a callback should be invoked when the seek operation has completed.

Returns:
 * the avplayerObject, or nil if no media content is currently loaded

Notes:
 * If you specify `callback` as true, the callback function (see [hs._asm.avplayer:setCallback](#setCallback)) will be invoked with the following 3 or 4 arguments:
   * the avplayerObject
   * "seek"
   * the current time, in seconds, specifying the current playback position in the media content
   * `true` if the seek operation was allowed to complete, or `false` if it was interrupted (for example by another seek request).

- - -

<a name="sendToBack"></a>
~~~lua
avplayer:sendToBack() -> avplayerObject
~~~
Places the avplayer object behind normal windows, between the desktop wallpaper and desktop icons

Parameters:
 * None

Returns:
 * The drawing object

- - -

<a name="setCallback"></a>
~~~lua
avplayer:setCallback(fn) -> avplayerObject
~~~
Set the callback function for the avplayerObject.

Parameters:
 * `fn` - a function, or explicit `nil`, specifying the callback function which is used by this avplayerObject.  If `nil` is specified, the currently active callback function is removed.

Returns:
 * the avplayerObject

Notes:
 * The callback function should expect 2 or more arguments.  The first two arguments will always be:
   * `avplayObject` - the avplayerObject userdata
   * `message`      - a string specifying the reason for the callback.
 * Additional arguments depend upon the message.  See the following methods for details concerning the arguments for each message:
   * `actionMenu` - [hs._asm.avplayer:actionMenu](#actionMenu)
   * `finished`   - [hs._asm.avplayer:trackCompleted](#trackCompleted)
   * `pause`      - [hs._asm.avplayer:trackRate](#trackRate)
   * `play`       - [hs._asm.avplayer:trackRate](#trackRate)
   * `progress`   - [hs._asm.avplayer:trackProgress](#trackProgress)
   * `seek`       - [hs._asm.avplayer:seek](#seek)
   * `status`     - [hs._asm.avplayer:trackStatus](#trackStatus)

- - -

<a name="shadow"></a>
~~~lua
avplayer:shadow([value]) -> avplayerObject | current value
~~~
Get or set whether or not the avplayer window has shadows. Default to false.

Parameters:
 * `value` - an optional boolean value indicating whether or not the avplayer should have shadows.

Returns:
 * If a value is provided, then this method returns the avplayer object; otherwise the current value

- - -

<a name="sharingServiceButton"></a>
~~~lua
avplayer:sharingServiceButton([state]) -> avplayerObject | current value
~~~
Get or set whether or not the sharing services button is included in the media controls.

Parameters:
 * `state` - an optional boolean, default false, specifying whether or not the sharing services button is included in the media controls.

Returns:
 * if an argument is provided, the avplayerObject; otherwise the current value.

- - -

<a name="show"></a>
~~~lua
avplayer:show() -> avplayerObject
~~~
Displays the avplayer object

Parameters:
 * None

Returns:
 * The avplayer object

- - -

<a name="size"></a>
~~~lua
avplayer:size([size]) -> avplayerObject | currentValue
~~~
Get or set the size of a avplayer window

Parameters:
 * `size` - An optional size-table specifying the width and height the avplayer window should be resized to

Returns:
 * If an argument is provided, the avplayer object; otherwise the current value.

Notes:
 * a size-table is a table with key-value pairs specifying the size (keys `h` and `w`) the avplayer should be resized to. The table may be crafted by any method which includes these keys, including the use of an `hs.geometry` object.

- - -

<a name="status"></a>
~~~lua
avplayer:status() -> status[, error] | nil
~~~
Returns the current status of the media content loaded for playback.

Parameters:
 * None

Returns:
 * One of the following status strings, or `nil` if no media content is currently loaded:
   * "unknown"     - The content's status is unknown; often this is returned when remote content is still loading or being evaluated for playback.
   * "readyToPlay" - The content has been loaded or sufficiently buffered so that playback may begin
   * "failed"      - There was an error loading the content; a second return value will contain a string which may contain more information about the error.

- - -

<a name="time"></a>
~~~lua
avplayer:time() -> number | nil
~~~
Returns the current position in seconds within the audiovisual media content.

Parameters:
 * None

Returns:
 * the current position, in seconds, within the audiovisual media content, or `nil` if no media content is currently loaded.

- - -

<a name="topLeft"></a>
~~~lua
avplayer:topLeft([point]) -> avplayerObject | currentValue
~~~
Get or set the top-left coordinate of the avplayer window

Parameters:
 * `point` - An optional point-table specifying the new coordinate the top-left of the avplayer window should be moved to

Returns:
 * If an argument is provided, the avplayer object; otherwise the current value.

Notes:
 * a point-table is a table with key-value pairs specifying the new top-left coordinate on the screen of the avplayer (keys `x`  and `y`). The table may be crafted by any method which includes these keys, including the use of an `hs.geometry` object.

- - -

<a name="trackCompleted"></a>
~~~lua
avplayer:trackCompleted([state]) -> avplayerObject | current value
~~~
Enable or disable a callback whenever playback of the current media content is completed (reaches the end).

Parameters:
 * `state` - an optional boolean, default false, specifying whether or not completing the playback of media should invoke a callback.

Returns:
 * if an argument is provided, the avplayerObject; otherwise the current value.

Notes:
 * the callback function (see [hs._asm.avplayer:setCallback](#setCallback)) will be invoked with the following 2 arguments:
   * the avplayerObject
   * "finished"

- - -

<a name="trackProgress"></a>
~~~lua
avplayer:trackProgress([number | nil]) -> avplayerObject | current value
~~~
Enable or disable a periodic callback at the interval specified.

Parameters:
 * `number` - an optional number specifying how often, in seconds, the callback function should be invoked to report progress.  If an explicit nil is specified, then the progress callback is disabled. Defaults to nil.

Returns:
 * if an argument is provided, the avplayerObject; otherwise the current value.  A return value of `nil` indicates that no progress callback is in effect.

Notes:
 * the callback function (see [hs._asm.avplayer:setCallback](#setCallback)) will be invoked with the following 3 arguments:
   * the avplayerObject
   * "progress"
   * the time in seconds specifying the current location in the media playback.

 * From Apple Documentation: The block is invoked periodically at the interval specified, interpreted according to the timeline of the current item. The block is also invoked whenever time jumps and whenever playback starts or stops. If the interval corresponds to a very short interval in real time, the player may invoke the block less frequently than requested. Even so, the player will invoke the block sufficiently often for the client to update indications of the current time appropriately in its end-user interface.

- - -

<a name="trackRate"></a>
~~~lua
avplayer:trackRate([state]) -> avplayerObject | current value
~~~
Enable or disable a callback whenever the rate of playback changes.

Parameters:
 * `state` - an optional boolean, default false, specifying whether or not playback rate changes should invoke a callback.

Returns:
 * if an argument is provided, the avplayerObject; otherwise the current value.

Notes:
 * the callback function (see [hs._asm.avplayer:setCallback](#setCallback)) will be invoked with the following 3 arguments:
   * the avplayerObject
   * "pause", if the rate changes to 0.0, or "play" if the rate changes to any other value
   * the rate that the playback was changed to.

 * Not all media content can have its playback rate changed; attempts to do so will invoke the callback twice -- once signifying that the change was made, and a second time indicating that the rate of play was reset back to the limits of the media content.  See [hs._asm:rate](#rate) for more information.

- - -

<a name="trackStatus"></a>
~~~lua
avplayer:trackStatus([state]) -> avplayerObject | current value
~~~
Enable or disable a callback whenever the status of loading a media item changes.

Parameters:
 * `state` - an optional boolean, default false, specifying whether or not changes to the status of audiovisual media's loading status should generate a callback..

Returns:
 * if an argument is provided, the avplayerObject; otherwise the current value.

Notes:
 * the callback function (see [hs._asm.avplayer:setCallback](#setCallback)) will be invoked with the following 3 or 4 arguments:
   * the avplayerObject
   * "status"
   * a string matching one of the states described in [hs._asm.avplayer:status](#status)
   * if the state reported is failed, an error message describing the error that occurred.

- - -

<a name="volume"></a>
~~~lua
avplayer:volume([volume]) -> avplayerObject | current value
~~~
Get or set the avplayer object's volume on a linear scale from 0.0 (silent) to 1.0 (full volume, relative to the current OS volume).

Parameters:
 * `volume` - an optional number, default as specified by the media or 1.0 if no designation is specified by the media, specifying the player's volume relative to the system volume level.

Returns:
 * if an argument is provided, the avplayerObject; otherwise the current value.

- - -

<a name="windowCallback"></a>
~~~lua
avplayer:windowCallback(fn) -> avplayerObject
~~~
Set or clear a callback for updates to the avplayer window

Parameters:
 * `fn` - the function to be called when the avplayer window is moved or closed. Specify an explicit nil to clear the current callback.  The function should expect 2 or 3 arguments and return none.  The arguments will be one of the following:

   * "closing", avplayer - specifies that the avplayer window is being closed, either by the user or with the [hs._asm.avplayer:delete](#delete) method.
     * `action`   - in this case "closing", specifying that the avplayer window is being closed
     * `avplayer` - the avplayer that is being closed

   * "focusChange", avplayer, state - indicates that the avplayer window has either become or stopped being the focused window
     * `action`   - in this case "focusChange", specifying that the avplayer window is being closed
     * `avplayer` - the avplayer that is being closed
     * `state`    - a boolean, true if the avplayer has become the focused window, or false if it has lost focus

   * "frameChange", avplayer, frame - indicates that the avplayer window has been moved or resized
     * `action`   - in this case "focusChange", specifying that the avplayer window is being closed
     * `avplayer` - the avplayer that is being closed
     * `frame`    - a rect-table containing the new co-ordinates and size of the avplayer window

Returns:
 * The avplayer object

- - -

<a name="windowStyle"></a>
~~~lua
avplayer:windowStyle(mask) -> avplayerObject | currentMask
~~~
Get or set the window display style

Parameters:
 * mask - if present, this mask should be a combination of values found in `hs.webview.windowMasks` describing the window style.  The mask should be provided as one of the following:
   * integer - a number representing the style which can be created by combining values found in `hs.webview.windowMasks` with the logical or operator.
   * string  - a single key from `hs.webview.windowMasks` which will be toggled in the current window style.
   * table   - a list of keys from `hs.webview.windowMasks` which will be combined to make the final style by combining their values with the logical or operator.

Returns:
 * if a mask is provided, then the avplayerObject is returned; otherwise the current mask value is returned.

- - -

### License

>     The MIT License (MIT)
>
> Copyright (c) 2017 Aaron Magill
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
>


