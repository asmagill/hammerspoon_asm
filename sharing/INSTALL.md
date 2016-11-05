hs._asm.sharing
===============

A precompiled version of this module can be found in this directory with a name along the lines of `sharing-v0.x.tar.gz`. This can be installed by downloading the file and then expanding it as follows:

~~~sh
$ cd ~/.hammerspoon # or wherever your Hammerspoon init.lua file is located
$ tar -xzf ~/Downloads/sharing-v0.x.tar.gz # or wherever your downloads are located
~~~

If you wish to build this module yourself, and have XCode installed on your Mac, the best way (you are welcome to clone the entire repository if you like, but no promises on the current state of anything) is to download `init.lua`, `internal.m`, and `Makefile` (at present, nothing else is required) into a directory of your choice and then do the following:

~~~sh
$ cd wherever-you-downloaded-the-files
$ [HS_APPLICATION=/Applications] [PREFIX=~/.hammerspoon] make install
~~~

If your Hammerspoon application is located in `/Applications`, you can leave out the `HS_APPLICATION` environment variable, and if your Hammerspoon files are located in their default location, you can leave out the `PREFIX` environment variable.  For most people it will be sufficient to just type `make install`.

As always, whichever method you chose, if you are updating from an earlier version it is recommended to fully quit and restart Hammerspoon after installing this module to ensure that the latest version of the module is loaded into memory.
