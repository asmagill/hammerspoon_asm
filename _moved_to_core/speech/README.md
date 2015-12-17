### hs._asm.speech

This module will be in the upcoming core release; however, there are still some features with regards to properties which are not implemented.  Getting them to work reliably and safely has proven to be more difficult than it is worth for 90%+ of the uses `hs.speech` will be called to perform, so the core module is written with safety in mind and leaves out these items.

This version includes basic support for the NSSpeechSynthesizer's `setObject:forProperty:error:` and `getObjectForProperty:error:` methods, but since they only seem to work for some combinations and can cause crashes if used improperly, they were left out of the core module version.  This version is left in case someone who is more familiar with NSSpeechSynthesizer or its Carbon equivalent and wants to fix it.

### Installation

Basically, clone/copy the repository, enter into this directory and do the following:

~~~bash
$ [HS_APPLICATION=/Applications] [PREFIX=~/.hammerspoon] make install
~~~

If Hammerspoon.app is in your /Applications folder, you may leave `HS_APPLICATION=/Applications` out and if you are fine with the module being installed in your Hammerspoon configuration directory, you may leave `PREFIX=~/.hammerspoon` out as well.  For most people, it will probably be sufficient to just type `make install`.

Documentation is embedded in the files themselves, rather than spelled out here, because the automated parser uses them for inclusion in the web site and Dash documentation when built in core.

* * *

If anyone has familiarity with programming with NSSpeechSynthesizer or wants to otherwise contribute, feel free to comment or make suggestions on the code... I'd love to find that I'm missing something simple that would make everything snap into place regarding using setObject:forProperty: without crashing the synthesizer process, getting values with getObjectProperty: for things like errors and (especially) getting the delegate to actually invoke the correct method when an embedded command triggers an error during synthesis (currently that delegate method seems to be ignored, though all of the others work fine)

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
