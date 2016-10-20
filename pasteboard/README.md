hs.pasteboard
=============

This is a staging area for a proposed update to Hammerspoon's `hs.pasteboard` module.  It is a (hopefully temporary) replacement for the built in `hs.pasteboard` module that offers all of the existing functionality with a few additions, described below.  Please report any problems you may encounter here, rather than at the Hammerspoon site, if you choose to try out this module before it makes it into the core application.

A precompiled version of this module can be found in this directory with a name along the lines of `pasteboard-v1.y.tar.gz`. This can be installed by downloading the file and then expanding it as follows:

~~~sh
$ cd ~/.hammerspoon # or wherever your Hammerspoon init.lua file is located
$ tar -xzf ~/Downloads/pasteboard-v1.x.tar.gz # or wherever your downloads are located
~~~

If you wish to build this module yourself, and have XCode installed on your Mac, the best way (you are welcome to clone the entire repository if you like, but no promises on the current state of anything else) is to download `init.lua`, `internal.m`, and `Makefile` (at present, nothing else is required) into a directory of your choice and then do the following:

~~~sh
$ cd wherever-you-downloaded-the-files
$ [HS_APPLICATION=/Applications] [PREFIX=~/.hammerspoon] make install
~~~

If your Hammerspoon application is located in `/Applications`, you can leave out the `HS_APPLICATION` environment variable, and if your Hammerspoon files are located in their default location, you can leave out the `PREFIX` environment variable.  For most people it will be sufficient to just type `make install`.

As always, whichever method you chose, if you are updating from an earlier version it is recommended to fully quit and restart Hammerspoon after installing this module to ensure that the latest version of the module is loaded into memory.

- - -

### Additions

The following functions are added to the pasteboard module -- for all other `hs.pasteboard` functions, please refer to the [Hammerspoon API documentation](http://www.hammerspoon.org/docs/index.html) or use the embedded help available through the `help` or `hs.hsdocs` console commands.

(Note that the relative links within the following descriptions which refer to other functions within the `hs.pasteboard` module will not currently work -- they are included in the documentation strings so that they *will* work when this is embedded in the official documentation and it seemed like too much work to edit them out just for this document which will (hopefully) be required only for a short time!)

- - -

~~~lua
hs.pasteboard.readDataForUTI([name], uti) -> string
~~~
Returns the first item on the pasteboard with the specified UTI as raw data

Parameters:
 * name - an optional string indicating the pasteboard name.  If nil or not present, defaults to the system pasteboard.
 * uti  - a string specifying the UTI of the pasteboard item to retrieve.

Returns:
 * a lua string containing the raw data of the specified pasteboard item

Notes:
 * *EXPERIMENTAL* - this function may undergo changes which may change its syntax as it is being tested.

 * The UTI's of the items on the pasteboard can be determined with the [hs.pasteboard.allContentTypes](#allContentTypes) and [hs.pasteboard.contentTypes](#contentTypes) functions.

- - -

~~~lua
hs.pasteboard.readPListForUTI([name], uti) -> string
~~~
Returns the first item on the pasteboard with the specified UTI as a property list item

Parameters:
 * name - an optional string indicating the pasteboard name.  If nil or not present, defaults to the system pasteboard.
 * uti  - a string specifying the UTI of the pasteboard item to retrieve.

Returns:
 * a lua item representing the property list value of the pasteboard item specified

Notes:
 * *EXPERIMENTAL* - this function may undergo changes which may change its syntax as it is being tested.

 * The UTI's of the items on the pasteboard can be determined with the [hs.pasteboard.allContentTypes](#allContentTypes) and [hs.pasteboard.contentTypes](#contentTypes) functions.

 * Property list items are those items which can be represented as Objective-C NSObjects which conform to the NSCoding protocol.
 * In Hammerspoon terms, this means any data which can be completely described as a string (NSString), a number (NSNumber), a table (NSArray and NSDictionary), recognized types with Hammerspoon userdata conversion support (NSColor, NSAttributedString, etc.) or some combination of these.  Property list objects for which no conversion support currently exists will be returned as raw data in a lua string.
 * Not all pasteboard items which correspond to individual (i.e. not array or dictionary) object types (e.g. a string, a number, etc.) appear to work with this function -- it seems to be source application dependent as sometimes the item will be returned and other times this function returns nil for an item with the same UTI.  At present, there is no way to determine this programmatically without checking the results of this function and then falling back to one of the other `hs.pasteboard` "read" functions if this returns nil.
   * If you know that you are retrieving a single item object that conforms to one of the built in "read" functions ([hs.pasteboard.readColor](#readColor), [hs.pasteboard.readImage](#readImage), [hs.pasteboard.readSound](#readSound), [hs.pasteboard.readString](#readString), [hs.pasteboard.readStyledText](#readStyledText), and [hs.pasteboard.readURL](#readURL)) it is recommended that you use these functions instead as they are not tied to a specific UTI and will retrieve the object from any UTI which can be converted into the required type.

- - -

~~~lua
hs.pasteboard.writeDataForUTI([name], uti, data) -> string
~~~
Sets the pasteboard to the contents of the data and assigns its type to the specified UTI.

Parameters:
 * name - an optional string indicating the pasteboard name.  If nil or not present, defaults to the system pasteboard.
 * uti  - a string specifying the UTI of the pasteboard item to set.
 * data - a string specifying the raw data to assign to the pasteboard.

Returns:
 * True if the operation succeeded, otherwise false

Notes:
 * *EXPERIMENTAL* - this function may undergo changes which may change its syntax as it is being tested.

 * The UTI's of the items on the pasteboard can be determined with the [hs.pasteboard.allContentTypes](#allContentTypes) and [hs.pasteboard.contentTypes](#contentTypes) functions.

- - -

~~~lua
hs.pasteboard.writePListForUTI([name], uti, data) -> string
~~~
Sets the pasteboard to the contents of the data and assigns its type to the specified UTI.

Parameters:
 * name - an optional string indicating the pasteboard name.  If nil or not present, defaults to the system pasteboard.
 * uti  - a string specifying the UTI of the pasteboard item to set.
 * data - a lua type which can be represented as a property list value.

Returns:
 * True if the operation succeeded, otherwise false

Notes:
 * *EXPERIMENTAL* - this function may undergo changes which may change its syntax as it is being tested.

 * The UTI's of the items on the pasteboard can be determined with the [hs.pasteboard.allContentTypes](#allContentTypes) and [hs.pasteboard.contentTypes](#contentTypes) functions.

 * Property list items are those items which can be represented as Objective-C NSObjects which conform to the NSCoding protocol.
 * In Hammerspoon terms, this means any data which can be completely described as a string (NSString), a number (NSNumber), a table (NSArray and NSDictionary), recognized types with Hammerspoon userdata conversion support (NSColor, NSAttributedString, etc.) or some combination of these.  Property list objects for which no conversion support currently exists should be specified as raw data in a lua string.

- - -

### License

> The MIT License (MIT)
>
> Copyright (c) 2016 Aaron Magill
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
