Implementation Plans/Thoughts/Notes


should integer key to __index return "char" at that position (e.g. `hs.text:sub(key,key)`?
should _len return the same thing as `len` below with no options? or not be implemented?
    if __index above implemented, then this should too

> inspect1(string)
{
// Done
  lower = <function 9>,
  upper = <function 17>

// Planned
  find = <function 4>,      // support for patterns uncertain
  len = <function 8>,       // `hs.text:len` will likely combine this and `utf8.len` possibly with additional options
  match = <function 10>,    // support for patterns uncertain
  reverse = <function 14>,
  sub = <function 15>,

// Uncertain
  gmatch = <function 6>,
  gsub = <function 7>,
  rep = <function 13>,

// Probably Not
  byte = <function 1>,      // specific to single byte encodings; use `tostring(hs.text object):byte([i],[j])`
  char = <function 2>,      // use `hs.text.new(string.char(...))`
  format = <function 5>,    // use `hs.text.new(string.format(...))` to create formatted string in required encoding

// No
  dump = <function 3>,      // binary representation of lua functions -- encoding would destroy
  pack = <function 11>,     // binary encoding of data in portable string -- encoding would destroy
  packsize = <function 12>, // binary encoding of data in portable string -- encoding would destroy
  unpack = <function 16>,   // binary encoding of data in portable string -- encoding would destroy
}

> inspect1(utf8)
{
// Planned
  codepoint = <function 2>, // can this work with *all* encodings or just limited to unicode/ascii/simple?
  codes = <function 3>,     // can this work with *all* encodings or just limited to unicode/ascii/simple?
  offset = <function 5>     // make more generic -- n'th char of encoding, return byte position in the rawData

// Probably Not
  char = <function 1>,      // see `codepointToUTF8` below (a "safer" version of this that doesn't barf on invalid codepoints)
  len = <function 4>,       // `hs.text:len` will likely combine this and `string.len` possibly with additional options

// No
  charpattern = "....",     // used to iterate UTF8 in 8bit world; better to use module len and sub
}

> inspect1(hs.utf8)
{
// Uncertain
  codepointToUTF8 = <function 2>,   // use `hs.text.new(hs.utf8.codepointToUTF8(...))`; maybe replicate as `hs.text` constructor?
                                    // need to research what surrogate region used for and if current implementation covers all
                                    // possibilities in all unicode variants (8, 16, 32, be, le) before making generic constructor.

// No
  asciiOnly = <function 1>,         // use `hs.utf8.asciiOnly(tostring(hs.text object))` or `hs.utf8.asciiOnly(hs.text:rawData())`
  fixUTF8 = <function 3>,           // use `hs.text:asEncoding(#, true)`
  hexDump = <function 4>,           // use `hs.utf8.hexDump(tostring(hs.text object))` or `hs.utf8.hexDump(hs.text:rawData())`
  registerCodepoint = <function 5>, // n/a
  registeredKeys = {...},           // n/a
  registeredLabels = {...}          // n/a
}


Still need to review `cp.text` and `utf16.utf16` to see what to migrate/modify into this module

Still need to review `NSString` docs for other functions we can easily add

Still need to review Unicode Normalization wiki and compare to NSString normalization methods to see if sufficient or if something more required.
