In progress Hammerspoon modules
===============================

This repository contains modules I am in the process of working on or testing out for Hammerspoon.

### Universal Builds

Apple computers now come in two flavors -- Intel and Arm (M1). Because of this, there is a push to create Universal applications, applications which contain code for both architectures and are capable of running on both types of systems.

As of version 0.9.82, Hammerspoon is now a universal application, but when running on the M1 architecture, external libraries (modules) which are compiled for the Intel architecture will no longer work unless you run Hammerspoon in Rosetta2 mode. To that end, I am in the process of modifying these modules to also be Universal builds. The Makefile template found at this level of the repository, supports the following targets which can be used to craft modules to best suit your requirements:

* `make` - will make the module for the architecture of the machine the build is being performed on.
* `make x86_64` - makes the module specifically for the Intel architecture.
* `make arm64` - makes the module specifically for the Arm (M1) architecture.
* `make universal` - makes a universal library combining both the Intel and the Arm (M1) architectures.

For the install targets, you can actually skip the build step above -- the correct build step will be performed automatically.
* `[PREFIX=~/.hs] make install` - installs the module for the current machine architecture.
* `[PREFIX=~/.hs] make install-x86_64` - installs the module built for the Intel architecture.
* `[PREFIX=~/.hs] make install-arm64` - installs the module built for the Arm (M1) architecture.
* `[PREFIX=~/.hs] make install-universal` - installs the module built as a universal library (i.e. for both architectures).

For modules which have precompiled binaries, the provided pre-built module is a universal build. This does make them (very slightly) larger then a module built for your specific architecture, but simplifies releases and means that the module will continue to work even if you run Hammerspoon with Rosetta2 enabled.

I have confirmed that these modules will load on both Intel and M1 architectures, but I have not fully tested all of the functionality on the M1 architecture -- no architecture specific changes have been added yet. While most of the modules *should* work as expected, there may be some edge cases that will be fixed in future updates updates.

### License

> Released under MIT license.
>
> Copyright (c) 2020 Aaron Magill
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
>
