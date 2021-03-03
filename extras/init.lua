--- === hs._asm.extras ===
---
--- This module provides extras that will someday be a real boy.  But for now I want them in a consistent place before I have decided where they belong.
---
--- I include these here for my convenience but they will be moved if a proper home is discovered for them where inclusion as a public function makes sense.  I will try to make it clear if something moves on the github repo where this ends up, but expect to need to make changes as these functions/tools become real.

-- make sure these are in the right place for for doSpacesKey in internal.m
--     if not hs.keycodes then hs.keycodes = require("hs.keycodes") end
--     if not hs.window   then hs.window   = require("hs.window")   end

-- maybe save some pain, if the shim is installed; otherwise, expect an objc dump to console when this loads on stock Hammerspoon without pull #2308 applied

-- package.loadlib("/System/Library/Frameworks/AddressBook.framework/Versions/A/AddressBook","*")
local USERDATA_TAG = "hs._asm.extras"
local module = require(USERDATA_TAG .. ".internal")

local basePath = package.searchpath(USERDATA_TAG, package.path)
if basePath then
    basePath = basePath:match("^(.+)/init.lua$")
    if require"hs.fs".attributes(basePath .. "/docs.json") then
        require"hs.doc".registerJSONFile(basePath .. "/docs.json")
    end
end

local fnutils = require("hs.fnutils")

-- local bridge = require("hs._asm.bridging")
local stext = require("hs.styledtext")

-- private variables and methods -----------------------------------------

local _kMetaTable = {}
_kMetaTable._k = {}
_kMetaTable.__index = function(obj, key)
        if _kMetaTable._k[obj] then
            if _kMetaTable._k[obj][key] then
                return _kMetaTable._k[obj][key]
            else
                for k,v in pairs(_kMetaTable._k[obj]) do
                    if v == key then return k end
                end
            end
        end
        return nil
    end
_kMetaTable.__newindex = function(obj, key, value)
        error("attempt to modify a table of constants",2)
        return nil
    end
_kMetaTable.__pairs = function(obj) return pairs(_kMetaTable._k[obj]) end
_kMetaTable.__tostring = function(obj)
        local result = ""
        if _kMetaTable._k[obj] then
            local width = 0
            for k,v in pairs(_kMetaTable._k[obj]) do width = width < #k and #k or width end
            for k,v in fnutils.sortByKeys(_kMetaTable._k[obj]) do
                result = result..string.format("%-"..tostring(width).."s %s\n", k, tostring(v))
            end
        else
            result = "constants table missing"
        end
        return result
    end
_kMetaTable.__metatable = _kMetaTable -- go ahead and look, but don't unset this

local _makeConstantsTable = function(theTable)
    local results = setmetatable({}, _kMetaTable)
    _kMetaTable._k[results] = theTable
    return results
end

-- Public interface ------------------------------------------------------

--- hs._asm.extras.windowsByName([includeDesktopElements])
--- Function
--- Returns a table containing information about all available windows, even those ignored by hs.window
---
--- Parameters:
---  * includeDesktopElements - defaults to false; if true, includes windows which that are elements of the desktop, including the background picture and desktop icons.
---
--- Returns:
---  * A table whose first level contains keys which match Application names.  For each application name, its value is an array of tables describing each window created by that application.  Each window table contains the information returned by the CoreGraphics CGWindowListCopyWindowInfo function for that window.
---
--- Notes:
---  * The companion function, hs._asm.extras.listWindows, is a simple array of windows in the order in which CGWindowListCopyWindowInfo returns them.  This function groups them a little more usefully.
---  * This function also utilizes metatables to allow an easier browsing experience of the data from the console.
---  * The results of this function are of dubious value at the moment... while it should be possible to determine what windows are on other spaces (though probably not which space -- just "this space" or "not this space") there is at present no way to positively distinguish "real" windows from "virtual" windows used for internal application purposes.
---  * This may also provide a mechanism for determine when Mission Control or other System displays are active, but this is untested at present.
module.windowsByName = function(all)
    local windowTable = module.listWindows(all)
    local resultTable = {}
    for i,v in ipairs(windowTable) do
        resultTable[v.kCGWindowOwnerName] = resultTable[v.kCGWindowOwnerName] or
            setmetatable({},{__tostring = function(_)
                    local result = "contains "..tostring(#_).." windows"
                    return result
                end
            })
        v.kCGWindowBounds = setmetatable(v.kCGWindowBounds, { __tostring=function(_)
                local result = ""
                for i,v in pairs(_) do
                    result = result..tostring(i).."="..tostring(v)..", "
                end
                return "{ "..result.."}"
            end
        })
        table.insert(resultTable[v.kCGWindowOwnerName],
            setmetatable(v,{__tostring = function(_)
                    local result = ""
                    local width = 0
                    for i,v in pairs(_) do width = width < #i and #i or width end
                    for i,v in pairs(_) do
                        result = result..string.format("%-"..tostring(width).."s %s\n", i, tostring(v))
                    end
                    return result
                end
            }))
    end
    return setmetatable(resultTable, { __tostring=function(_)
          local result = ""
          local width = 0
          for i,v in pairs(_) do width = width < #i and #i or width end
          for i,v in pairs(_) do
              result = result..string.format("%-"..tostring(width).."s %s\n", i, tostring(v))
          end
          return result
      end
    })
end

--- hs._asm.extras.tableCopy(table1) -> table2
--- Function
--- Returns a copy of the provided table, taking into account self and external references.
---
--- Parameters:
---  * table1 -- the table to duplicate
---
--- Returns:
---  * table2 -- a duplicate of table1, which can be safely modified without changing the original table or subtables it references.
---
--- Notes:
---  * The metatable, if present, for table1 is applied to table2.  If you need a true duplicate of the metatable as well, do something like the following (note this only applies to the top-level tables metatable -- recursive metatable duplication is not supported):
---
---     newTable = setmetatable(
---             hs._asm.extras.tableCopy(originalTable),
---             hs._asm.extras.tableCopy(getmetatable(originalTable))
---     )
---
---  * Original code from https://forums.coronalabs.com/topic/27482-copy-not-direct-reference-of-table/
---  * For a more complex and powerful solution, check out https://gist.github.com/Deco/3985043; it seems overkill for what I need right now, but may be of interest in the furure.
module.tableCopy = function(object)
    local lookup_table = {}
    local function _copy(object)
        if type(object) ~= "table" then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local new_table = {}
        lookup_table[object] = new_table
        for index, value in pairs(object) do
            new_table[_copy(index)] = _copy(value)
        end
        return setmetatable(new_table, getmetatable(object))
    end
    return _copy(object)
end

--- hs._asm.extras.mods[...]
--- Variable
--- Table of key modifier maps for hs._asm.hotkey.bind. It's a 16 element table of keys containing differing cased versions of the key "casc" where the letters stand for Command, Alt/Option, Shift, and Control.
---
---     hs._asm.extras.mods = {
---       casc = {                     }, casC = {                       "ctrl"},
---       caSc = {              "shift"}, caSC = {              "shift", "ctrl"},
---       cAsc = {       "alt"         }, cAsC = {       "alt",          "ctrl"},
---       cASc = {       "alt", "shift"}, cASC = {       "alt", "shift", "ctrl"},
---       Casc = {"cmd"                }, CasC = {"cmd",                 "ctrl"},
---       CaSc = {"cmd",        "shift"}, CaSC = {"cmd",        "shift", "ctrl"},
---       CAsc = {"cmd", "alt"         }, CAsC = {"cmd", "alt",          "ctrl"},
---       CASc = {"cmd", "alt", "shift"}, CASC = {"cmd", "alt", "shift", "ctrl"},
---     }
---
---     hs._asm.extras.mods.plusFN("label") will return the specified modifier table with "fn" added.
---     A more complete list may be provided if the eventtap version of hs.hotkey goes core.
---
--- What fun if we ever differentiate between left, right, either, and both!
---
module.mods = {
    casc = {                     }, casC = {                       "ctrl"},
    caSc = {              "shift"}, caSC = {              "shift", "ctrl"},
    cAsc = {       "alt"         }, cAsC = {       "alt",          "ctrl"},
    cASc = {       "alt", "shift"}, cASC = {       "alt", "shift", "ctrl"},
    Casc = {"cmd"                }, CasC = {"cmd",                 "ctrl"},
    CaSc = {"cmd",        "shift"}, CaSC = {"cmd",        "shift", "ctrl"},
    CAsc = {"cmd", "alt"         }, CAsC = {"cmd", "alt",          "ctrl"},
    CASc = {"cmd", "alt", "shift"}, CASC = {"cmd", "alt", "shift", "ctrl"},
    plusFN = function(label)
        local tmpTable = module.tableCopy(module.mods[label])
        table.insert(tmpTable, "fn")
        return tmpTable
    end,
}

--- hs._asm.extras.mtTools[...]
--- Variable
--- An array containing useful functions for metatables in a single location for reuse.  Use as `setmetatable(myTable, { __index = hs._asm.extras.mtTools })`
--- Currently defined:
---     myTable:get("path.key" [, default])      -- Retrieve a value for key at the specified path in (possibly nested) table, or a default value, if it doesn't exist.  Note that "path" can be arbitrarily deeply nested tables (e.g. path.p2.p3. ... .pN).
---     myTable:set("path.key", value [, build]) -- Set value for key at the specified path in table, building up the tables along the way, if build argument is true.   Note that "path" can be arbitrarily deeply nested tables (e.g. path.p2.p3. ... .pN).
module.mtTools = {
    get = function(self, key_path, default)
        local root = self
        for part in string.gmatch(key_path, "[%w_]+") do
            root = root[part]
            if not root then return default end
        end
        return root
    end,
    set = function(self, key_path, value, build)
        local root = self
        local pathPart, keyPart

        for part, sep in string.gmatch(key_path, "([%w_]+)([^%w_]?)") do
            if sep ~= "" then
                if (not root[part] and build) or type(root[part]) == "table" then
                    root[part] = root[part] or {}
                    root = root[part]
                else
                    error("Part "..part.." of "..key_path.." either exists and is not a table, or does not exist and build not set to true.", 2)
                    return nil
                end
            else
                root[part] = value
                return root[part]
            end
        end
    end
}

--- hs._asm.extras.versionCompare(v1, v2) -> bool
--- Function
--- Compare version strings and return `true` if v1 < v2, otherwise false.
---
--- Note that this started out for comparing luarocks version numbers, but should work for many cases. The basics are listed below.
---
--- Luarocks version numbers: x(%.y)*-z
---      x and y are probably numbers... but maybe not... z is a number
---
--- More generically, we actually accept _ or . as a separator, but only 1 - to keep with the luarocks spec.
---
--- Our rules for testing:
--- 1. if a or b start with "v" or "r" followed immediately by a number, drop the letter.
--- 2. break apart into x(%.y)* and z (we actually allow the same rules on z as we do for the first part, but if I understand the rockspec correctly, this should never actually happen)
--- 3. first compare the x(%.y)* part.  If they are the same, only then compare the z part.
---
--- Repeat the following for each part:
--- 1. if the version matches so far, and a has more components, then return a > b. e.g. 3.0.1 > 3.0 (of course 3.0.0 > 3.0 as well... should that change?)
--- 2. If either part n of a or part n of b cannot be successfully changed to a number, compare as strings. Otherwise compare as numbers.
---
--- This does mean that the following probably won't work correctly, but at
--- least with luarocks, none have been this bad yet...
---
---     3.0 "should" be > then a release candidate: 3.0rc
---     3.0rc2 and 3.0.rc1 (inconsistent lengths of parts)
---     3.0.0 aren't 3.0 "equal" (should they be?)
---     "dev" should be before "alpha" or "beta"
---     "final" should be after "rc" or "release"
---     dates as version numbers that aren't yyyymmdd
---     runs of 0's (tonumber("00") == tonumber("000"))
---     "1a" and "10a"
---
---     others?
module.version_compare = function(a,b)

    local a = a or "" ; if type(a) == "number" then a = tostring(a) end
    local b = b or "" ; if type(b) == "number" then b = tostring(b) end

    a = a:match("^[vr]?(%d.*)$") or a
    b = b:match("^[vr]?(%d.*)$") or b

--    print(a,b)

    local aver, ars = a:match("([%w%._]*)-?([%w%._]*)")
    local bver, brs = b:match("([%w%._]*)-?([%w%._]*)")
    local averp, arsp = {}, {}
    local bverp, brsp = {}, {}

    aver, ars, bver, brs = aver or "", ars or "", bver or "", brs or ""

    for p in aver:gmatch("([^%._]+)") do table.insert(averp, p) end
    for p in bver:gmatch("([^%._]+)") do table.insert(bverp, p) end
    for p in ars:gmatch("([^%._]+)") do table.insert(arsp, p) end
    for p in brs:gmatch("([^%._]+)") do table.insert(brsp, p) end

    for i = 1, #averp, 1 do
        if i > #bverp then return false end
--        print(averp[i],bverp[i])
        if tonumber(averp[i]) and tonumber(bverp[i]) then
            averp[i] = tonumber(averp[i])
            bverp[i] = tonumber(bverp[i])
        end
        if averp[i] ~= bverp[i] then return averp[i] < bverp[i] end
    end

    for i = 1, #arsp, 1 do
        if i > #brsp then return false end
--        print(arsp[i],brsp[i])
        if tonumber(arsp[i]) and tonumber(brsp[i]) then
            arsp[i] = tonumber(arsp[i])
            brsp[i] = tonumber(brsp[i])
        end
        if arsp[i] ~= brsp[i] then return arsp[i] < brsp[i] end
    end

    return false
end

--- hs._asm.extras.bundleIDForApp(app) -> bundleID
--- Function
--- Returns the bundle id for the application with the specified name, if it can be found.
---
--- Parameters:
---  * app - the name of the application
---
--- Returns:
---  * the bundle id or ": could not find ." if it could not be found
---
--- Notes:
---  * this function uses `mdls` to search for the application in the Spotlight metadata.
module.bundleIDForApp = function(app)
    return (hs.execute([[mdls -name kMDItemCFBundleIdentifier -r "$(mdfind 'kMDItemKind==Application' | grep /]] .. app .. [[.app | head -1)"]]))
end

--- hs._asm.extras.caseInsensitivePattern(string) -> pattern
--- Function
--- Returns a pattern which matches a case-insensitive version of the string provided when used with the Lua string pattern matching functions.
---
--- Parameters:
---  * string - a string to match
---
--- Returns:
---  * a pattern which can be used by the Lua string pattern matching functions to match the specified string in a case-insensitive way, properly ignoring any embedded pattern matching sequences which may already be in the string.
---
--- Notes:
---  * Example: `hs._asm.extras.caseInsensitivePattern("content-length: %d+")` will return `[cC][oO][nN][tT][eE][nN][tT]-[lL][eE][nN][gG][tT][hH]: %d+`.
---
---  * Based on code found at http://stackoverflow.com/a/11402486
---  * May be added to the Hammerspoon core somewhere at some point.
module.caseInsensitivePattern = function(pattern)
    -- find an optional '%' (group 1) followed by any character (group 2)
    local p = pattern:gsub("(%%?)(.)", function(percent, letter)
        if percent ~= "" or not letter:match("%a") then
            -- if the '%' matched, or `letter` is not a letter, return "as is"
            return percent .. letter
        else
            -- else, return a case-insensitive character class of the matched letter
            return string.format("[%s%s]", letter:lower(), letter:upper())
        end
    end)
    return p
end

--- hs._asm.extras.tobits(integer, [width]) -> bitmask
--- Function
--- Returns the specified integer as a bitmask (boolean).
---
--- Parameters:
---  * integer - the integer to convert to a bitmask
---  * width   - an option integer specifying the number of bits to display.  If not specified, defaults to the smallest multiple of 8 that the number specified can be fully expressed as a bitmask in.
---
--- Returns:
---  * the bitmask for the specified integer
---
--- Notes:
---  * May be added to the Hammerspoon core somewhere at some point.
module.tobits = function(num, bits)
    bits = bits or (math.floor(math.log(num,2) / 8) + 1) * 8
    if bits == -(1/0) then bits = 8 end
    local value = ""
    for i = (bits - 1), 0, -1 do
        value = value..tostring((num >> i) & 0x1)
    end
    return value
end

--- hs._asm.extras.isinf(number) -> boolean
--- Function
--- Returns true or false specifying if the number provided represents infinity
---
--- Parameters:
---  * number - the number to check
---
--- Returns:
---  * true if the number represents infinity or false if it is a finite number
---
--- Notes:
---  * Lua represents infinity internally and displays "inf" when such a value is printed.  This function is (in my oppinion) more clear as to intent then `result = x == math.huge`.
module.isinf = function(x) return x == math.huge end

--- hs._asm.extras.isnan(number) -> boolean
--- Function
--- Returns true or false specifying if the number represents an invalid operation resulting in a value of NaN.
---
--- Parameters:
---  * number - the number to check
---
--- Returns:
---  * true if the number is NaN or false if it is a finite number
---
--- Notes:
---  * NaN represents the result of an invalid mathematical operation, the simplest of which is dividing 0 by 0.
---  * Lua represents NaN internally and displays "nan" when such a value is printed.  This function is (in my opinion) more clear as to intent then `result = x ~= x`.
module.isnan = function(x) return x ~= x end

--- hs._asm.extras.colorsFor(listName) -> none
--- Function
--- Prints the colors contained within the specified hs.drawing.color list name.
---
--- Parameters:
---  * listName - the name of the list to display.  Must be one of the lists returned by `hs.drawing.color.lists()`
---
--- Returns:
---  * None.  Displays the list of colors in a colored background to match each name in the console.
module.colorsFor = function(name)
    local a = stext.new("")
    for i,v in fnutils.sortByKeys(require"hs.drawing.color".colorsFor(name)) do
        a = a..stext.new(i.."\n", { color = { white = .5 }, backgroundColor = v })
    end
    require"hs.console".printStyledtext(a)
end

--- hs._asm.extras.colorDump() -> none
--- Function
--- Prints all of the colors defined in hs.drawing.color's lists.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None.  Displays the list of colors in a colored background to match each name in the console.
module.colorDump = function()
    for i,v in fnutils.sortByKeys(require"hs.drawing.color".lists()) do
        print(i)
        module.colorsFor(i)
    end
end

--- hs._asm.extras.idunno
--- Variable
--- A string containing ¯\_(ツ)_/¯.
---
--- I don't know where I first saw it, but I liked it and wanted to keep a copy in case I come up with a reason to use it someday.
module.idunno = "¯\\_(ツ)_/¯"

--- hs._asm.extras.graphpaperImage
--- Variable
--- An `hs.image` object containing an image of graph paper suitable for use as a color pattern.
---
--- The image is 50 x 50 points and contains grey graph lines every 10 points and a blue graph line at the far left and bottom of the graph.  This image is suitable for use as a color pattern by specifying `{ image = hs._asm.extras.graphpaperImage }` wherever a color is allowed.
module.graphpaperImage = require"hs.image".imageFromASCII([[
.........1.........3.........5.........7.........N
..................................................
..................................................
..................................................
..................................................
..................................................
..................................................
..................................................
..................................................
A................................................A
..................................................
..................................................
..................................................
..................................................
..................................................
..................................................
..................................................
..................................................
..................................................
C................................................C
..................................................
..................................................
..................................................
..................................................
..................................................
..................................................
..................................................
..................................................
..................................................
E................................................E
..................................................
..................................................
..................................................
..................................................
..................................................
..................................................
..................................................
..................................................
..................................................
G................................................G
..................................................
..................................................
..................................................
..................................................
..................................................
..................................................
..................................................
..................................................
..................................................
L........1.........3.........5.........7.........M
]],
{
    [9]  = { strokeColor = { blue = 1, alpha = 1 } },
    [10] = { strokeColor = { white = .25, alpha = 1 }, fillColor = { alpha = 0 }, shouldClose = false },
})

-- make sure to update paths for LuaSkin and Hammerspoon build locations
-- or set with hs.settings.set("_asm_extras_buildPath", <path>) in the
-- console where <path> is the directory containing the "build" directory
local buildPath = require("hs.settings").get("_asm_extras_buildPath") or "/usr/local/src/hammerspoon/"
module.dladdrWithLine = function(add)
    local fs      = require("hs.fs")
    local inspect = require("hs.inspect")

    local details = _xtras.dladdr(add)
    local address = string.format("0x%0x", add)
    if details then
        print(inspect(details))

        local fn = details.fname .. ".dSYM/Contents/Resources/DWARF/internal.so"
        if details.fname:match("LuaSkin$") then
            fn = buildPath .. "/build/LuaSkin.framework.dSYM/Contents/Resources/DWARF/LuaSkin"
        elseif details.fname:match("Hammerspoon$") then
            fn = buildPath .. "/build/Hammerspoon.app.dSYM/Contents/Resources/DWARF/Hammerspoon"
        elseif details.fname:match("/Hammerspoon.app/Contents/Resources/extensions/") then
            fn = details.fname
        end

        if (fs.attributes(fn)) then
            local cmd = "/usr/bin/atos -o " .. fn .. " -l " .. details.fbase .. " " .. address
            print(cmd)
            return hs.execute(cmd)
        else
            error(string.format("no dsym file found at %s", fn), 2)
        end
    else
        error(string.format("unable to get dladdr details for %s", address), 2)
    end
end


--- hs._asm.extras.detabOutput(string) -> string
--- Function
--- Converts tabs in multi-line string to tabs such that each field lines up like a report.
---
--- Parameters:
---  * `string` -- text to detab
---
--- Returns:
---  * the cleaned up report like input as a string
---
--- Notes:
---  * if pasting in text copied from the console that is likely to contain quotes, use block-quotes, e.g. `detabOutput([==[ ... pasted value ... ]==])`
module.detabOutput = function(output)
    local lines = fnutils.split(output, "[\r\n]")

    local widths, outputTable = {}, {}

    for i = 1, #lines, 1 do
        outputTable[i] = fnutils.split(lines[i], "\t")
        for n, v in ipairs(outputTable[i]) do
            widths[n] = math.max((widths[n] or 0), #(v or ""))
            if widths[n] > 99 then
                widths[n] = 99
                print(string.format("WARNING: width for '%s' too long", v))
            end
        end
    end

    local result = ""
    for i = 1, #lines, 1 do
        local fmtStr = ""
        for n, v in ipairs(outputTable[i]) do
            fmtStr = fmtStr .. "%-" .. tostring(widths[n]) .. "s  "
        end
        fmtStr = fmtStr:sub(1, -3) .. "\n"
        result = result .. string.format(fmtStr, table.unpack(outputTable[i]))
    end
    return result
end

-- Return Module Object --------------------------------------------------

return module
