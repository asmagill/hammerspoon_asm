hs._asm.notificationcenter
==========================

Listen to notifications sent by the operating system, other applications, and within Hammerspoon itself.

This module allows creating observers for the various notification centers common in the Macintosh OS:

 * The Distributed Notification Center is used to send messages between different tasks (applications) or to post notifications that may be of interest to other applications.
 * The Share Workspace Notification Center is used by the operating system to send messages about system events, such as changes in the currently active applications, screens, sleep, etc.
 * The Hammerspoon Application Notification Center provides a means for objects and threads within Hammerspoon itself to pass messages and information back and forth.  Currently this is read-only, so it's use is somewhat limited, but this may change in the future.

Many of the Hammerspoon module watchers use more narrowly targeted versions of the same code used in this module.  Usually they have been designed for their specific uses and include any additional support which may be needed to interpret or act on the notifications.  This module provides a more basic interface for accessing messages but can be useful for messages which are unique to your specific Application set or are new to the Mac OS, or just not yet understood or desired by enough users to merit formal inclusion in Hammerspoon.

This module is compatible with both Hammerspoon itself and the threaded lua instances provided in by `hs._asm.luathread` module.  No changes to your own lua code is required for use of this module in either environment.

This module is based partially on code from the previous incarnation of Mjolnir by [Steven Degutis](https://github.com/sdegutis/).

### Installation

A compiled version of this module can (usually) be found in this folder named `notificationcenter-vX.Y.tar.gz` .  You can download the release and install it by expanding it in your `~/.hammerspoon/` directory (or any other directory in your `package.path` and `package.cpath` search paths):

~~~bash
cd ~/.hammerspoon
tar -xzf ~/Downloads/notificationcenter-vX.Y.tar.gz # or wherever your downloads are saved
~~~

If this doesn't work for you, or you want to build the latest and greatest, follow the directions below:

This does require that you have XCode or the XCode Command Line Tools installed.  See the App Store application or https://developer.apple.com to install these if necessary.

~~~bash
$ git clone https://github.com/asmagill/hammerspoon_asm
$ cd hammerspoon_asm/notificationcenter
$ [HS_APPLICATION=/Applications] [PREFIX=~/.hammerspoon] make install
~~~

If Hammerspoon.app is in your /Applications folder, you may leave `HS_APPLICATION=/Applications` out and if you are fine with the module being installed in your Hammerspoon configuration directory, you may leave `PREFIX=~/.hammerspoon` out as well.  For most people, it will probably be sufficient to just type `make install`.

In either case, if you are upgrading over a previous installation of this module, you must completely quit and restart Hammerspoon before the new version will be fully recognized.

### Usage
~~~lua
notificationcenter = require("hs._asm.notificationcenter")
~~~

### Module Constructors

<a name="distributedObserver"></a>
~~~lua
notificationcenter.distributedObserver(fn, [name]) -> notificationcenter
~~~
Registers a notification observer for distributed (Intra-Application) notifications.

Parameters:
 * fn - the callback function to associate with this listener.  The function will receive 3 parameters:
   * name - a string giving the name of the notification received
   * object - the object that posted this notification
   * userinfo - an optional table containing information attached to the notification reveived
 * name - an optional parameter specifying the name of the message you wish to listen for.  If nil or left out, all received notifications will be observed.

Returns:
 * a notificationcenter object

- - -

<a name="internalObserver"></a>
~~~lua
notificationcenter.internalObserver(fn, name) -> notificationcenter
~~~
Registers a notification observer for notifications sent within Hammerspoon itself.

Parameters:
 * fn - the callback function to associate with this listener.  The function will receive 3 parameters:
   * name - a string giving the name of the notification received
   * object - the object that posted this notification
   * userinfo - an optional table containing information attached to the notification reveived
 * name - a required parameter specifying the name of the message you wish to listen for.

Returns:
 * a notificationcenter object

Notes:
 * Listening for all inter-application messages will cause Hammerspoon to bog down completely (not to mention generate its own, thus adding to the mayhem), so the name of the message to listen for is required for this version of the contructor.
 * Currently this specific constructor is of limited use outside of development and testing, since there is no current way to programmatically send specific messages outside of the internal messaging that all Objective-C applications perform or specify specific objects within Hammerspoon to observe.  Consideration is being given to methods which will allow posting ad-hoc messages and may make this more useful outside of its currently limited scope.

- - -

<a name="workspaceObserver"></a>
~~~lua
notificationcenter.workspaceObserver(fn, [name]) -> notificationcenter
~~~
Registers a notification observer for notifications sent to the shared workspace.

Parameters:
 * fn - the callback function to associate with this listener.  The function will receive 3 parameters:
   * name - a string giving the name of the notification received
   * object - the object that posted this notification
   * userinfo - an optional table containing information attached to the notification reveived
 * name - an optional parameter specifying the name of the message you wish to listen for.  If nil or left out, all received notifications will be observed.

Returns:
 * a notificationcenter object

### Module Methods

<a name="start"></a>
~~~lua
notificationcenter:start()
~~~
Starts listening for notifications.

Parameters:
 * None

Returns:
 * the notificationcenter object

- - -

<a name="stop"></a>
~~~lua
notificationcenter:stop()
~~~
Stops listening for notifications.

Parameters:
 * None

Returns:
 * the notificationcenter object


### LICENSE

> The MIT License (MIT)
>
> Copyright (c) 2016 Aaron Magill
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
