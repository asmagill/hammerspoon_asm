An experiment capturing event data through NSEvent, rather than CGEvent, in Hammerspoon

Probably won't use this for much beyond testing because
* NSEvent only allows sending and modifying events destined for our own application
* NSEvent's global watcher... doesn't seem to work reliably in my initial, admittedly very brief, tests

However, it has helped to understand system events (things like adjusting brightness, etc.) so I'll probably keep it around and push it to my GitHub pages eventually, but I doubt it will be added to core, though some portions of it may be added in a modified for to hs.eventtap's cleanup or used in wrappers added to hs.eventtap.

Feel free to do what you want with this code.
