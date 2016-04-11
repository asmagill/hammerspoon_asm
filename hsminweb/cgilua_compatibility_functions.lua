--- === hs._asm.hsminweb.cgilua ===
---
--- This file contains functions which attempt to mimic as closely as possible the functions available to lua template files in the CGILua module provided by the Kepler Project at http://keplerproject.github.io/cgilua/index.html
---
--- Because of the close integration with Hammerspoon and the hs._asm.hsminweb module that I am attempting to provide with this, I decided that it was easier to "replicate" the functionality of some of the CGILua functions, rather than attempt to bridge the differences between how CGILua and Hammerspoon/this module handle their implementation of the HTTP protocol.
---
--- I may revisit the idea of using CGILua more directly in the future.  In the meantime, the goal of this file is to provide most of the same functionality that CGILua does to template files. Any differences in the results or errors are most likely due to my code and you should direct all error reports or code change suggestions to the hs._asm.hsminweb github repository at https://github.com/asmagill/hammerspoon_asm, rather than the Kepler Project.


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
        table.insert(_parent.tmpfiles, {name = filename, file = file})
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
---  * the first directory, the remainder of the path
cgilua.splitonfirst = function(_parent, path) return match(path, "^/([^:/\\]*)(.*)") end

-- Variable's defined per use at runtime, but logically belong within the cgilua submodule for documentation purposes...

--- hs._asm.hsminweb.cgilua.script_path
--- Variable
--- The actual path of the running script. Equivalent to the CGI environment variable SCRIPT_FILENAME.
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





-- Candidates being considered for inclusion
--     cgilua.contentheader (type, subtype)
--     cgilua.header (header, value)
--     cgilua.htmlheader ()
--     cgilua.redirect (url, args)

--     cgilua.lp.include (filename[, env]) (see doif when implementing this)

--     cgilua.mkabsoluteurl (path)
--     cgilua.mkurlpath (script [, args])

--     cgilua.urlcode.encodetable (table)
--     cgilua.urlcode.escape (string)
--     cgilua.urlcode.insertfield (args, name, value)
--     cgilua.urlcode.parsequery (query, args)
--     cgilua.urlcode.unescape (string)

--     cgilua.doif (filepath)
--     cgilua.doscript (filepath)
--     cgilua.pack (...)

--     cgilua.authentication.check (username, passwd)
--     cgilua.authentication.checkURL ()
--     cgilua.authentication.configure (options, methods)
--     cgilua.authentication.logoutURL ()
--     cgilua.authentication.refURL ()
--     cgilua.authentication.username ()

--     cgilua.cookies.get (name)
--     cgilua.cookies.set (name, value[, options])
--     cgilua.cookies.sethtml (name, value[, options])
--     cgilua.cookies.delete (name[, options])

--     cgilua.serialize (table, outfunc[, indent[, prefix]])

--     cgilua.session.close ()
--     cgilua.session.data
--     cgilua.session.delete (id)
--     cgilua.session.destroy ()
--     cgilua.session.load (id)
--     cgilua.session.new ()
--     cgilua.session.open ()
--     cgilua.session.save (id, data)
--     cgilua.session.setsessiondir (path)

return cgilua