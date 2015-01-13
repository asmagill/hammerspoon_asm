_asm.notification
=================

** Still testing -- if you use this, it's with the expectation of catastrophic failure and a great sense of ennui.  **

** This is expected to make it's way into Hammerspoon core at some point, but is included here in this form as it should also work with Mjolnir.  If you use Hammerspoon and utilize this module before it appears in core, expect to have to chnge references from hs._asm.notification to whatever the name ends up being in core. **

A more powerful use of Apple's built-in notifications system for Hammerspoon and Mjolnir.

This module also provides backwards compatibility with `mjolnir._asm.notify`, `hs.notify` and Hydra's `notify` command.

This module is based in part on code from the previous incarnation of Mjolnir by [Steven Degutis](https://github.com/sdegutis/).

### Local Install
~~~bash
$ git clone https://github.com/asmagill/hammerspoon_asm
$ cd hammerspoon_asm/notification
$ [PREFIX=/usr/local/share/lua/5.2/] [TARGET=`Hammerspoon|Mjolnir`] make install
~~~

Note that if you do not provide `TARGET`, then it defaults to `Hammerspoon`, and if you do not provide `PREFIX`, then it defaults to your particular environments home directory (~/.hammerspoon or ~/.mjolnir).

### Require

~~~lua
notification = require("`base`._asm.notification")
~~~

Where `base` is `hs` for Hammerspoon, and `mjolnir` for Mjolnir.

### Functions
~~~lua
notification.new([fn,][attributes]) -> notification
~~~
Returns a new notification object with the assigned callback function after applying the attributes specified in the attributes argument.  The attribute table can contain one or key-value pairs where the key corrosponds to the short name of a notification attribute function.  The callback function receives as it's argument the notification object. Note that a notification without an empty title will not be delivered.

~~~lua
notification.withdraw_all()
~~~
Withdraw all posted notifications for your environment.  Note that this will withdraw all notifications for your environment, including those not sent by this module or that linger from previous reload and restarts.

##### Notification Methods
~~~lua
notification:send() -> self
~~~
Delivers the notification to the Notification Center.  If a notification has been modified, then this will resend it, setting the delivered status again.  You can invoke this multiple times if you wish to repeat the same notification.

~~~lua
notification:release() -> self
~~~
Disables the callback function for a notification.  Is also invoked during garbage collection (or a `base`.reload()).

~~~lua
notification:withdraw() -> self
~~~
Withdraws a delivered notification from the Notification Center.  Note that if you modify a delivered note, even with `release`, then it is no longer considered delivered and this method will do nothing.  If you want to fully remove a notification, invoke this method and then invoke `release`, not the other way around.

##### Attribute Methods
~~~lua
notification:title([string]) -> string
~~~
If a string argument is provided, first set the notification's title to that value.  Returns current value for notification title.

~~~lua
notification:subtitle([string]) -> string
~~~
If a string argument is provided, first set the notification's subtitle to that value.  Returns current value for notification subtitle.

~~~lua
notification:informativeText([string]) -> string
~~~
If a string argument is provided, first set the notification's informativeText to that value.  Returns current value for notification informativeText.

*The following are only apparent if you have Hammerspoon or Mjolnir's notification style set to Alert in the Notifications System Preferences Panel.*

~~~lua
notification:actionButtonTitle([string]) -> string
~~~
If a string argument is provided, first set the notification's action button title to that value.  Returns current value for notification action button title.  Can be blank, but not `nil`.  Defaults to "Notification".

~~~lua
notification:otherButtonTitle([string]) -> string
~~~
If a string argument is provided, first set the notification's cancel button's title to that value.  Returns current value for notification cancel button title.

~~~lua
notification:hasActionButton([bool]) -> bool
~~~
If a boolean argument is provided, first set whether or not the notification has an action button.  Returns current presence of notification action button. Defaults to true.

~~~lua
notification:soundName([string]) -> string
~~~
If a string argument is provided, first set the notification's delivery sound to that value.  Returns current value for notification delivery sound.  If it's nil, no sound will be played. Defaults to nil.

~~~lua
notification:alwaysPresent([bool]) -> bool
~~~
If a boolean argument is provided, determines whether or not the notification should be presented, even if the Notification Center's normal decision would be not to.  This does not affect the return value of the `presented` attribute -- that will still reflect the decision of the Notification Center. Returns the current status. Defaults to true.

~~~lua
notification:autoWithdraw([bool]) -> bool
~~~
If a boolean argument is provided, sets whether or not a notification should be automatically withdrawn once activated. Returns the current status.  Defaults to true.

##### Result Methods
The following methods are useful for checking the status of a notification or for use within the callback function.

~~~lua
notification:presented() -> bool
~~~
Returns whether the notification was presented by the decision of the Notification Center.  Under certain conditions (most notably if you're currently active in the application which sent the notification), the Notification Center can decide not to present a notification.  This flag represents that decision.

~~~lua
notification:delivered() -> bool
~~~
Returns whether the notification has been delivered to the Notification Center.

~~~lua
notification:remote() -> bool
~~~
Returns whether the notification was generated by a push notification (remotely).  Currently unused, but perhaps not forever.

~~~lua
notification:activationType() -> int
~~~
Returns whether the notification was generated by a push notification (remotely).  Currently unused, but perhaps not forever.

~~~lua
notification:actualDeliveryDate() -> int
~~~
Returns the delivery date of the notification in seconds since 1970-01-01 00:00:00 +0000 (e.g. `os.time()`).

##### Backwards compatibility:

~~~lua
notification.register(tag, fn) -> id
~~~
Registers a function to be called when an Apple notification with the given tag is clicked.

~~~lua
notification.show(title, subtitle, text, tag)
~~~
Convenience function to mimic Hydra's notify.show. Shows an Apple notification. Tag is a unique string that identifies this notification; any functions registered for the given tag will be called if the notification is clicked. None of the strings are optional, though they may each be blank.

~~~lua
notification.unregister(id)
~~~
Unregisters a function to no longer be called when an Apple notification with the given tag is clicked.

~~~lua
notification.unregisterall()
~~~
Unregisters all functions registered for notification-clicks; called automatically when user config

### Variables
~~~lua
notification.activationType[]
~~~
Convenience array of the possible activation types for a notification, and their reverse for reference.
    None                        The user has not interacted with the notification.
    ContentsClicked             User clicked on notification
    ActionButtonClicked         User clicked on Action button
    Replied                     User used Reply button (10.9) (not implemented yet)
    AdditionalActionClicked     Additional Action selected (10.10) (not implemented yet)

~~~lua
notification.defaultNotificationSound -> string
~~~
The string representation of the default notification sound.  Set `soundName` attribute to this if you want to use the default sound.

##### Backwards compatibility:
~~~lua
notification.registry[]
~~~
This table contains the list of registered tags and their functions.  It should not be modified directly, but instead by the `notification.register(tag, fn)` and `notification.unregister(id)` functions.

### License

> Released under MIT license.
>
> Copyright (c) 2015 Aaron Magill
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

