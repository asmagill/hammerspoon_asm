### hs._asm.speech

*Moving this into core soon, so this version, which includes the unpredictable and somewhat dangerous (in that you can easily crash Hammerspoon or the speech synthesizer by sending unexpected values to `hs._asm.speech:setProperty`) "other" methods will be in the _asm namespace and you can load them and test them side be side if you want to.  Or don't want to.  But I might sometime.*

The version in core will have the unsafe methods removed, but a link in the comments to this folder will be given if anyone wants to try to extend it more.

* * *

This module provides an interface to the NSSpeechSynthesizer and NSSpeechRecognizer object classes in OS X.  With these Hammerspoon can generate speech and react to spoken commands through the Speech and Dictation features of OS X.

The ultimate plan is for this to go into the core modules and be included with Hammerspoon by default.

* * *

However, NSSpeechSynthesizer is a mess... the docs have obvious errors (both in Dash and on Apple's web site), it appears as if its a mash of the old MacinTalk style functionality with the more modern higher quality voices tacked on as an after thought, and the Cocoa objects appear to be but a very thin layer on top of the Carbon API, and not a complete or 100% accurate one at that...

At least one of the bugs I've encountered has been around since at least 10.5.

Sorry... rant mode off...

By way of comparison, NSSpeechRecognizer was almost a let down in how simple it was to get working.

* * *

Basic functionality with callback support for both Text-To-Speech (hs._asm.speech) and responding to spoken commands (hs._asm.speech.listener) works quite well, so I'm putting this out for those who want to play with it before I'm done seeing what can be done to make the more esoteric and minor settings safe and/or reliable to use without fear of crashing.

Since I hope this is a separate module for only a short time, you'll have to compile this if you want to use it.  By default, the potentially buggy functions are disabled... it should be obvious what to change if you want to live dangerously :-)

### Installation

Basically, clone/copy the repository, enter into this directory and do the following:

~~~bash
$ [HS_APPLICATION=/Applications] [PREFIX=~/.hammerspoon] make install
~~~

If Hammerspoon.app is in your /Applications folder, you may leave `HS_APPLICATION=/Applications` out and if you are fine with the module being installed in your Hammerspoon configuration directory, you may leave `PREFIX=~/.hammerspoon` out as well.  For most people, it will probably be sufficient to just type `make install`.

Unlike most of my other modules, this one will be accessible as `hs._asm.speech` (i.e. without the _asm sub-space) as it's ultimate intended destination is the core application.

Documentation is also embedded in the files themselves, rather than spelled out here, because the automated parser will be using them for inclusion in the web site and Dash documentation when it is finally merged.

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
