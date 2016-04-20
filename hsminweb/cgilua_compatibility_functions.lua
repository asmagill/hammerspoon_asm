--- === hs._asm.hsminweb.cgilua ===
---
--- This file contains functions which attempt to mimic as closely as possible the functions available to lua template files in the CGILua module provided by the Kepler Project at http://keplerproject.github.io/cgilua/index.html
---
--- Because of the close integration with Hammerspoon and the hs._asm.hsminweb module that I am attempting to provide with this, I decided that it was easier to "replicate" the functionality of some of the CGILua functions, rather than attempt to bridge the differences between how CGILua and Hammerspoon/this module handle their implementation of the HTTP protocol.
---
--- I may revisit the idea of using CGILua more directly in the future.  In the meantime, the goal of this file is to provide most of the same functionality that CGILua does to template files. Any differences in the results or errors are most likely due to my code and you should direct all error reports or code change suggestions to the hs._asm.hsminweb github repository at https://github.com/asmagill/hammerspoon_asm, rather than the Kepler Project.
---
--- #### Style Note:
---
--- If you compare this to the actual CGILua code, you'll see that even when I've copied a function almost exactly, I've un-done the optimizations where functions in the global scope are stored as local variables.
---
--- I favor readability over performance.  If I were coding on an embedded system (I have, but not in Lua), I would probably care about this more; but Hammerspoon runs on fairly modern Macintosh computers. I did a little digging and came across this, although their testing was done on an iPhone: http://www.ludicroussoftware.com/blog/2011/11/01/local-v--table-functions/
---
--- Now I'm not saying that this sort of optimization isn't useful in the right places, but for a few ms, I'd rather spend my time looking at readable code, rather than try to remember without looking it up if `_open` is something I assigned or is it really `io.open`... or is `unpack` shorthand for `table.unpack` or `string.unpack`?

-- Per the CGILua license at http://keplerproject.github.io/cgilua/license.html, portions of this file may be covered under the following license:
--
-- Copyright © 2003 Kepler Project.
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--

local cgilua = {}

--- hs._asm.hsminweb.cgilua.print(...) -> nil
--- Function
--- Appends the given arguments to the response body.
---
--- Parameters:
---  * ... - a list of comma separated arguments to add to the response body
---
--- Returns:
---  * None
---
--- Notes:
---  * Available within a lua template file as `cgilua.print`
---  * This function works like the lua builtin `print` command in that it converts all its arguments to strings, separates them with tabs (`\t`), and ends the line with a newline (`\n`) before appending them to the current response body.
cgilua.print = function(_parent, ...)
    local args = { ... }
    for i = 1, select("#",...) do
        args[i] = tostring(args[i])
    end
    _parent.response.body = _parent.response.body .. table.concat(args, "\t") .. "\n"
end

--- hs._asm.hsminweb.cgilua.put(...) -> nil
--- Function
--- Appends the given arguments to the response body.
---
--- Parameters:
---  * ... - a list of comma separated arguments to add to the response body
---
--- Returns:
---  * None
---
--- Notes:
---  * Available within a lua template file as `cgilua.put`
---  * This function works by flattening tables and converting all values except for `nil` and `false` to their string representation and then appending them in order to the response body. Unlike `cgilua.print`, it does not separate values with a tab character or terminate the line with a newline character.
cgilua.put = function(_parent, ...)
    for _, s in ipairs{ ... } do
        if type(s) == "table" then
            cgilua.put(_parent, table.unpack(s))
        elseif s then
            _parent.response.body = _parent.response.body .. tostring(s)
        end
    end
end

--- hs._asm.hsminweb.cgilua.errorlog(msg) -> nil
--- Function
--- Sends the message to the `hs._asm.hsminweb` log, tagged as an error.
---
--- Parameters:
---  * msg - the message to send to the module's error log
---
--- Returns:
---  * None
---
--- Notes:
---  * Available within a lua template file as `cgilua.errorlog`
---  * By default, messages logged with this method will appear in the Hammerspoon console and are available in the `hs.logger` history.
cgilua.errorlog = function(_parent, string) _parent.log.e(string) end


--- hs._asm.hsminweb.cgilua.tmp_path
--- Variable
--- The directory used by `cgilua.tmpfile`
---
--- This variable contains the location where temporary files should be created.  Defaults to the user's temporary directory as returned by `hs.fs.temporaryDirectory`.
cgilua.tmp_path = require"hs.fs".temporaryDirectory():match("^(.*)/")

--- hs._asm.hsminweb.cgilua.tmpname() -> string
--- Function
--- Returns a temporary file name used by `cgilua.tmpfile`.
---
--- Parameters:
---  * None
---
--- Returns:
---  * a temporary filename, without the path.
---
--- Notes:
---  * This function uses `hs.host.globallyUniqueString` to generate a unique file name.
cgilua.tmpname = function()
    return "lua_" .. require"hs.host".globallyUniqueString()
end


--- hs._asm.hsminweb.cgilua.tmpfile([dir], [namefunction]) -> file[, err]
--- Function
--- Returns the file handle to a temporary file for writing, or nil and an error message if the file could not be created for any reason.
---
--- Parameters:
---  * dir          - the system directory where the temporary file should be created.  Defaults to `cgilua.tmp_path`.
---  * namefunction - an optional function used to generate unique file names for use as temporary files.  Defaults to `cgilua.tmpname`.
---
--- Returns:
---  * the created file's handle or nil and an error message if the file could not be created.
---
--- Notes:
---  * The file is automatically deleted when the HTTP request has been completed, so if you need for the data to persist, make sure to `io.flush` or `io.close` the file handle yourself and copy the file to a more permanent location.
cgilua.tmpfile = function(_parent, dir, namefunction)
    dir = dir or cgilua.tmp_path
    namefunction = namefunction or cgilua.tmpname
    local tempname = namefunction()
    local filename = dir.."/"..tempname
    local file, err = io.open(filename, "w+b")
    if file then
        table.insert(_parent._tmpfiles, {name = filename, file = file})
    end
    return file, err
end

--- hs._asm.hsminweb.cgilua.servervariable(varname) -> string
--- Function
--- Returns a string with the value of the CGI environment variable correspoding to varname.
---
--- Parameters:
---  * varname - the name of the CGI variable to get the value of.
---
--- Returns:
---  * the value of the CGI variable as a string, or nil if no such variable exists.
---
--- Notes:
---  * CGI Variables include server defined values commonly shared with CGI scripts and the HTTP request headers from the web request.  The server variables include the following (note that depending upon the request and type of resource the URL refers to, not all values may exist for every request):
---    * "AUTH_TYPE"         - If the server supports user authentication, and the script is protected, this is the protocol-specific authentication method used to validate the user.
---    * "CONTENT_LENGTH"    - The length of the content itself as given by the client.
---    * "CONTENT_TYPE"      - For queries which have attached information, such as HTTP POST and PUT, this is the content type of the data.
---    * "DOCUMENT_ROOT"     - the real directory on the server that corresponds to a DOCUMENT_URI of "/".  This is the first directory which contains files or sub-directories which are served by the web server.
---    * "DOCUMENT_URI"      - the path portion of the HTTP URL requested
---    * "GATEWAY_INTERFACE" - The revision of the CGI specification to which this server complies. Format: CGI/revision
---    * "PATH_INFO"         - The extra path information, as given by the client. In other words, scripts can be accessed by their virtual pathname, followed by extra information at the end of this path. The extra information is sent as PATH_INFO. This information should be decoded by the server if it comes from a URL before it is passed to the CGI script.
---    * "PATH_TRANSLATED"   - The server provides a translated version of PATH_INFO, which takes the path and does any virtual-to-physical mapping to it.
---    * "QUERY_STRING"      - The information which follows the "?" in the URL which referenced this script. This is the query information. It should not be decoded in any fashion. This variable should always be set when there is query information, regardless of command line decoding.
---    * "REMOTE_ADDR"       - The IP address of the remote host making the request.
---    * "REMOTE_HOST"       - The hostname making the request. If the server does not have this information, it should set REMOTE_ADDR and leave this unset.
---    * "REMOTE_IDENT"      - If the HTTP server supports RFC 931 identification, then this variable will be set to the remote user name retrieved from the server. Usage of this variable should be limited to logging only.
---    * "REMOTE_USER"       - If the server supports user authentication, and the script is protected, this is the username they have authenticated as.
---    * "REQUEST_METHOD"    - The method with which the request was made. For HTTP, this is "GET", "HEAD", "POST", etc.
---    * "REQUEST_TIME"      - the time the server received the request represented as the number of seconds since 00:00:00 UTC on 1 January 1970.  Usable with `os.date` to provide the date and time in whatever format you require.
---    * "REQUEST_URI"       - the DOCUMENT_URI with any query string present in the request appended.  Usually this corresponds to the URL without the scheme or host information.
---    * "SCRIPT_FILENAME"   - the actual path to the script being executed.
---    * "SCRIPT_NAME"       - A virtual path to the script being executed, used for self-referencing URLs.
---    * "SERVER_NAME"       - The server's hostname, DNS alias, or IP address as it would appear in self-referencing URLs.
---    * "SERVER_PORT"       - The port number to which the request was sent.
---    * "SERVER_PROTOCOL"   - The name and revision of the information protcol this request came in with. Format: protocol/revision
---    * "SERVER_SOFTWARE"   - The name and version of the web server software answering the request (and running the gateway). Format: name/version
---
--- * The HTTP Request header names are prefixed with "HTTP_", converted to all uppercase, and have all hyphens converted into underscores.  Common headers (converted to their CGI format) might include, but are not limited to:
---    * HTTP_ACCEPT, HTTP_ACCEPT_ENCODING, HTTP_ACCEPT_LANGUAGE, HTTP_CACHE_CONTROL, HTTP_CONNECTION, HTTP_DNT, HTTP_HOST, HTTP_USER_AGENT
---  * This server also defines the following (which are replicated in the CGI variables above, so those should be used for portability):
---    * HTTP_X_REMOTE_ADDR, HTTP_X_REMOTE_PORT, HTTP_X_SERVER_ADDR, HTTP_X_SERVER_PORT
---  * A list of common request headers and their definitions can be found at https://en.wikipedia.org/wiki/List_of_HTTP_header_fields
cgilua.servervariable = function(_parent, varname)
    return _parent.CGIVariables[varname]
end

--- hs._asm.hsminweb.cgilua.splitonlast(path) -> directory, file
--- Function
--- Returns two strings with the "directory path" and "file" parts of the given path string splitted on the last separator ("/" or "\").
---
--- Parameters:
---  * path - the path to split
---
--- Returns:
---  * the directory path, the file
---
--- Notes:
---  * This function used to be called cgilua.splitpath and still can be accessed by this name for compatibility reasons. cgilua.splitpath may be deprecated in future versions.
cgilua.splitonlast  = function(_parent, path) return match(path,"^(.-)([^:/\\]*)$") end
cgilua.splitpath    = cgilua.splitonlast -- compatibility with previous versions

--- hs._asm.hsminweb.cgilua.splitfirst(path) -> path component, path remainder
--- Function
--- Returns two strings with the "first directory" and the "remaining paht" of the given path string splitted on the first separator ("/" or "\").
---
--- Parameters:
---  * path - the path to split
---
--- Returns:
---  * the first directory component, the remainder of the path
cgilua.splitonfirst = function(_parent, path) return match(path, "^/([^:/\\]*)(.*)") end

--- hs._asm.hsminweb.cgilua.script_path
--- Variable
--- The system path of the running script. Equivalent to the CGI environment variable SCRIPT_FILENAME.
---
--- Notes:
---  * CGILua supports being invoked through a URL that amounts to set of chained paths and script names; this is not necessary for this module, so these variables may differ somewhat from a true CGILua installation; the intent of the variable has been maintained as closely as I can determine at present.  If this changes, so will this documentation.

--- hs._asm.hsminweb.cgilua.script_file
--- Variable
--- The file name of the running script. Obtained from cgilua.script_path.
---
--- Notes:
---  * CGILua supports being invoked through a URL that amounts to set of chained paths and script names; this is not necessary for this module, so these variables may differ somewhat from a true CGILua installation; the intent of the variable has been maintained as closely as I can determine at present.  If this changes, so will this documentation.

--- hs._asm.hsminweb.cgilua.script_pdir
--- Variable
--- The directory of the running script. Obtained from cgilua.script_path.
---
--- Notes:
---  * CGILua supports being invoked through a URL that amounts to set of chained paths and script names; this is not necessary for this module, so these variables may differ somewhat from a true CGILua installation; the intent of the variable has been maintained as closely as I can determine at present.  If this changes, so will this documentation.

--- hs._asm.hsminweb.cgilua.script_vpath
--- Variable
--- Equivalent to the CGI environment variable PATH_INFO or "/", if no PATH_INFO is set.
---
--- Notes:
---  * CGILua supports being invoked through a URL that amounts to set of chained paths and script names; this is not necessary for this module, so these variables may differ somewhat from a true CGILua installation; the intent of the variable has been maintained as closely as I can determine at present.  If this changes, so will this documentation.

--- hs._asm.hsminweb.cgilua.script_vdir
--- Variable
--- If PATH_INFO represents a directory (i.e. ends with "/"), then this is equal to `cgilua.script_vpath`.  Otherwise, this contains the directory portion of `cgilua.script_vpath`.
---
--- Notes:
---  * CGILua supports being invoked through a URL that amounts to set of chained paths and script names; this is not necessary for this module, so these variables may differ somewhat from a true CGILua installation; the intent of the variable has been maintained as closely as I can determine at present.  If this changes, so will this documentation.

--- hs._asm.hsminweb.cgilua.urlpath
--- Variable
--- The name of the script as requested in the URL. Equivalent to the CGI environment variable SCRIPT_NAME.
---
--- Notes:
---  * CGILua supports being invoked through a URL that amounts to set of chained paths and script names; this is not necessary for this module, so these variables may differ somewhat from a true CGILua installation; the intent of the variable has been maintained as closely as I can determine at present.  If this changes, so will this documentation.


--- hs._asm.hsminweb.cgilua.doscript(filename) -> results
--- Function
--- Executes a lua file (given by filepath).
---
--- Parameters:
---  * filepath - the file to interpret as Lua code
---
--- Returns:
---  * the values returned by the execution, or nil followed by an error message if the file does not exists.
---
--- Notes:
---  * If the file does not exist, an Internal Server error is returned to the client and an error is logged to the Hammerspoon console.
---  * During the processing of the web request, the local directory is temporarily changed to match the local directory of the path of the file being served, as determined by the URL of the request.  This is usually different than the Hammerspoon default directory which corresponds to the directory which contains the `init.lua` file for Hammerspoon.
cgilua.doscript = function(_parent, filename)
    local f, err = loadfile(filename, "bt", _parent.cgiluaENV)
    if not f then
        error(string.format("Cannot execute '%s'. Exiting.\n%s", filename, err), 3)
    else
        local results = { xpcall(f, _parent.cgiluaENV.cgilua._errorhandler) }
        local ok = table.remove(results, 1)
        if ok then
            if #results == 0 then results = { true } end
            return table.unpack(results)
        else
            error(table.unpack(results), 3)
        end
    end
end

--- hs._asm.hsminweb.cgilua.doif(filename) -> results
--- Function
--- Executes a lua file (given by filepath) if it exists.
---
--- Parameters:
---  * filepath - the file to interpret as Lua code
---
--- Returns:
---  * the values returned by the execution, or nil followed by an error message if the file does not exists.
---
--- Notes:
---  * This function only interprets the file if it exists; if the file does not exist, it returns an error to the calling code (not the web client)
---  * During the processing of the web request, the local directory is temporarily changed to match the local directory of the path of the file being served, as determined by the URL of the request.  This is usually different than the Hammerspoon default directory which corresponds to the directory which contains the `init.lua` file for Hammerspoon.
cgilua.doif = function(_parent, filename)
        if not filename then return end    -- no file
        local f, err = io.open(filename)
        if not f then return nil, err end    -- no file (or unreadable file)
        f:close()
        return cgilua.doscript(_parent, filename)
end

--- hs._asm.hsminweb.cgilua.contentheader(maintype, subtype) -> none
--- Function
--- Sets the HTTP response type for the content being generated to maintype/subtype.
---
--- Parameters:
---  * maintype - the primary content type (e.g. "text")
---  * subtype  - the sub-type for the content (e.g. "plain")
---
--- Returns:
---  * None
---
--- Notes:
---  * This sets the `Content-Type` header field for the HTTP response being generated.  This will override any previous setting, including the default of "text/html".
cgilua.contentheader = function(_parent, mainType, subType)
    _parent.response.headers["Content-Type"] = tostring(mainType) .. "/" .. tostring(subType)
end

--- hs._asm.hsminweb.cgilua.htmlheader() -> none
--- Function
--- Sets the HTTP response type to "text/html"
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * This sets the `Content-Type` header field for the HTTP response being generated to "text/html".  This is the default value, so generally you should not need to call this function unless you have previously changed it with the [cgilua.contentheader](#contentheader) function.
cgilua.htmlheader = function(_parent)
    _parent.response.headers["Content-Type"] = "text/html"
end

--- hs._asm.hsminweb.cgilua.header(key, value) -> none
--- Function
--- Sets the HTTP response header `key` to `value`
---
--- Parameters:
---  * key - the HTTP response header to set a value to.  This should be a string.
---  * value - the value for the header.  This should be a string or a value representable as a string.
---
--- Returns:
---  * None
---
--- Notes:
---  * You should not use this function to set the value for the "Content-Type" key; instead use [cgilua.contentheader](#contentheader) or [cgilua.htmlheader](#htmlheader).
cgilua.header = function(_parent, key, value)
     _parent.response.headers[key] = value
end

--- hs._asm.hsminweb.cgilua.redirect(url, [args]) -> none
--- Function
--- Sends the headers to force a redirection to the given URL adding the parameters in table args to the new URL.
---
--- Parameters:
---  * url
---  * args
---
--- Returns:
---  * None
---
--- Notes:
---  * This function should generally be followed by a `return` in your lua template page as no additional processing or output should occur when a request is to be redirected.
The first argument (url) is the URL the browser should be redirected to; the second one (args) is an optional table which could have pairs name = value that will be encoded to form a valid URL (see function cgilua.urlcode.encodetable).
Returns nothing.
cgilua.redirect = function(_parent, url, args)
    if not url:find("^https?:") then
        if url:find("^/") then
            url = _parent.CGIVariables.REQUEST_SCHEME .. "://" .. _parent.CGIVariables.HTTP_HOST .. url
        else
            url = _parent.CGIVariables.REQUEST_SCHEME .. "://" .. _parent.CGIVariables.HTTP_HOST .. "/" .. table.concat(_parent.request.headers._.pathParts.pathComponents, "/", 2, #_parent.request.headers._.pathParts.pathComponents - 1) .. url
        end
    end
    local params = ""
    if args then
        params = "?" .. cgilua.urlcode.encodetable(_parent, args)
    end
    _parent.response.code = 307
    _parent.response.headers["Location"] = url .. params
end

cgilua.mkabsoluteurl = function(_parent, path, protocol)
    protocol = protocol or "http"
    if path:sub(1,1) ~= '/' then
        path = '/'..path
    end
    return string.format("%s://%s:%s%s",
        protocol,
        _parent.CGIVariables.SERVER_NAME,
        _parent.CGIVariables.SERVER_PORT,
        path)
end

cgilua.mkurlpath = function(_parent, script, args)
    local params = ""
    if args then
        params = "?" .. cgilua.urlcode.encodetable(_parent, args)
    end
    local urldir = _parent.cgiluaENV.cgilua.urlpath:match("^(.-)[^:/\\]*$")
    if script:sub(1,1) == '/' or urldir == '/' then
        return script .. params
    else
        return urldir .. script .. params
    end
end


cgilua.urlcode = {}

cgilua.urlcode.escape = function(_parent, str)
    return (str:gsub("\n", "\r\n"):gsub("([^0-9a-zA-Z ])", function(_) return string.format("%%%02X", string.byte(_)) end):gsub(" ", "+"))
end

cgilua.urlcode.unescape = function(_parent, str)
    return (str:gsub("+", " "):gsub("%%(%x%x)", function(_) return string.char(tonumber(_, 16)) end):gsub("\r\n", "\n"))
end

cgilua.urlcode.encodetable = function(_parent, args)
    if args == nil or next(args) == nil then return "" end
    local results = {}
    for k, v in pairs(args) do
        if type(v) ~= "table" then v = { v } end
        for _, v2 in ipairs(v) do
            table.insert(results, cgilua.urlcode.escape(_parent, k) .. "=" .. cgilua.urlcode.escape(_parent, v2))
        end
    end
    return table.concat(results, "&")
end

cgilua.urlcode.insertfield = function(_parent, args, name, value)
    if not args[name] then
        args[name] = value
    else
        local t = type(args[name])
        if t ~= "table" then
            args[name] = {
              args[name],
              value,
            }
        else
            table.insert(args[name], value)
        end
    end
end

cgilua.urlcode.parsequery = function(_parent, query, args)
    if type(query) == "string" then
        query:gsub("([^&=]+)=([^&=]*)&?",
            function(key, val)
                cgilua.urlcode.insertfield(_parent, args, cgilua.urlcode.unescape(_parent, key), cgilua.urlcode.unescape(_parent, val))
            end)
    end
end

local out = function(s, i, f)
    if type(s) ~= "string" then s = tostring(s) end
    s = s:sub(i, f or -1)
    if s == "" then return s end
    -- we could use `%q' here, but this way we have better control
    s = s:gsub("([\\\n\'])", "\\%1")
    -- substitute '\r' by '\'+'r' and let `loadstring' reconstruct it
    s = s:gsub("\r", "\\r")
    return string.format(" %s('%s'); ", "cgilua.put", s)
end

cgilua.lp = {}

cgilua.lp.translate = function(_parent, source)
    -- in an effort to attempt to maintain compatibility with CGILua, we should expect/allow the same things in a source file...
    source = source:gsub("^#![^\n]+\n", "")

    -- compatibility with earlier versions...
    -- translates $| lua-var |$
    source = source:gsub("$|(.-)|%$", "<?lua = %1 ?>")
    -- translates <!--$$ lua-code $$-->
    source = source:gsub("<!%-%-$$(.-)$$%-%->", "<?lua %1 ?>")
    -- translates <% lua-code %>
    source = source:gsub("<%%(.-)%%>", "<?lua %1 ?>")

    local res = {}
    local start = 1   -- start of untranslated part in `s'
    while true do
        local ip, fp, target, exp, code = source:find("<%?(%w*)[ \t]*(=?)(.-)%?>", start)
        if not ip then break end
        table.insert(res, out(source, start, ip-1))
        if target ~= "" and target ~= "lua" then
            -- not for Lua; pass whole instruction to the output
            table.insert(res, out(source, ip, fp))
        else
            if exp == "=" then   -- expression?
                table.insert(res, string.format(" %s(%s);", "cgilua.put", code))
            else  -- command
                table.insert(res, string.format(" %s ", code))
            end
        end
        start = fp + 1
    end
    table.insert(res, out(source, start))
    return table.concat(res)
end

cgilua.lp.compile = function(_parent, string, chunkname, env)
    local s = _parent.translations[string]
    if not s then
          s = cgilua.lp.translate(_parent, string)
          _parent.translations[string] = s
    end
    local f, err = load(s, chunkname, "bt", env or _parent.cgiluaENV)
    if not f then error(err, 3) end
    return f
end

cgilua.lp.include = function(_parent, filename, env)
    -- read the whole contents of the file
    local fh = assert(io.open(filename))
    local src = fh:read("a")
    fh:close()

    if src:sub(1,3) == "\xEF\xBB\xBF" then src = src:sub(4) end
    -- translates the file into a function
    local prog = cgilua.lp.compile(_parent, src, '@'..filename, env or _parent.cgiluaENV)
    prog()
end


--  -      cgilua.redirect (url, args)

--  -      cgilua.mkabsoluteurl (path)
--  -      cgilua.mkurlpath (script [, args])

--  -      cgilua.lp.compile (string)
--  -      cgilua.lp.include (filename[, env])
--  -      cgilua.lp.translate (string)

--  -      cgilua.urlcode.encodetable (table)
--  -      cgilua.urlcode.escape (string)
--  -      cgilua.urlcode.insertfield (args, name, value)
--  -      cgilua.urlcode.parsequery (query, args)
--  -      cgilua.urlcode.unescape (string)

return cgilua