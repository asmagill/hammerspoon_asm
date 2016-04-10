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

-- Candidates for inclusion
--     cgilua.contentheader (type, subtype)
--     cgilua.header (header, value)
--     cgilua.htmlheader ()
--     cgilua.redirect (url, args)

--     cgilua.mkabsoluteurl (path)
--     cgilua.mkurlpath (script [, args])
--     cgilua.script_file
--     cgilua.script_path
--     cgilua.script_pdir
--     cgilua.script_vdir
--     cgilua.script_vpath
--     cgilua.servervariable (varname)
--     cgilua.tmp_path
--     cgilua.urlpath

--     cgilua.urlcode.encodetable (table)
--     cgilua.urlcode.escape (string)
--     cgilua.urlcode.insertfield (args, name, value)
--     cgilua.urlcode.parsequery (query, args)
--     cgilua.urlcode.unescape (string)

--     cgilua.doif (filepath)
--     cgilua.doscript (filepath)
--     cgilua.pack (...)
--     cgilua.splitfirst (path)
--     cgilua.splitonlast (path)
--     cgilua.tmpfile (dir[, namefunction])
--     cgilua.tmpname ()

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