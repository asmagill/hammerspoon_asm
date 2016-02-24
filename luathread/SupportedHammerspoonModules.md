Supported Hammerspoon Modules
=============================

This document contains information about what the status of various Hammerspoon modules is within a luathread instance provided by this module.  If you find any discrepancies or errors, please let me know!

Module auto-loading is not currently enabled.  This may be added once enough modules have been ported to justify it.

Individual modules can be installed by entering the appropriate subdirectory in `modules/` and using the same `make` command that you would use for building the LuaThread module itself;  they are also present in the v0.2 (and later) precompiled package and will be installed when you install it as described in README.md.

Note that these modules install themselves in a subdirectory of the `hs._asm.luathread` module, so the modified versions are only available from within a lua thread (your core application and any code you run normally with Hammerspoon are untouched).

### Core Hammerspoon Modules

Module             | Status   | Notes
-------------------|----------|------
hs.alert           | no       | maybe
hs.appfinder       | no       | requires application and window
hs.applescript     | no       | maybe
hs.application     | no       | maybe
hs.audiodevice     | no       |
hs.base64          | no       | probably
hs.battery         | no       | probably
hs.brightness      | no       |
hs.caffeinate      | no       |
hs.chooser         | no       |
hs.console         | no       |
hs.crash           | no       |
hs.doc             | yes      | requires json and fs
hs.dockicon        | no       |
hs.drawing         | no       | probably not; tight UI integration
hs.eventtap        | no       |
hs.expose          | no       |
hs.fnutils         | yes      |
hs.fs              | partial  | volume submodule doesn't work as of v0.2
hs.geometry        | unknown  | should, but untested
hs.grid            | no       |
hs.hash            | no       | probably
hs.hints           | no       |
hs.host            | yes      | as of v0.2
hs.hotkey          | no       |
hs.http            | no       |
hs.httpserver      | no       |
hs.image           | no       |
hs.inspect         | yes      |
hs.ipc             | no       |
hs.itunes          | no       | requires alert, applescript, application
hs.javascript      | no       | maybe
hs.json            | yes      | as of v0.2
hs.keycodes        | no       | probably not, unless eventtap is added
hs.layout          | no       |
hs.location        | no       |
hs.logger          | unknown  | should, but untested
hs.menubar         | no       | would like to make this non-blocking, but IIRC some NSMenu stuff must be in main thread; will check
hs.messages        | no       | requires applescript
hs.milight         | no       |
hs.mjomatic        | no       |
hs.mouse           | no       |
hs.network         | no       | maybe
hs.notify          | no       |
hs.pasteboard      | no       | probably
hs.pathwatcher     | yes      | as of v0.2
hs.redshift        | no       |
hs.screen          | no       |
hs.settings        | no       | probably
hs.sound           | no       |
hs.spaces          | no       |
hs.speech          | no       |
hs.spotify         | no       | requires alert, applescript, application
hs.styledtext      | no       | probably not; requires drawing
hs.tabs            | no       |
hs.task            | no       | maybe
hs.timer           | no       | maybe
hs.uielement       | no       |
hs.urlevent        | no       |
hs.usb             | yes      | as of v0.2
hs.utf8            | no       | probably
hs.webview         | no       |
hs.wifi            | no       |
hs.window          | no       |

### Core Functions

Function                        | Status   | Notes
--------------------------------|----------|------
hs.accessibilityState           | no       |
hs.autoLaunch                   | no       |
hs.automaticallyCheckForUpdates | no       |
hs.checkForUpdates              | no       |
hs.cleanUTF8forConsole          | no       | if hs.utf8 added, this probably will be as well
hs.completionsForInputString    | no       | no need in non-console thread
hs.configdir                    | yes      |
hs.consoleOnTop                 | no       |
hs.dockIcon                     | no       |
hs.docstrings_json_file         | yes      |
hs.execute                      | yes      |
hs.focus                        | no       |
hs.getObjectMetatable           | no       |
hs.help                         | yes      | Not included by default; add `hs.help = require("hs.doc")` to `~/.hammerspoon/_init.lua`
hs.menuIcon                     | no       |
hs.openAbout                    | no       |
hs.openConsole                  | no       |
hs.openPreferences              | no       |
hs.processInfo                  | no       | maybe
hs.rawprint                     | no       |
hs.reload                       | no       | maybe, to reload thread
hs.showError                    | no       | would like something visual, but this requires hs.notify
hs.shutdownCallback             | no       | probably not
hs.toggleConsole                | no       |
