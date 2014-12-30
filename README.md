Organizational space for Hammerspoon/Mjolnir modules.
=====================================================

I attempt to write these modules using documented OS X API functionality and develop under OS X Yosemite (10.10.x).  I do routinely try loading and testing these modules under 10.8, but these do not get rigorously tested there -- primarily I make sure that they don't crash, but YMMV.

Any module in which I explicitly use private or undocumented API's can be found at (https://github.com/asmagill/hammerspoon_asm.undocumented).

Unless otherwise indicated, these modules *should* work from 10.8, forward, but see above -- I routinely use and test under 10.10.  Where I use 10.9 or 10.10 specific functionality, I try to add code to fail gracefully, but no promises.  I will, however, note such in the documentation.

### Sub Modules (See folder README.md)
The following submodules are located in this repository for organizational purposes.  Installation instructions for each will be given in the appropriate subdirectory.

|Module         | Available | Description                                                                |
|:--------------|:---------:|:---------------------------------------------------------------------------|
|_asm.extras    | Git       | Random useful stuff I haven't decided how to package yet.                  |

I am uncertain at this time if I will be providing these and future modules via Luarocks... I am less than impressed with it's limited flexibility concerning makefiles and local variances.  If there is interest in precompiled binaries for these modules, post an issue and I'll see what the interest level is.

### Documentation

The json files provided at this level contain the documentation for all of these modules in a format suitable for use with Hammerspoon's `hs.doc.fromJSONFile(file)` function.  In the near future, I hope to extend this support to Mjolnir and provide a simple mechanism for combining multiple json files into one set of documents for use within the appropriate console and Dash docsets.

### License

> Released under MIT license.
>
> Copyright (c) 2014 Aaron Magill
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
>