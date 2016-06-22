This is a test version of `hs.hotkey` for Hammerspoon users running the 10.12 Beta.

**This requires Hammerspoon *and* OS X 10.12 beta**

You can compile this module by downloading `internal.m`, `init.lua`, and `Makefile` into a folder and then typing:

~~~sh
$ cd wherever-you-downloaded-the-files
$ [HS_APPLICATION=/Applications] [PREFIX=~/.hammerspoon] make install
~~~

If your Hammerspoon application is located in `/Applications`, you can leave out the `HS_APPLICATION` environment variable, and if your Hammerspoon files are located in their default location (`~/.hammerspoon`), you can leave out the `PREFIX` environment variable.  For most people it will be sufficient to just type `make install`.

You can remove it later with `[PREFIX=~/.hammerspoon] make uninstall`.

A pre-compiled version is also available as `hotkey1012.tar.gz`, if you prefer.  Download the file and then do the following:

~~~sh
$ cd ~/.hammerspoon # or wherever your Hammerspoon configuration files are located
$ tar -xzf ~/Downloads/hotkey1012.tar.gz # or wherever your downloaded files are located
~~~

This can later be removed by typing `rm -fr ~/.hammerspoon/hs/hotkey` (adjusted to whatever PREFIX you used above, if it's not `~/.hammerspoon`).

Once installed, completely quit and restart Hammerspoon and then try the following in the Hammerspoon console:

~~~lua
hs.hotkey.bind({"cmd","alt","shift"},"e",function() print("notFN",hs.inspect(hs.eventtap.checkKeyboardModifiers())) end)
hs.hotkey.bind({"cmd","alt","shift","fn"},"e",function() print("withFN", hs.inspect(hs.eventtap.checkKeyboardModifiers())) end)
~~~

A warning like the following will appear after typing the second entry: `15:54:33 ** Warning:   LuaSkin: using kEventKeyModifierFnBit` -- this is expected and will be removed later.

Under OS X 10.11.5, I get the following (which indicates that the `fn` addition, which toggles bit 17 of the modifier flags, is being ignored, so it sees them as the same global hotkey):

~~~lua
> hs.hotkey.bind({"cmd","alt","shift"},"e",function() print("notFN",hs.inspect(hs.eventtap.checkKeyboardModifiers())) end)
hs.hotkey: keycode: 14, mods: 0x0b00 (0x7fd7864cb008)

> hs.hotkey.bind({"cmd","alt","shift","fn"},"e",function() print("withFN", hs.inspect(hs.eventtap.checkKeyboardModifiers())) end)
15:54:33 ** Warning:   LuaSkin: using kEventKeyModifierFnBit
********
15:54:33 ERROR:   LuaSkin: hs.hotkey:enable() keycode: 14, mods: 0x20b00, RegisterEventHotKey failed: -9878
********
nil
~~~

If you do not get the error for the second entry, try hitting the key combination `Cmd-Alt-Shift E` with and without the `Fn` key being held down and let me know what the results are in Hammerspoon issue [#922](https://github.com/Hammerspoon/hammerspoon/issues/922).