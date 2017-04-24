hs._asm.alert
=============

Display warning or critical alert dialogs from within Hammerspoon

This module allows you to create warning or critical alert dialog boxes from within Hammerspoon.  These dialogs are modal (meaning that no other Hammerspoon activity can occur while they are being displayed) and are currently limited to just providing one or more buttons for user interaction. Attempts to remove or mitigate these limitations are being examined.


A precompiled version of this module can be found in this directory with a name along the lines of `alert-v0.x.tar.gz`. This can be installed by downloading the file and then expanding it as follows:

~~~sh
$ cd ~/.hammerspoon # or wherever your Hammerspoon init.lua file is located
$ tar -xzf ~/Downloads/alert-v0.x.tar.gz # or wherever your downloads are located
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
alert = require("hs._asm.alert")
~~~

### Contents


##### Module Constructors
* <a href="#new">alert.new([critical]) -> alertObject</a>

##### Module Methods
* <a href="#autoActivate">alert:autoActivate([state]) -> current value | alertObject</a>
* <a href="#autoHideConsole">alert:autoHideConsole([state]) -> current value | alertObject</a>
* <a href="#buttons">alert:buttons([list]) -> current value | alertObject</a>
* <a href="#helpCallback">alert:helpCallback(fn | nil) -> alertObject</a>
* <a href="#icon">alert:icon([image]) -> current value | alertObject</a>
* <a href="#information">alert:information([text]) -> current value | alertObject</a>
* <a href="#message">alert:message([text]) -> current value | alertObject</a>
* <a href="#modal">alert:modal() -> result</a>
* <a href="#resultCallback">alert:resultCallback(fn | nil) -> alertObject</a>

- - -

### Module Constructors

<a name="new"></a>
~~~lua
alert.new([critical]) -> alertObject
~~~
Creates a new alert object.

Parameters:
 * critical - an optional boolean, default false, specifying that the alert represents a critical notification as opposed to an informational one or a warning.

Returns:
 * the alert object

Notes:
 * A critical alert will show a caution icon with a smaller version of the alert's icon -- see [hs._asm.alert:icon](#icon) -- as a badge in the lower right corner.
 * Apple's current UI guidelines makes no visual distinction between informational or warning alerts -- this module implements the alert as critical or not critical because of this.

### Module Methods

<a name="autoActivate"></a>
~~~lua
alert:autoActivate([state]) -> current value | alertObject
~~~
Get or set whether or not the alert should automatically grab focus when it is displayed with [hs._asm.alert:modal](#modal).

Parameters:
 * state - an optional boolean, default true, indicathing whether the alert dialog should become the focused user interface element when it is displayed.

Returns:
 * if an argument is provided, returns the alert object; otherwise returns the current value

Notes:
 * When set to true, the application which was frontmost right before the alert is displayed will be reactivated when the alert is dismissed.
 * When set to false then the user must click on the dialog before it will respond to any key equivalents which may be in effect for the alert -- see [hs._asm.alert:buttons](#buttons).

- - -

<a name="autoHideConsole"></a>
~~~lua
alert:autoHideConsole([state]) -> current value | alertObject
~~~
Get or set whether or not the Hammerspoon console should be hidden while the alert is visible.

Parameters:
 * state - an optional boolean, default false, indicathing whether the Hammerspoon console, should be hidden when the alert is visible.  If this is set to true and the console is visible, it will be hidden and then re-opened when the alert is dismissed.

Returns:
 * if an argument is provided, returns the alert object; otherwise returns the current value

Notes:
 * Because responding to an alert requires Hammerspoon to become the focused application, the Hammerspoon console may be brought forward if it is visible when you display an alert. When used in conjunction with [hs._asm.alert:autoActivate(true)[#autoActivate], this method may be used to minimize the visual distraction of this.

- - -

<a name="buttons"></a>
~~~lua
alert:buttons([list]) -> current value | alertObject
~~~
Get or set the list of buttons which are displayed by the alert as options for the user to choose from.

Parameters:
 * an optional table containing a list of one or more strings which will be the titles on the buttons provided in the alert.  Defaults to `{ "OK" }`.

Returns:
 * if an argument is provided, returns the alert object; otherwise returns the current value

Notes:
 * The list of buttons will be displayed from right to left in the order in which they appear in this list.
 * The *last* button title specifies the default for the alert and will be selected if the user hits the Return key rather than clicking on another button.
 * If a button (other than the *last* one) is named "Cancel", then the user may press the Escape key to choose it instead of clicking on it.
 * If a button (other than the *last* one) is named "Don't Save", then the user may press Command-D to choose it instead of clicking on it.

* These key equivalents are built in. At preset there is no way to override them or set your own, though adding this is being considered.
* Programmers note: This ordering of the button titles was chosen to more accurately represent their visual order and is opposite from the way buttons are added internally to the NSAlert object.

- - -

<a name="helpCallback"></a>
~~~lua
alert:helpCallback(fn | nil) -> alertObject
~~~
Set or remove a callback function which should be invoked if the user clicks on the help icon of the alert.

Parameters:
 * fn - a function to register as the callback when the user clicks on the help icon of the alert, or an explicit nil to remove any existing callback.

Returns:
 * the alert object

Notes:
 * If no help callback is set, the help icon will not be displayed in the alert dialog.
 * While the alert is being displayed with [hs._asm.alert:modal](#modal), Hammerspoon activity is blocked; however this callback function will be executed because it is within the same thread as the modal alert itself.  Be aware however that any action initiated by this callback function which relies on injecting events into the Hammerspoon application run loop (timers, notification watchers, etc.) will be delayed until the alert is dismissed.

- - -

<a name="icon"></a>
~~~lua
alert:icon([image]) -> current value | alertObject
~~~
Get or set the message icon for the alert.

Parameters:
 * image - an optional `hs.image` object specifying the image to use as the icon at the left of the alert dialog.  Defaults to the Hammerspoon application icon.  You can revert this to the Hammerspoon application icon by specifying an explicit nil as the image argument.

Returns:
 * if an argument is provided, returns the alert object; otherwise returns the current value

Notes:
 * If the alert is a critical one as specified when created with [hs._asm.alert.new](#new), this is the image which appears as the small badge at the lower right of the caution icon.

- - -

<a name="information"></a>
~~~lua
alert:information([text]) -> current value | alertObject
~~~
Get or set the information text field of the alert.  This text is displayed in the main body of the alert.

Parameters:
 * text - an optional string specifying the text to be displayed in the main body of the alert. Defaults to the empty string, "".

Returns:
 * if an argument is provided, returns the alert object; otherwise returns the current value

Notes:
 * The information text is displayed in the main body of the alert and is not in bold.  It can be multiple lines in length, and you can use `\\n` to force an explicit line break within the text to be displayed.

- - -

<a name="message"></a>
~~~lua
alert:message([text]) -> current value | alertObject
~~~
Get or set the message text field of the alert.  This text is displayed at the top of the alert like a title for the alert.

Parameters:
 * text - an optional string specifying the text to be displayed at the top of the alert. Defaults to "Alert".

Returns:
 * if an argument is provided, returns the alert object; otherwise returns the current value

Notes:
 * The message text is displayed at the top of the alert and is in bold.  It can be multiple lines in length, and you can use `\\n` to force an explicit line break within the text to be displayed.

- - -

<a name="modal"></a>
~~~lua
alert:modal() -> result
~~~
Displays the alert as a modal dialog, pausing Hammerspoon activity until the user makes their selection from the buttons provided.

Parameters:
 * None

Returns:
 * the string title of the button the user clicked on to dismiss the alert.

Notes:
 * as described in the [hs._asm.alert:buttons](#buttons) method, some buttons may have keyboard equivalents for clicking on them -- the string returned is identical and we have no way to distinguish *how* they selected a button, just which button they did select.

- - -

<a name="resultCallback"></a>
~~~lua
alert:resultCallback(fn | nil) -> alertObject
~~~
*** Currently does nothing *** : Get or set a callback to be invoked with the result of a non-modal alert when the user dismisses the dialog.
Parameters:
 * fn - a function to register as the callback when the user clicks on a button to dismiss the alert, or an explicit nil to remove any existing callback.

Returns:
 * the alert object

Notes:
 * This method is included for testing during development while a non-modal method of displaying the alerts is researched.  At present, using this method to set a callback has no affect since such a callback is never actually invoked.

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

