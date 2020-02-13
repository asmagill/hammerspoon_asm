--- === hs.text ===
---
--- Stuff about the module

local USERDATA_TAG = "hs.text"
local module       = require(USERDATA_TAG..".internal")
-- module.utf16       = require(USERDATA_TAG..".utf16")
-- module.http        = require(USERDATA_TAG..".http")

local textMT  = hs.getObjectMetatable(USERDATA_TAG)
local utf16MT = hs.getObjectMetatable(USERDATA_TAG..".utf16")

-- local log = require("hs.logger").new(USERDATA_TAG, require"hs.settings".get(USERDATA_TAG .. ".logLevel") or "warning")

require("hs.http") -- load some conversion functions that may be useful with hs.text.http, not certain yet

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

textMT.tostring = function(self, ...)
    return self:asEncoding(module.encodingTypes.UTF8, ...):rawData()
end

textMT.toUTF16 = function(self, ...)
    return module.utf16.new(self, ...)
end

-- string.byte (s [, i [, j]])
--
-- Returns the internal numeric codes of the characters s[i], s[i+1], ..., s[j]. The default value for i is 1; the default value for j is i. These indices are corrected following the same rules of function string.sub.
-- Numeric codes are not necessarily portable across platforms.
textMT.byte = function(self, ...)
    return self:rawData():byte(...)
end

-- string.gmatch (s, pattern)
--
-- Returns an iterator function that, each time it is called, returns the next captures from pattern (see §6.4.1) over the string s. If pattern specifies no captures, then the whole match is produced in each call.
-- As an example, the following loop will iterate over all the words from string s, printing one per line:
--
--      s = "hello world from Lua"
--      for w in string.gmatch(s, "%a+") do
--        print(w)
--      end
-- The next example collects all pairs key=value from the given string into a table:
--
--      t = {}
--      s = "from=world, to=Lua"
--      for k, v in string.gmatch(s, "(%w+)=(%w+)") do
--        t[k] = v
--      end
-- For this function, a caret '^' at the start of a pattern does not work as an anchor, as this would prevent the iteration.
utf16MT.gmatch = function(self, pattern)
    local pos, selfCopy = 1, self:copy()
    return function()
        local results = table.pack(selfCopy:find(pattern, pos))
        if results.n < 2 then return end
        pos = results[2] + 1
        if results.n == 2 then
            return selfCopy:sub(results[1], results[2])
        else
            table.remove(results, 1)
            table.remove(results, 1)
            return table.unpack(results)
        end
    end
end

-- utf8.codes (s)
--
-- Returns values so that the construction
--
--      for p, c in utf8.codes(s) do body end
-- will iterate over all characters in string s, with p being the position (in bytes) and c the code point of each character. It raises an error if it meets any invalid byte sequence.
utf16MT.codes = function(self)
    return function(iterSelf, index)
        if index > 0 and module.utf16.isHighSurrogate(iterSelf:unitCharacter(index)) then
            index = index + 2
        else
            index = index + 1
        end
        if index > #iterSelf then
            return nil
        else
            return index, iterSelf:codepoint(index)
        end
    end, self, 0
end

utf16MT.composedCharacters = function(self)
    return function(iterSelf, index)
        if index > 0 then
            local i, j = iterSelf:composedCharacterRange(index)
            index = j
        end
        index = index + 1
        if index > #iterSelf then
            return nil
        else
            local i, j = iterSelf:composedCharacterRange(index)
            return index, j
        end
    end, self, 0
end

utf16MT.compare = function(self, ...)
    local args = table.pack(...)
    if args.n > 1 and type(args[2]) == "table" then
        local options = 0
        for _,v in ipairs(args[2]) do
            if type(v) == "number" then
                options = options | v
            elseif type(v) == "string" then
                local value = module.utf16.compareOptions[v]
                if value then
                    options = options | value
                else
                    error("expected integer or string from hs.utf16.compareOptions in argument 2 table", 2)
                end
            else
                error("expected integer or string from hs.utf16.compareOptions in argument 2 table", 2)
            end
        end
        args[2] = options
    end
    return self:_compare(table.unpack(args))
end

module.encodingTypes           = ls.makeConstantsTable(module.encodingTypes)

--- hs.text.http.get(url, headers) -> int, string, table
--- Function
--- Sends an HTTP GET request to a URL
---
--- Parameters
---  * url - A string containing the URL to retrieve
---  * headers - A table containing string keys and values representing the request headers, or nil to add no headers
---
--- Returns:
---  * A number containing the HTTP response status
---  * A string containing the response body
---  * A table containing the response headers
---
--- Notes:
---  * If authentication is required in order to download the request, the required credentials must be specified as part of the URL (e.g. "http://user:password@host.com/"). If authentication fails, or credentials are missing, the connection will attempt to continue without credentials.
---
---  * This function is synchronous and will therefore block all other Lua execution while the request is in progress, you are encouraged to use the asynchronous functions
---  * If you attempt to connect to a local Hammerspoon server created with `hs.httpserver`, then Hammerspoon will block until the connection times out (60 seconds), return a failed result due to the timeout, and then the `hs.httpserver` callback function will be invoked (so any side effects of the function will occur, but it's results will be lost).  Use [hs.text.http.asyncGet](#asyncGet) to avoid this.
module.http.get = function(url, headers)
    return module.http.doRequest(url, "GET", nil, headers)
end

--- hs.text.http.post(url, data, headers) -> int, string, table
--- Function
--- Sends an HTTP POST request to a URL
---
--- Parameters
---  * url - A string containing the URL to submit to
---  * data - A string containing the request body, or nil to send no body
---  * headers - A table containing string keys and values representing the request headers, or nil to add no headers
---
--- Returns:
---  * A number containing the HTTP response status
---  * A string containing the response body
---  * A table containing the response headers
---
--- Notes:
---  * If authentication is required in order to download the request, the required credentials must be specified as part of the URL (e.g. "http://user:password@host.com/"). If authentication fails, or credentials are missing, the connection will attempt to continue without credentials.
---
---  * This function is synchronous and will therefore block all other Lua execution while the request is in progress, you are encouraged to use the asynchronous functions
---  * If you attempt to connect to a local Hammerspoon server created with `hs.httpserver`, then Hammerspoon will block until the connection times out (60 seconds), return a failed result due to the timeout, and then the `hs.httpserver` callback function will be invoked (so any side effects of the function will occur, but it's results will be lost).  Use [hs.text.http.asyncPost](#asyncPost) to avoid this.
module.http.post = function(url, data, headers)
    return module.http.doRequest(url, "POST", data,headers)
end

--- hs.text.http.asyncGet(url, headers, callback)
--- Function
--- Sends an HTTP GET request asynchronously
---
--- Parameters:
---  * url - A string containing the URL to retrieve
---  * headers - A table containing string keys and values representing the request headers, or nil to add no headers
---  * callback - A function to be called when the request succeeds or fails. The function will be passed three parameters:
---   * A number containing the HTTP response status
---   * A string containing the response body
---   * A table containing the response headers
---
--- Notes:
---  * If authentication is required in order to download the request, the required credentials must be specified as part of the URL (e.g. "http://user:password@host.com/"). If authentication fails, or credentials are missing, the connection will attempt to continue without credentials.
---
---  * If the request fails, the callback function's first parameter will be negative and the second parameter will contain an error message. The third parameter will be nil
module.http.asyncGet = function(url, headers, callback)
    module.http.doAsyncRequest(url, "GET", nil, headers, callback)
end

--- hs.text.http.asyncPost(url, data, headers, callback)
--- Function
--- Sends an HTTP POST request asynchronously
---
--- Parameters:
---  * url - A string containing the URL to submit to
---  * data - A string containing the request body, or nil to send no body
---  * headers - A table containing string keys and values representing the request headers, or nil to add no headers
---  * callback - A function to be called when the request succeeds or fails. The function will be passed three parameters:
---   * A number containing the HTTP response status
---   * A string containing the response body
---   * A table containing the response headers
---
--- Notes:
---  * If authentication is required in order to download the request, the required credentials must be specified as part of the URL (e.g. "http://user:password@host.com/"). If authentication fails, or credentials are missing, the connection will attempt to continue without credentials.
---
---  * If the request fails, the callback function's first parameter will be negative and the second parameter will contain an error message. The third parameter will be nil
module.http.asyncPost = function(url, data, headers, callback)
    module.http.doAsyncRequest(url, "POST", data, headers, callback)
end

module.utf16.builtinTransforms = ls.makeConstantsTable(module.utf16.builtinTransforms)
module.utf16.compareOptions    = ls.makeConstantsTable(module.utf16.compareOptions)

-- Return Module Object --------------------------------------------------

return module
