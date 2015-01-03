--- === {PATH}.{MODULE} ===
---
--- This module provides extras that will someday be a real boy.  But for now I want them in a consistent place before I have decided where they belong.
---
--- I include these here for my convenience but they will be moved if a proper home is discovered for them where inclusion as a public function makes sense.  I will try to make it clear if something moves on the github repo where this ends up, but expect to need to make changes as these functions/tools become real.

local module = require("{PATH}.{MODULE}.internal")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

--- {PATH}.{MODULE}.mods[...]
--- Variable
--- Table of key modifier maps for {PATH}.hotkey.bind. It's a 16 element table of keys containing differing cased versions of the key "casc" where the letters stand for Command, Alt/Option, Shift, and Control.
---
---     {PATH}.{MODULE}.mods = {
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
}


--- {PATH}.{MODULE}.appleKeys[...]
--- Variable
--- Array of symbols representing special keys in the mac environment, as per http://macbiblioblog.blogspot.com/2005/05/special-key-symbols.html.  Where there are alternatives, I've tried to verify that the first is Apple's preference for their own documentation.  I found a dev file concerning this once, but forgot to link it, so I'll add that here when I find it again.
module.appleKeys = {
    ["escape"] = "⎋",               ["tab"] = "⇥",
    ["backtab"] = "⇤",              ["capslock"] = "⇪",
    ["shift"] = "⇧",                ["ctrl"] = "⌃",
    ["alt"] = "⌥",                  ["option"] = "⌥",
    ["apple"] = "",                ["cmd"] = "⌘",
    ["space"] = "␣",                ["return"] = "⏎",
    ["return2"] = "↩",              ["delete"] = "⌫",
    ["forwarddelete"] = "⌦",        ["help"] = "﹖",
    ["home"] = "⇱",                 ["home alternate2"] = "↖",
    ["home alternate3"] = "↸",      ["end"] = "⇲",
    ["end2"] = "↘",                 ["pageup"] = "⇞",
    ["pagedown"] = "⇟",             ["up"] = "↑",
    ["up2"] = "⇡",                  ["down"] = "↓",
    ["down2"] = "⇣",                ["left"] = "←",
    ["left2"] = "⇠",                ["right"] = "→",
    ["right2"] = "⇢",               ["padclear"] = "⌧",
    ["numlock"] = "⇭",              ["eject"] = "⏏",
    ["power"] = "⌽",                ["padenter"] = "⌤", -- apple preferred
    ["padenter2"] = "⎆", -- sun preferred
    ["padenter3"] = "↩",
}

--- {PATH}.{MODULE}.hexDump(string [, count]) -> string
--- Function
--- Treats the input string as a binary blob and returns a prettied up hex dump of it's contents. By default, a newline character is inserted after every 16 bytes, though this can be changed by also providing the optional count argument.  This is useful with the results of `{PATH}.{MODULE}.userDataToString` or `string.dump` for debugging and the curious, and may also provide some help with troubleshooting utf8 data that is being mis-handled or corrupted.
module.hexDump = function(stuff, linemax)
	local ascii = ""
	local count = 0
	local linemax = tonumber(linemax) or 16
	local buffer = ""
	local rb = ""
	local offset = math.floor(math.log(#stuff,16)) + 1
	offset = offset + (offset % 2)

	local formatstr = "%0"..tostring(offset).."x : %-"..tostring(linemax * 3).."s : %s"

	for c in string.gmatch(tostring(stuff), ".") do
		buffer = buffer..string.format("%02X ",string.byte(c))
		-- using string.gsub(c,"%c",".") didn't work in Hydra, but I didn't dig any deeper -- this works.
		if string.byte(c) < 32 or string.byte(c) > 126 then
		    ascii = ascii.."."
		else
		    ascii = ascii..c
		end
		count = count + 1
		if count % linemax == 0 then
			rb = rb .. string.format(formatstr, count - linemax, buffer, ascii) .. "\n"
			buffer=""
			ascii=""
		end
	end
	if count % linemax ~= 0 then
		rb = rb .. string.format(formatstr, count - (count % linemax), buffer, ascii) .. "\n"
	end
	return rb
end

--- {PATH}.{MODULE}.split(div, string) -> { ... }
--- Function
--- Convert string to an array of strings, breaking at the specified divider(s), similar to "split" in Perl.
module.split = function(div,str)
    if (div=='') then return { str } end
    local pos,arr = 0,{}
    for st,sp in function() return string.find(str,div,pos) end do
        table.insert(arr,string.sub(str,pos,st-1))
        pos = sp + 1
    end
    if string.sub(str,pos) ~= "" then
        table.insert(arr,string.sub(str,pos))
    end
    return arr
end

--- {PATH}.{MODULE}.sortedKeys(table[ , function]) -> function
--- Function
--- Iterator for getting keys from a table in a sorted order. Provide function 'f' as per _Programming_In_Lua,_3rd_ed_, page 52; otherwise order is ascii order ascending. (e.g. `function(m,n) return not (m < n) end` would result in reverse order.
---
--- Similar to Perl's sort(keys %hash).  Use like this: `for i,v in {PATH}.{MODULE}.sortedKeys(t[, f]) do ... end`
module.sortedKeys = function(t, f)
    if t then
        local a = {}
        for n in pairs(t) do table.insert(a, n) end
            table.sort(a, f)
            local i = 0      -- iterator variable
            local iter = function ()   -- iterator function
            i = i + 1
            if a[i] == nil then return nil
                else return a[i], t[a[i]]
            end
        end
        return iter
    else
        return function() return nil end
    end
end

--- {PATH}.{MODULE}.mtTools[...]
--- Variable
--- An array containing useful functions for metatables in a single location for reuse.  Use as `setmetatable(myTable, { __index = {PATH}.{MODULE}.mtTools })`
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

--- {PATH}.{MODULE}.asciiOnly(string[, all]) -> string
--- Function
--- Returns the provided string with all non-printable ascii characters (except for Return, Linefeed, and Tab unless `all` is provided and is true) escaped as \x## so that it can be safely printed in the {TARGET} console, rather than result in an uninformative '(null)'.  Note that this will break up Unicode characters into their individual bytes.
function module.asciiOnly(theString, all)
    local all = all or false
    if all then
        return (theString:gsub("[\x00-\x1f\x7f-\xff]",function(a)
                return string.format("\\x%02X",string.byte(a))
            end))
    else
        return (theString:gsub("[\x00-\x08\x0b\x0c\x0e-\x1f\x7f-\xff]",function(a)
                return string.format("\\x%02X",string.byte(a))
            end))
    end
end

--- {PATH}.{MODULE}.fnutils_every(table, fn) -> bool
--- Function
--- Returns true if the application of fn on every entry in table is truthy.
function module.fnutils_every(table, fn)
    for k, v in pairs(table) do
        if not fn(v, k) then return false end
    end
    return true
end

--- {PATH}.{MODULE}.fnutils_some(table, fn) -> bool
--- Function
--- Returns true if the application of fn on entries in table are truthy for at least one of the members.
function module.fnutils_some(table, fn)
    local function is_invalid(v, k)
        return not fn(v, k)
    end
    return not module.fnutils_every(table, is_invalid)
end

--- {PATH}.{MODULE}.exec(command[, with_user_env]) -> output, status, type, rc
--- Function
--- Runs a shell command and returns stdout as a string (may include a trailing newline), followed by true or nil indicating if the command completed successfully, the exit type ("exit" or "signal"), and the result code.
---
---  If `with_user_env` is `true`, then invoke the user's default shell as an interactive login shell in which to execute the provided command in order to make sure their setup files are properly evaluated so extra path and environment variables can be set.  This is not done, if `with_user_env` is `false` or not provided, as it does add some overhead and is not always strictly necessary.
module.exec = function(command, user_env)
    local f
    if user_env then
        f = io.popen(os.getenv("SHELL").." -l -i -c \""..command.."\"", 'r')
    else
        f = io.popen(command, 'r')
    end
    local s = f:read('*a')
    local status, exit_type, rc = f:close()
    return s, status, exit_type, rc
end

--- {PATH}.{MODULE}.restart()
--- Function
--- Completely restart {TARGET} by actually quitting the application and then reopening it.  Default pause to allow for a complete shutdown of {TARGET}  is 2 seconds, but you can adjust this by using the `settings` module to set "_asm.sleepCount" to your desired wait time.
module.restart = function()
    sleepCount = ((mjolnir and require("mjolnir._asm.settings")) or (hs and require("hs.settings"))).get("_asm.restartSleep") or 2
    os.execute("(sleep "..sleepCount.." ; open -a "..module._paths.bundlePath..") &")
    {BASE}._exit("What is this argument for?",true)
end

--- {PATH}.{MODULE}.versionCompare(v1, v2) -> bool
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

-- Return Module Object --------------------------------------------------

return module
