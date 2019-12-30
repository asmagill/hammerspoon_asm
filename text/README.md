hs.text
=======

***For those playing the home game, compatibility breaking changes afoot...***

Because the macOS string manipulation is based almost exclusively on UTF16 encodings, this modue is being split into multiple parts:

1. `hs.text` will represent blocks of text in an arbitrary (or even unspecified) encoding. Outside of converting between encodings and accepting data from other sources (`hs.http`, local files, etc.), this module will mostly be used for internal data representation and the tools used by programmers will likely be in the submodule(s).

2. `hs.text.utf16` will provide the expected functioanlity replicated from lua's `string` and `utf8` libraries optimizd for UTF16. Constructors for this module will accept `hs.text` objects or strings from lua.

3. other modules as needed?

Note: `hs.text.utf16` will internally represent its data as macOS native UTF16, which is equivalent to UTF16LittleEndian with the appropriate BOM prefix.  If your source is BigEndian, load it into `hs.text` then use that in the `hs.text.utf16` constructor. This will remove the need for duplication as found in `cp.utf16`.

These changes are being made because creating a single interface that works consistently across all of the different possible encodings and yet retains meaning within each encoding was becoming riddled with exceptions and complexities. Since UTF16 can represent (sometimes with surrogates) all of the characters in other encodings, it is simpler to leverage the builtin biases of the macOS API.

- - -

Very early work on addressing https://github.com/Hammerspoon/hammerspoon/issues/2215

Doesn't do much yet, other than allow you to convert byte strings into an object of a specified string encoding and then convert it to others, identify encodings the byte sequence *could* be valid for, etc.

See above mentioned issue and `NOTES` file for an approximate roadmap and plan.

Unlike other modules in my *Work-In-Progress* repository, this one will install itself as `hs.text` rather than `hs._asm.text`, as this is being developed specifically to be added to the core app as soon as it is reasonably functional.

### License

> Released under MIT license.
>
> Copyright (c) 2019 Aaron Magill
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
>
