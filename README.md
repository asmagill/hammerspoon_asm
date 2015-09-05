In progress Hammerspoon modules
===============================

This repository contains modules I am in the process of working on or testing out for Hammerspoon.  I am no longer attempting to maintain compatibility with Mjolnir as the environments have diverged to a point where attempting to do so was taking more time than actual work on these modules usually does.

The last commit where I paid much attention to compatibility between the two is probably found at https://github.com/asmagill/hammerspoon_asm/tree/270924f390a50fda9c2ae0e1910efaf588ffbac6, if there is still an interest.  Everything after this has been Hammerspoon focused and it's time for me to make a clean break.

### Sub Modules (See folder README.md)
The following submodules are located in this repository for organizational purposes.  Installation instructions for each will be given in the appropriate subdirectory.

The modules which have not already been supplanted or removed or deemed dead ends can presently be found in 'wip/' -- this will be undergoing a reorganization and I'm not sure yet what the final layout will be.  I am moving towards a model where you can clone this repository and then just type `make install` in the directory of any module you want to try out (and conversely, `make uninstall` to remove any you find you don't use or that later get added into something else or the Hammerspoon core).

### Documentation

The json files provided in some of the directories is in a format suitable for use with Hammerspoon's `hs.doc.fromJSONFile(file)` function.  In the near future, I hope to provide documentation on how to create these files yourself and make them available within the Hammerspoon console's help command.

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
>
