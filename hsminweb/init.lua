--- === hs._asm.hsminweb ===
---
--- Minimalist Web Server for Hammerspoon
---
--- Note that his module is in development; not all methods described here are fully functional yet.  Others may change slightly during development, so be aware, if you choose to start using this module, that things may change somewhat before it stabilizes.
---
--- This module aims to be a minimal, but reasonably functional, web server for use within Hammerspoon.  Expanding upon the Hammerspoon module, `hs.httpserver`, this module adds support for serving static pages stored at a specified document root as well as serving dynamic content from user defined functions, lua files interpreted within the Hammerspoon environment, and external executables which support the CGI/1.1 framework.
---
--- This module aims to provide a fully functional, and somewhat extendable, web server foundation, but will never replace a true dedicated web server application.  Some limitations include:
---  * It is single threaded within the Hammerspoon environment and can only serve one resource at a time
---  * As with all Hammerspoon modules, while dynamic content is being generated, Hammerspoon cannot respond to other callback functions -- a complex or time consuming script may block other Hammerspoon activity in a noticeable manner.
---  * All document requests and responses are handled in memory only -- because of this, maximum resource size is limited to what you are willing to allow Hammerspoon to consume and memory limitations of your computer.
---
--- While some of these limitations may be mitigated to an extent in the future with additional modules and additions to `hs.httpserver`, Hammerspoon's web serving capabilities will never replace a dedicated web server when volume or speed is required.

--
-- Planned Features
--
--   [X] object based approach
--   [X] custom error pages
--   [X] functions for methods
--   [X] default page for directory
--   [X] text references to "http://" need to check _ssl status
--   [X] verify read access to file
--   [X] access list/general header check for go ahead?
--   [X] CGI Variables
--   [X] CGI file types, check executable extensions
--   [X] can CGI script change working directory to CGI file's directory?
--   [-] Hammerspoon aware pages (files, functions?)
--       [ ] embedded lua/SSI in regular html? check out http://keplerproject.github.io/cgilua/
--       [ ] Decode query strings
--       [ ] Decode form POST data
--   [ ] Allow adding alternate POST encodings (JSON)
--   [X] add type validation, or at least wrap setters so we can reset internals when they fail
--   [X] documentation
--   [X] proper content-type detection for GET
--
--   [ ] helpers for custom functions/handlers
--       [ ] common headers
--       [ ] function to get CGI-like variables?
--       [ ] query/body parsing like Hammerspoon/cgilua support?
--
--   [ ] common/default response headers? Would simplify error functions...
--   [ ] wrap webServerHandler so we can do SSI?  will need a way to verify text content or specific header check
--
--   [ ] should things like directory index code be a function so it can be overridden?
--       [ ] custom headers/footers? (auto include head/tail files if exist?)
--
--   [ ] support per-dir, in addition to per-server settings?
--
--   [ ] support PATH_INFO?  Not directly supported by hs.http.urlParts (i.e. NSURLComponents), so we'd have to roll our own... see how Apache handles it
--
--   [ ] logging?
--   [ ] additional response headers?
--   [ ] Additional errors to add?
--
--   [ ] basic/digest auth via lua only?
--   [ ] cookie support? other than passing to/from dynamic pages, do we need to do anything?
--
--   [ ] For full WebDav support, some other methods may also require a body
--

local USERDATA_TAG          = "hs._asm.hsminweb"
local VERSION               = "0.0.2"

local DEFAULT_ScriptTimeout = 30
local scriptWrapper         = package.searchpath(USERDATA_TAG, package.path):match("^(/.*/).*%.lua$").."timeout3"

local module     = {}

local httpserver = require("hs.httpserver")
local http       = require("hs.http")
local fs         = require("hs.fs")
local nethost    = require("hs.network.host")
local hshost     = require("hs.host")

local serverAdmin    = os.getenv("USER") .. "@" .. hshost.localizedName()
local serverSoftware = USERDATA_TAG:gsub("^hs%._asm%.", "") .. "/" .. VERSION

local log  = require("hs.logger").new(serverSoftware, "debug")
module.log = log

local HTTPdateFormatString = "!%a, %d %b %Y %T GMT"
local HTTPformattedDate    = function(x) return os.date(HTTPdateFormatString, x or os.time()) end

local shallowCopy = function(t1)
    local t2 = {}
    for k, v in pairs(t1) do t2[k] = v end
    return t2
end

local directoryIndex = {
    "index.html", "index.htm"
}

local cgiExtensions = {
    "cgi", "pl"
}

local errorHandlers = setmetatable({
-- https://en.wikipedia.org/wiki/List_of_HTTP_status_codes
    [403] = function(method, path, headers)
        return "<html><head><title>Forbidden</title><head><body><H1>HTTP/1.1 403 Forbidden</H1><hr/><div align=\"right\"><i>" .. serverSoftware .. " at " .. os.date() .. "</i></div></body></html>", 403, { Server = serverSoftware .. " (OSX)", ["Content-Type"] = "text/html" }
    end,

    [403.2] = function(method, path, headers)
        return "<html><head><title>Read Access is Forbidden</title><head><body><H1>HTTP/1.1 403.2 Read Access is Forbidden</H1><br/>Read access for the requested URL, http" .. (headers._SSL and "s" or "") .. "://" .. headers.Host .. path .. ", is forbidden.<br/><hr/><div align=\"right\"><i>" .. serverSoftware .. " at " .. os.date() .. "</i></div></body></html>", 403, { Server = serverSoftware .. " (OSX)", ["Content-Type"] = "text/html" }
    end,

    [404] = function(method, path, headers)
        return "<html><head><title>Object Not Found</title><head><body><H1>HTTP/1.1 404 Object Not Found</H1><br/>The requested URL, http" .. (headers._SSL and "s" or "") .. "://" .. headers.Host .. path .. ", was not found on this server.<br/><hr/><div align=\"right\"><i>" .. serverSoftware .. " at " .. os.date() .. "</i></div></body></html>", 404, { Server = serverSoftware .. " (OSX)", ["Content-Type"] = "text/html" }
    end,

    [405] = function(method, path, headers)
        return "<html><head><title>Method Not Allowed</title><head><body><H1>HTTP/1.1 405 Method Not Allowed</H1><br/>The requested method, " .. method .. ", is not supported by this server or for the requested URL, http" .. (headers._SSL and "s" or "") .. "://" .. headers.Host .. path .. ".<br/><hr/><div align=\"right\"><i>" .. serverSoftware .. " at " .. os.date() .. "</i></div></body></html>", 405, { Server = serverSoftware .. " (OSX)", ["Content-Type"] = "text/html" }
    end,

    [500] = function(method, path, headers)
        return "<html><head><title>Internal Server Error</title><head><body><H1>HTTP/1.1 500 Internal Server Error</H1><br/>An internal server error occurred.  Check the Hammerspoon console for possible log messages which may contain more details.<br/><hr/><div align=\"right\"><i>" .. serverSoftware .. " at " .. os.date() .. "</i></div></body></html>", 405, { Server = serverSoftware .. " (OSX)", ["Content-Type"] = "text/html" }
    end,

    default = function(code, method, path, headers)
        return "<html><head><title>Internal Server Error</title><head><body><H1>HTTP/1.1 500 Internal Server Error</H1><br/>Error code " .. tostring(code) .. " has no handler<br/><hr/><div align=\"right\"><i>" .. serverSoftware .. " at " .. os.date() .. "</i></div></body></html>", 500, { Server = serverSoftware .. " (OSX)", ["Content-Type"] = "text/html" }
    end,
}, {
    __index = function(_, key)
        return function(...) return _.default(key, ...) end
    end
})

local supportedMethods = {
-- https://en.wikipedia.org/wiki/Hypertext_Transfer_Protocol
    GET       = true,
    HEAD      = true,
    POST      = true,
    PUT       = false,
    DELETE    = false,
    TRACE     = false,
    OPTIONS   = false,
    CONNECT   = false,
    PATCH     = false,
-- https://en.wikipedia.org/wiki/WebDAV
    PROPFIND  = false,
    PROPPATCH = false,
    MKCOL     = false,
    COPY      = false,
    MOVE      = false,
    LOCK      = false,
    UNLOCK    = false,
}

local verifyAccess = function(aclTable, headers)
    local accessGranted = false
    local headerMap = {}
    for k, v in pairs(headers) do headerMap[k:upper()] = k end

    for i, v in ipairs(aclTable) do
        local headerToCheck = v[1]:upper()
        local valueToCheck  = v[2]
        local isPattern     = v[3]
        local desiredResult = v[4]

        if type(v[1]) == "string" and
           type(v[2]) == "string" and
           (type(v[3]) == "boolean" or type(v[3]) == "nil") and
           (type(v[4]) == "boolean" or type(v[4]) == "nil") then

            if headerToCheck == '*' and valueToCheck == '*' then
                accessGranted = desiredResult
                break
            else
                local matched = false
                local value = headers[headerMap[headerToCheck]]
                if value then
                    if isPattern then
                        matched = value:match(valueToCheck)
                    else
                        matched = (value == valueToCheck)
                    end
                end
                if matched then
                    accessGranted = desiredResult
                    break
                end
            end
        else
            log.wf("access-list entry %d malformed, found { %s, %s, %s, %s }: skipping", i, type(v[1]), type(v[2]), type(v[3]), type(v[4]))
        end
    end

    return accessGranted
end

local webServerHandler = function(self, method, path, headers, body)
    method = method:upper()

    -- to help make proper URL in error functions
    headers._SSL = self._ssl and true or false

    if self._accessList and not verifyAccess(self._accessList, headers) then
        return self._errorHandlers[403](method, path, headers)
    end

    local action = self._supportedMethods[method]
    if not action then return self._errorHandlers[405](method, path, headers) end

-- if the method is a function, we make no assumptions -- the function gets the raw input
    if type(action) == "function" then
    -- allow the action to ignore the request by returning false or nil to fall back to built-in methods
        local responseBody, responseCode, responseHeaders = action(self, method, path, headers, body)
        if responseBody then
            responseCode    = responseCode or 200
            responseHeaders = responseHeaders or {}
            responseHeaders["Server"]        = responseHeaders["Server"]        or serverSoftware .. " (OSX)"
            responseHeaders["Last-Modified"] = responseHeaders["Last-Modified"] or HTTPformattedDate()
            return responseBody, responseCode, responseHeaders
        end
    end

-- otherwise, figure out what specific file/directory is being targetted

    local pathParts  = http.urlParts((self._ssl and "https" or "http") .. "://" .. headers.Host .. path)
    local targetFile = self._documentRoot .. pathParts.path
    local attributes = fs.attributes(targetFile)
    if not attributes then return self._errorHandlers[404](method, path, headers) end

    if attributes.mode == "directory" and self._directoryIndex then
        if type(self._directoryIndex) ~= "table" then
            log.wf("directoryIndex: expected table, found %s", type(self._directoryIndex))
        else
            for i, v in ipairs(self._directoryIndex) do
                local attr = fs.attributes(targetFile .. "/" .. v)
                if attr and attr.mode == "file" then
                    attributes = attr
                    pathParts = http.urlParts((self._ssl and "https" or "http") .. "://" .. headers.Host .. pathParts.path .. "/" .. v .. (pathParts.query and ("?" .. pathParts.query) or ""))
                    targetFile = targetFile .. "/" .. v
                    break
                elseif attr then
                    log.wf("default directoryIndex %s for %s is not a file; skipping", v, targetFile)
                end
            end
        end
    end

-- check extension and see if it's an executable CGI
    local itBeCGI = false
    if pathParts.pathExtension and self._cgiEnabled then
        for i, v in ipairs(self._cgiExtensions) do
            if v == pathParts.pathExtension then
                itBeCGI = true
                break
            end
        end
    end

    local itBeDynamic = itBeCGI or (self._inHammerspoonExtension and pathParts.pathExtension and self._inHammerspoonExtension == pathParts.pathExtension)

    local responseBody, responseCode, responseHeaders = "", 200, {}

    responseHeaders["Last-Modified"] = HTTPformattedDate(attributes.modified)
    responseHeaders["Server"]        = serverSoftware .. " (OSX)"

    if itBeDynamic then
    -- target is dynamically generated
        responseHeaders["Last-Modified"] = HTTPformattedDate()

        -- per https://tools.ietf.org/html/rfc3875
        local CGIVariables = {
            AUTH_TYPE         = self:password() and "Basic" or nil,
            CONTENT_TYPE      = headers["Content-Type"],
            CONTENT_LENGTH    = headers["Content-Length"],
            GATEWAY_INTERFACE = "CGI/1.1",
--                 PATH_INFO         = , -- path portion after script (e.g. ../info.php/path/info/portion)
--                 PATH_TRANSLATED   = , -- see below
            QUERY_STRING      = pathParts.query,
            REQUEST_METHOD    = method,
            REQUEST_SCHEME    = pathParts.scheme,
            REMOTE_ADDR       = headers["X-Remote-Addr"],
            REMOTE_PORT       = headers["X-Remote-Port"],
--                 REMOTE_HOST       = , -- see below
--                 REMOTE_IDENT      = , -- we don't support IDENT protocol
            REMOTE_USER       = self:password() and "" or nil,
            SCRIPT_NAME       = pathParts.path,
            SERVER_ADMIN      = serverAdmin,
            SERVER_NAME       = pathParts.host,
            SERVER_ADDR       = headers["X-Server-Addr"],
            SERVER_PORT       = headers["X-Server-Port"],
            SERVER_PROTOCOL   = "HTTP/1.1",
            SERVER_SOFTWARE   = serverSoftware,
        }
        if CGIVariables.PATH_INFO then
            CGIVariables.PATH_TRANSLATED = self._documentRoot .. CGIVariables.PATH_INFO
        end
        if self._dnsLookup then
            local good, val = pcall(nethost.hostnamesForAddress, CGIVariables.REMOTE_ADDR)
            if good then
                CGIVariables.REMOTE_HOST = val[1]
            else
                log.f("unable to resolve %s", CGIVariables.REMOTE_ADDR)
            end
        end
--         if not CGIVariables.REMOTE_HOST then
--             CGIVariables.REMOTE_HOST = CGIVariables.REMOTE_ADDR
--         end

        -- Request headers per rfc2875
        for k, v in pairs(headers) do
            local k2 = k:upper():gsub("-", "_")
            -- skip Authorization related headers (per rfc2875) and _SSL internally used flag
            if not ({ ["AUTHORIZATION"] = 1, ["PROXY-AUTHORIZATION"] = 1, ["_SSL"] = 1 })[k2] then
                CGIVariables["HTTP_" .. k2] = v
            end
        end

        -- commonly added
        CGIVariables.DOCUMENT_URI    = CGIVariables.SCRIPT_NAME .. (CGIVariables.PATH_INFO or "")
        CGIVariables.REQUEST_URI     = CGIVariables.DOCUMENT_URI .. (CGIVariables.QUERY_STRING and ("?" .. CGIVariables.QUERY_STRING) or "")
        CGIVariables.DOCUMENT_ROOT   = self._documentRoot
        CGIVariables.SCRIPT_FILENAME = targetFile
        CGIVariables.REQUEST_TIME    = os.time()

        if itBeCGI then
        -- do external script thing

-- this is a horrible horrible hack...
-- look for an update to hs.httpserver because I really really really want to use hs.task for this, but we need chunked or delayed response support for that to work...

            local scriptTimeout = self._scriptTimeout or DEFAULT_ScriptTimeout
            local tempFileName = fs.temporaryDirectory() .. "/" .. USERDATA_TAG:gsub("^hs%._asm%.", "") .. hshost.globallyUniqueString()

            local tmpCGIFile = io.open(tempFileName, "w")
            tmpCGIFile:write("#! /bin/bash\n\n")
            for k, v in pairs(CGIVariables) do
                tmpCGIFile:write(string.format("export %s=%q\n", k, v))
            end
            tmpCGIFile:write("exec " .. targetFile .. "\n")
            tmpCGIFile:close()
            os.execute("chmod +x " .. tempFileName)

            local tmpInputFile = io.open(tempFileName .. "input", "w")
            tmpInputFile:write(body)
            tmpInputFile:close()

            local out, stat, typ, rc = "** no output **", false, "** unknown **", -1

            local targetWD = self._documentRoot .. "/" .. table.concat(pathParts.pathComponents, "/", 2, #pathParts.pathComponents - 1)
            local oldWD = fs.currentDir()
            fs.chdir(targetWD)

            out, stat, typ, rc = hs.execute("/bin/cat " .. tempFileName .. "input | /usr/bin/env -i PATH=\"/usr/bin:/bin:/usr/sbin:/sbin\" " .. scriptWrapper .. " -t " .. tostring(scriptTimeout) .. " " .. tempFileName .. " 2> " .. tempFileName .. "err")

            fs.chdir(oldWD)

            if stat then
                responseStatus = 200
                local headerText, bodyText = out:match("^(.-)\r?\n\r?\n(.*)$")
                if headerText then
                    for line in (headerText .. "\n"):gmatch("(.-)\r?\n") do
                        local newKey, newValue = line:match("^(.-):(.*)$")
                        if not newKey then -- malformed header, break out and show everything
                            log.i("malformed header in CGI output")
                            bodyText = out
                            break
                        end
                        if newKey:upper() == "STATUS" then
                            responseStatus = newValue:match("(%d+)[^%d]")
                        else
                            responseHeaders[newKey] = newValue
                        end
                    end
                    responseBody = bodyText
                else
                    responseBody = out
                    responseHeaders["Content-Type"] = "text/plain"
                end
            else
                local errOutput = "** no stderr **"
                local errf = ioopen(tempFileName .. "err", "rb")
                if errf then
                    errOut = errf:read("a")
                    errf:close()
                end
                log.ef("CGI error: output:%s, stderr:%s, %s code:%d", out, errOut, typ, rc)
                log.ef("CGI support files %s* not removed", tempFileName)
                return self._errorHandlers[500](method, path, headers)
            end

            if log.level ~= 5 then -- if we're at verbose, it means we're tracking something down...
                os.execute("rm " .. tempFileName)
                os.execute("rm " .. tempFileName .. "input")
                os.execute("rm " .. tempFileName .. "err")
            else
                log.vf("CGI support files %s* not removed", tempFileName)
            end

        else
        -- do the in Hammerspoon lua file thing
            -- decode query and/or body
        end

    elseif ({ ["HEAD"] = 1, ["GET"] = 1, ["POST"] = 1 })[method] then

    -- otherwise, we can't truly POST, so treat POST as GET; it will ignore the content body which a static page can't get to anyways; POST should be handled by a function or dynamic support above -- this is a fallback for an improper form action, etc.

        if method == "POST" then method = "GET" end
        if method == "GET" or method == "HEAD" then
            if attributes.mode == "file" then
                local finput = io.open(targetFile, "rb")
                if finput then
                    if method == "GET" then -- don't actually do work for HEAD
                        responseBody = finput:read("a")
                    end
                    finput:close()
                    local contentType = fs.fileUTI(targetFile)
                    if contentType then contentType = fs.fileUTIalternate(contentType, "mime") end
                    responseHeaders["Content-Type"] = contentType
                else
                    return self._errorHandlers[403.2](method, path, headers)
                end
            elseif attributes.mode == "directory" and self._allowDirectory then
                if fs.dir(targetFile) then
                    if method == "GET" then -- don't actually do work for HEAD
                        local targetPath = pathParts.path
                        if not targetPath:match("/$") then targetPath = targetPath .. "/" end
                        responseBody = [[
                            <html>
                              <head>
                                <title>Directory listing for ]] .. targetPath .. [[</title>
                              </head>
                              <body>
                                <h1>Directory listing for ]] .. targetPath .. [[</h1>
                                <hr>
                                <pre>]]
                        for k in fs.dir(targetFile) do
                            local fattr = fs.attributes(targetFile.."/"..k)
                            if k:sub(1,1) ~= "." then
                                if fattr then
                                    responseBody = responseBody .. string.format("    %-12s %s %7.2fK <a href=\"http%s://%s%s%s\">%s%s</a>\n", fattr.mode, fattr.permissions, fattr.size / 1024, (self._ssl and "s" or ""), headers.Host, targetPath, k, k, (fattr.mode == "directory" and "/" or ""))
                                else
                                    responseBody = responseBody .. "    <i>unknown" .. string.rep(" ", 6) .. string.rep("-", 9) .. string.rep(" ", 10) .. "?? " .. k .. " ??</i>\n"
                                end
                            end
                        end
                        responseBody = responseBody .. [[</pre>
                                <hr>
                                <div align="right"><i>]] .. serverSoftware .. [[ at ]] .. os.date() .. [[</i></div>
                              </body>
                            </html>]]
                    end
                    responseHeaders["Content-Type"] = "text/html"
                else
                    return self._errorHandlers[403.2](method, path, headers)
                end
            elseif attributes.mode == "directory" then
                return self._errorHandlers[403.2](method, path, headers)
            end
        end
    else
    -- even though it's an allowed method, there is no built in support for it...
        return self._errorHandlers[405](method, path, headers)
    end

    if method == "HEAD" then responseBody = "" end -- in case it was dynamic and code gave us a body
    return responseBody, responseCode, responseHeaders
end

local objectMethods = {}
local mt_table = {
    __passwords = {},
    __tostrings = {},
    __index     = objectMethods,
    __metatable = objectMethods, -- getmetatable should only list the available methods
    __type      = USERDATA_TAG,
}

mt_table.__tostring  = function(_)
    return mt_table.__type .. ": " .. _:name() .. ":" .. tostring(_:port()) .. ", " .. (mt_table.__tostrings[_] or "* unbound -- this is unsupported *")
end

--- hs._asm.hsminweb:port([port]) -> hsminwebTable | current-value
--- Method
--- Get or set the name the port the web server listens on
---
--- Parameters:
---  * port - an optional integer specifying the TCP port the server listens for requests on when it is running.  Defaults to `nil`, which causes the server to randomly choose a port when it is started.
---
--- Returns:
---  * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.
---
--- Notes:
---  * due to security restrictions enforced by OS X, the port must be a number greater than 1023
objectMethods.port = function(self, ...)
    local args = table.pack(...)
    assert(type(args[1]) == "nil" or (type(args[1]) == "number" and math.tointeger(args[1])), "argument must be an integer")
    if args.n > 0 then
        if self._server then
            self._server:setPort(args[1])
            self._port = self._server:getPort()
        else
            self._port = args[1]
        end
        return self
    else
        return self._server and self._server:getPort() or self._port
    end
end

--- hs._asm.hsminweb:name([name]) -> hsminwebTable | current-value
--- Method
--- Get or set the name the web server uses in Bonjour advertisement when the web server is running.
---
--- Parameters:
---  * name - an optional string specifying the name the server advertises itself as when Bonjour is enabled and the web server is running.  Defaults to `nil`, which causes the server to be advertised with the computer's name as defined in the Sharing preferences panel for the computer.
---
--- Returns:
---  * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.
objectMethods.name  = function(self, ...)
    local args = table.pack(...)
    assert(type(args[1]) == "nil" or type(args[1] == "string"), "argument must be string")
    if args.n > 0 then
        if self._server then
            self._server:setName(args[1])
            self._name = self._server:getName()
        else
            self._name = args[1]
        end
        return self
    else
        return self._server and self._server:getName() or self._name
    end
end

--- hs._asm.hsminweb:password([password]) -> hsminwebTable | boolean
--- Method
--- Set a password for the hsminweb web server, or return a boolean indicating whether or not a password is currently set for the web server.
---
--- Parameters:
---  * password - An optional string that contains the server password, or an explicit `nil` to remove an existing password.
---
--- Returns:
---  * the hsminwebTable object if a parameter is provided, or a boolean indicathing whether or not a password has been set if no parameter is specified.
---
--- Notes:
---  * the password, if set, is server wide and causes the server to use the Basic authentication scheme with an empty string for the username.
---  * this module is an extension to the Hammerspoon core module `hs.httpserver`, so it has the limitations regarding server passwords. See the documentation for `hs.httpserver.setPassword` (`help.hs.httpserver.setPassword` in the Hammerspoon console).
objectMethods.password = function(self, ...)
    local args = table.pack(...)
    assert(type(args[1]) == "nil" or type(args[1] == "string"), "argument must be string")
    if args.n > 0 then
        if self._server then
            self._server:setPassword(args[1])
            mt_table.__passwords[self] = args[1]
        else
            mt_table.__passwords[self] = args[1]
        end
        return self
    else
        return  mt_table.__passwords[self] and true or false
    end
end


--- hs._asm.hsminweb:maxBodySize([size]) -> hsminwebTable | current-value
--- Method
--- Get or set the maximum body size for an HTTP request
---
--- Parameters:
---  * size - An optional integer value specifying the maximum body size allowed for an incoming HTTP request in bytes.  Defaults to 10485760 (10 MB).
---
--- Returns:
---  * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.
---
--- Notes:
---  * Because the Hammerspoon http server processes incoming requests completely in memory, this method puts a limit on the maximum size for a POST or PUT request.
---  * If the request body excedes this size, `hs.httpserver` will respond with a status code of 405 for the method before this module ever receives the request.
objectMethods.maxBodySize = function(self, ...)
    local args = table.pack(...)
    assert(type(args[1]) == "nil" or (type(args[1]) == "number" and math.tointeger(args[1])), "argument must be an integer")
    if args.n > 0 then
        if self._server then
            self._server:maxBodySize(args[1])
            self._maxBodySize = self._server:maxBodySize()
        else
            self._maxBodySize = args[1]
        end
        return self
    else
        return self._server and self._server:maxBodySize() or self._maxBodySize
    end
end

--- hs._asm.hsminweb:documentRoot([path]) -> hsminwebTable | current-value
--- Method
--- Get or set the document root for the web server.
---
--- Parameters:
---  * path - an optional string, default `os.getenv("HOME") .. "/Sites"`, specifying where documents for the web server should be served from.
---
--- Returns:
---  * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.
objectMethods.documentRoot = function(self, ...)
    local args = table.pack(...)
    assert(type(args[1]) == "nil" or type(args[1] == "string"), "argument must be string")
    if args.n > 0 then
        self._documentRoot = args[1]
        return self
    else
        return self._documentRoot
    end
end

--- hs._asm.hsminweb:ssl([flag]) -> hsminwebTable | current-value
--- Method
--- Get or set the whether or not the web server utilizes SSL for HTTP request and response communications.
---
--- Parameters:
---  * flag - an optional boolean, defaults to false, indicating whether or not the server utilizes SSL for HTTP request and response traffic.
---
--- Returns:
---  * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.
---
--- Notes:
---  * this flag can only be changed when the server is not running (i.e. the [hs._asm.hsminweb:start](#start) method has not yet been called, or the [hs._asm.hsminweb:stop](#stop) method is called first.)
---  * this module is an extension to the Hammerspoon core module `hs.httpserver`, so it has the considerations regarding SSL. See the documentation for `hs.httpserver.new` (`help.hs.httpserver.new` in the Hammerspoon console).
objectMethods.ssl = function(self, ...)
    local args = table.pack(...)
    assert(type(args[1]) == "nil" or type(args[1] == "boolean"), "argument must be boolean")
    if args.n > 0 then
        if not self._server then
            self._ssl = args[1]
            return self
        else
            error("ssl cannot be set for a running server", 2)
        end
    else
        return self._ssl
    end
end

--- hs._asm.hsminweb:bonjour([flag]) -> hsminwebTable | current-value
--- Method
--- Get or set the whether or not the web server should advertise itself via Bonjour when it is running.
---
--- Parameters:
---  * flag - an optional boolean, defaults to true, indicating whether or not the server should advertise itself via Bonjour when it is running.
---
--- Returns:
---  * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.
---
--- Notes:
---  * this flag can only be changed when the server is not running (i.e. the [hs._asm.hsminweb:start](#start) method has not yet been called, or the [hs._asm.hsminweb:stop](#stop) method is called first.)
objectMethods.bonjour = function(self, ...)
    local args = table.pack(...)
    assert(type(args[1]) == "nil" or type(args[1] == "boolean"), "argument must be boolean")
    if args.n > 0 then
        if not self._bonjour then
            self._bonjour = args[1]
            return self
        else
            error("bonjour cannot be set for a running server", 2)
        end
    else
        return self._bonjour
    end
end

--- hs._asm.hsminweb:allowDirectory([flag]) -> hsminwebTable | current-value
--- Method
--- Get or set the whether or not a directory index is returned when the requested URL specifies a directory and no file matching an entry in the directory indexes table is found.
---
--- Parameters:
---  * flag - an optional boolean, defaults to false, indicating whether or not a directory index can be returned when a default file cannot be located.
---
--- Returns:
---  * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.
---
--- Notes:
---  * if this value is false, then an attempt to retrieve a URL specifying a directory that does not contain a default file as identified by one of the entries in the [hs._asm.hsminweb:directoryIndex](#directoryIndex) list will result in a "403.2" error.
objectMethods.allowDirectory = function(self, ...)
    local args = table.pack(...)
    assert(type(args[1]) == "nil" or type(args[1] == "boolean"), "argument must be boolean")
    if args.n > 0 then
        self._allowDirectory = args[1]
        return self
    else
        return self._allowDirectory
    end
end

--- hs._asm.hsminweb:dnsLookup([flag]) -> hsminwebTable | current-value
--- Method
--- Get or set the whether or not DNS lookups are performed.
---
--- Parameters:
---  * flag - an optional boolean, defaults to false, indicating whether or not DNS lookups are performed.
---
--- Returns:
---  * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.
---
--- Notes:
---  * DNS lookups can be time consuming or even block Hammerspoon for a short time, so they are disabled by default.
---  * Currently DNS lookups are (optionally) performed for CGI scripts, but may be added for other purposes in the future (logging, etc.).
objectMethods.dnsLookup = function(self, ...)
    local args = table.pack(...)
    assert(type(args[1]) == "nil" or type(args[1] == "boolean"), "argument must be boolean")
    if args.n > 0 then
        self._dnsLookup = args[1]
        return self
    else
        return self._dnsLookup
    end
end

--- hs._asm.hsminweb:directoryIndex([table]) -> hsminwebTable | current-value
--- Method
--- Get or set the file names to look for when the requested URL specifies a directory.
---
--- Parameters:
---  * table - an optional table or `nil`, defaults to `{ "index.html", "index.htm" }`, specifying a list of file names to look for when the requested URL specifies a directory.  If a file with one of the names is found in the directory, this file is served instead of the directory.
---
--- Returns:
---  * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.
---
--- Notes:
---  * Files listed in this table are checked in order, so the first matched is served.  If no file match occurs, then the server will return a generated list of the files in the directory, or a "403.2" error, depending upon the value controlled by [hs._asm.hsminweb:allowDirectory](#allowDirectory).
objectMethods.directoryIndex = function(self, ...)
    local args = table.pack(...)
    assert(type(args[1]) == "nil" or type(args[1] == "table"), "argument must be a table of index file names")
    if args.n > 0 then
        self._directoryIndex = args[1]
        return self
    else
        return self._directoryIndex
    end
end

--- hs._asm.hsminweb:cgiEnabled([flag]) -> hsminwebTable | current-value
--- Method
--- Get or set the whether or not CGI file execution is enabled.
---
--- Parameters:
---  * flag - an optional boolean, defaults to false, indicating whether or not CGI script execution is enabled for the web server.
---
--- Returns:
---  * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.
objectMethods.cgiEnabled = function(self, ...)
    local args = table.pack(...)
    assert(type(args[1]) == "nil" or type(args[1] == "boolean"), "argument must be boolean")
    if args.n > 0 then
        self._cgiEnabled = args[1]
        return self
    else
        return self._cgiEnabled
    end
end

--- hs._asm.hsminweb:cgiExtensions([table]) -> hsminwebTable | current-value
--- Method
--- Get or set the file extensions which identify files which should be executed as CGI scripts to provide the results to an HTTP request.
---
--- Parameters:
---  * table - an optional table or `nil`, defaults to `{ "cgi", "pl" }`, specifying a list of file extensions which indicate that a file should be executed as CGI scripts to provide the content for an HTTP request.
---
--- Returns:
---  * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.
---
--- Notes:
---  * this list is ignored if [hs._asm.hsminweb:cgiEnabled](#cgiEnabled) is not also set to true.
objectMethods.cgiExtensions = function(self, ...)
    local args = table.pack(...)
    assert(type(args[1]) == "nil" or type(args[1] == "table"), "argument must be table of file extensions")
    if args.n > 0 then
        self._cgiExtensions = args[1]
        return self
    else
        return self._cgiExtensions
    end
end

--- hs._asm.hsminweb:inHammerspoonExtension([string]) -> hsminwebTable | current-value
--- Method
--- Get or set the extension of files which contain Lua code which should be executed within Hammerspoon to provide the results to an HTTP request.
---
--- Parameters:
---  * string - an optional string or `nil`, defaults to `nil`, specifying the file extension which indicates that a file should be executed as Lua code within the Hammerspoon environment to provide the content for an HTTP request.
---
--- Returns:
---  * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.
---
--- Notes:
---  * This extension is checked after the extensions given to [hs._asm.hsminweb:cgiExtensions](#cgiExtensions); this means that if the same extension set by this method is also in the CGI extensions list, then the file will be interpreted as a CGI script and ignore this setting.
objectMethods.inHammerspoonExtension = function(self, ...)
    local args = table.pack(...)
    assert(type(args[1]) == "nil" or type(args[1] == "string"), "argument must be a file extension")
    if args.n > 0 then
        self._inHammerspoonExtension = args[1]
        return self
    else
        return self._inHammerspoonExtension
    end
end

--- hs._asm.hsminweb:scriptTimeout([integer]) -> hsminwebTable | current-value
--- Method
--- Get or set the timeout for a CGI script
---
--- Parameters:
---  * integer - an optional integer, defaults to 30, specifying the length of time in seconds a CGI script should be allowed to run before being forcibly terminated if it has not yet completed its task.
---
--- Returns:
---  * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.
---
--- Notes:
---  * With the current functionality available in `hs.httpserver`, any script which is expected to return content for an HTTP request must run in a blocking manner -- this means that no other Hammerspoon activity can be occurring while the script is executing.  This parameter lets you set the maximum amount of time such a script can hold things up before being terminated.
---  * An alternative implementation of at least some of the methods available in `hs.httpserver` is being considered which may make it possible to use `hs.task` for these scripts, which would alleviate this blocking behavior.  However, even if this is addressed, a timeout for scripts is still desirable so that a client making a request doesn't sit around waiting forever if a script is malformed.
objectMethods.scriptTimeout = function(self, ...)
    local args = table.pack(...)
    assert(type(args[1]) == "nil" or (type(args[1]) == "number" and math.tointeger(args[1])), "argument must be an integer")
    if args.n > 0 then
        self._scriptTimeout = args[1]
        return self
    else
        return self._scriptTimeout
    end
end

--- hs._asm.hsminweb:accessList([table]) -> hsminwebTable | current-value
--- Method
--- Get or set the access-list table for the hsminweb web server
---
--- Parameters:
---  * table - an optional table or `nil` containing the access list for the web server, default `nil`.
---
--- Returns:
---  * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.
---
--- Notes:
---  * The access-list feature works by comparing the request headers against a list of tests which either accept or reject the request.  If no access list is set (i.e. it is assigned a value of `nil`), then all requests are served.  If a table is passed into this method, then any request which is not explicitly accepted by one of the tests provided is rejected (i.e. there is an implicit "reject" at the end of the list).
---  * The access-list table is a list of tests which are evaluated in order.  The first test which matches a given request determines whether or not the request is accepted or rejected.
---  * Each entry in the access-list table is also a table with the following format:
---    * { 'header', 'value', isPattern, isAccepted }
---      * header     - a string value matching the name of a header.  While the header name must match exactly, the comparison is case-insensitive (i.e. "X-Remote-addr" and "x-remote-addr" will both match the actual header name used, which is "X-Remote-Addr").
---      * value      - a string value specifying the value to compare the header key's value to.
---      * isPattern  - a boolean indicating whether or not the header key's value should be compared to `value` as a pattern match (true) -- see Lua documentation 6.4.1, `help.lua._man._6_4_1` in the console, or as an exact match (false)
---      * isAccepted - a boolean indicating whether or not a match should be accepted (true) or rejected (false)
---    * A special entry of the form { '\*', '\*', '\*', true } accepts all further requests and can be used as the final entry if you wish for the access list to function as a list of requests to reject, but to accept any requests which do not match a previous test.
---    * A special entry of the form { '\*', '\*', '\*', false } rejects all further requests and can be used as the final entry if you wish for the access list to function as a list of requests to accept, but to reject any requests which do not match a previous test.  This is the implicit "default" final test if a table is assigned with the access-list method and does not actually need to be specified, but is included for completeness.
---    * Note that any entry after an entry in which the first two parameters are equal to '\*' will never actually be used.
---
---  * The tests are performed in order; if you wich to allow one IP address in a range, but reject all others, you should list the accepted IP addresses first. For example:
---     ~~~
---     {
---        { 'X-Remote-Addr', '192.168.1.100',  false, true },  -- accept requests from 192.168.1.100
---        { 'X-Remote-Addr', '^192%.168%.1%.', true,  false }, -- reject all others from the 192.168.1 subnet
---        { '*',             '*',              '*',   true }   -- accept all other requests
---     }
---     ~~~
---
---  * Most of the headers available are provided by the requesting web browser, so the exact headers available will vary.  You can find some information about common HTTP request headers at: https://en.wikipedia.org/wiki/List_of_HTTP_header_fields.
---
---  * The following headers are inserted automatically by `hs.httpserver` and are probably the most useful for use in an access list:
---    * X-Remote-Addr - the remote IPv4 or IPv6 address of the machine making the request,
---    * X-Remote-Port - the TCP port of the remote machine where the request originated.
---    * X-Server-Addr - the server IPv4 or IPv6 address that the web server received the request from.  For machines with multiple interfaces, this will allow you to determine which interface the request was received on.
---    * X-Server-Port - the TCP port of the web server that received the request.
objectMethods.accessList = function(self, ...)
    local args = table.pack(...)
    assert(type(args[1]) == "nil" or type(args[1] == "table"), "argument must be table of access requirements")
    if args.n > 0 then
        self._accessList = args[1]
        return self
    else
        return self._accessList
    end
end

--- hs._asm.hsminweb:start() -> hsminwebTable
--- Method
--- Start serving pages for the hsminweb web server.
---
--- Parameters:
---  * None
---
--- Returns:
---  * the hsminWebTable object
objectMethods.start = function(self)
    if not self._server then
        self._ssl     = self._ssl or false
        self._bonjour = (type(self._bonjour) == "nil") and true or self._bonjour
        self._server  = httpserver.new(self._ssl, self._bonjour):setCallback(function(...)
            return webServerHandler(self, ...)
        end)

        if self._port                 then self._server:setPort(self._port) end
        if self._name                 then self._server:setName(self._name) end
        if self._maxBodySize          then self._server:maxBodySize(self._maxBodySize) end
        if mt_table.__passwords[self] then self._server:setPassword(mt_table.__passwords[self]) end

        self._server:start()

        return self
    else
        error("server already started", 2)
    end
end

--- hs._asm.hsminweb:stop() -> hsminwebTable
--- Method
--- Stop serving pages for the hsminweb web server.
---
--- Parameters:
---  * None
---
--- Returns:
---  * the hsminWebTable object
---
--- Notes:
---  * this method is called automatically during garbage collection.
objectMethods.stop = function(self)
    if self._server then
        self._server:stop()
        self._server = nil
        return self
    else
        error("server not currently running", 2)
    end
end

objectMethods.__gc = function(self)
    if self._server then self:stop() end
end

--- hs._asm.hsminweb.new([documentRoot]) -> hsminwebTable
--- Constructor
--- Create a new hsminweb table object representing a Hammerspoon Web Server.
---
--- Parameters:
---  * documentRoot - an optional string specifying the document root for the new web server.  Defaults to the Hammerspoon users `Sites` sub-directory (i.e. `os.getenv("HOME").."/Sites"`).
---
--- Returns:
---  * a table representing the hsminweb object.
---
--- Notes:
---  * a web server's document root is the directory which contains the documents or files to be served by the web server.
---  * while an hs.minweb object is actually represented by a Lua table, it has been assigned a meta-table which allows methods to be called directly on it like a user-data object.  For most purposes, you should think of this table as the module's userdata.
module.new = function(documentRoot)
    local instance = {
        _documentRoot     = documentRoot or os.getenv("HOME").."/Sites",
        _directoryIndex   = shallowCopy(directoryIndex),
        _cgiExtensions    = shallowCopy(cgiExtensions),

        _errorHandlers    = setmetatable({}, { __index = errorHandlers }),
        _supportedMethods = setmetatable({}, { __index = supportedMethods }),
    }

    -- make it easy to see which methods are supported
    for k, v in pairs(supportedMethods) do if v then instance._supportedMethods[k] = v end end

    -- save tostring(instance) since we override it, but I like the address so it looks more "formal" in the console...
    mt_table.__tostrings[instance] = tostring(instance)

    return setmetatable(instance, mt_table)
end

--- hs._asm.hsminweb._errorHandlers
--- Variable
--- Accessed as `object._errorHandlers[errorCode]`.  A table whose keyed entries specify the function to generate the error response page for an HTTP error.
---
--- HTTP uses a three digit numeric code for error conditions.  Some servers have introduced subcodes, which are appended as a decimal added to the error condition. In addition, the key "default" is used for error codes which do not have a defined function.
---
--- Built in handlers exist for the following error codes:
---  * 403   - Forbidden, usually used when authentication is required, but no authentication token exists or an invalid token is used
---  * 403.2 - Read Access Forbidden, usually specified when a file is not readable by the server, or directory indexing is not allowed and no default file exists for a URL specifying a directory
---  * 404   - Object Not Found, usually indicating that the URL specifies a non-existant destination or file
---  * 405   - Method Not Supported, indicating that the HTTP request specified a method not supported by the web server
---  * 500   - Internal Server Error, a catch-all for server side problems that prevent a page from being returned.  Commonly when CGI scripts fail for some reason.
---
--- The "default" key also specifies a 500 error, in this case because an error condition occurred for which there is no handler. The content of the message returned indicates the actual error code that was intended.
---
--- You can provide your own handler by specifying a function for the desired error condition.  The function should expect three arguments:
---  * method  - the method for the HTTP request
---  * path    - the full path, including any GET query items
---  * headers - a table containing key-value pairs for the HTTP request headers
---
--- If you override the default handler, the function should expect four arguments:  the error code as a string, followed by the same three arguments defined above.
---
--- In either case, the function should return three values:
---  * body    - the content to be returned, usually HTML for a basic error description page
---  * code    - a 3 digit integer specifying the HTTP Response status (see https://en.wikipedia.org/wiki/List_of_HTTP_status_codes)
---  * headers - a table containing any headers which should be included in the HTTP response.  Usually this will just be an empty table (e.g. {})

--- hs._asm.hsminweb._supportMethods
--- Variable
--- Accessed as `object._supportMethods[method]`.  A table whose keyed entries specify whether or not a specified HTTP method is supported by this server.
---
--- The default methods supported internally are:
---  * HEAD - an HTTP method which verifies whether or not a resource is available and it's last modified date
---  * GET  - an HTTP method requesting content; the default method used by web browsers for bookmarks or URLs typed in by the user
---  * POST - an HTTP method requesting content that includes content in the request body, most often used by forms to include user input or file data which may affect the content being returned.
---
--- These methods are included by default in this variable and are set to the boolean value true to indicate that they are supported and that the internal support code should be used.
---
--- You can assign a function to these methods if you wish for a custom handler to be invoked when the method is used in an HTTP request.  The function should accept five arguments:
---  * self    - the `hsminwebTable` object representing the web server
---  * method  - the method for the HTTP request
---  * path    - the full path, including any GET query items
---  * headers - a table containing the HTTP request headers
---  * body    - the content of the request body, if available, otherwise nil.  Currently only the POST and PUT methods will contain a request body, but this may change in the future.
---
--- The function should return one or three values:
---  * body    - the content to be returned.  If this is the boolean `false` or `nil`, then the request will fall through to the default handlers as if this function had never been called (this can be used in cases where you want to override the default behavior only for certain requests based on header or path details)
---  * code    - a 3 digit integer specifying the HTTP Response status (see https://en.wikipedia.org/wiki/List_of_HTTP_status_codes)
---  * headers - a table containing any headers which should be included in the HTTP response.  If `Server` or `Last-Modified` are not present, they will be provided automatically.
---
--- If you assign `false` to a method, then any request utilizing that method will return a status of 405 (Method Not Supported).  E.g. `object._supportMethods["POST"] = false` will prevent the POST method from being supported.
---
--- There are some functions and conventions used within this module which can simplify generating appropriate content within your custom functions.  Currently, you should review the module source, but a companion document describing these functions and conventions is expected to follow in the near future.
---
--- Common HTTP request methods can be found at https://en.wikipedia.org/wiki/Hypertext_Transfer_Protocol#Request_methods and https://en.wikipedia.org/wiki/WebDAV.  Currently, only HEAD, GET, and POST have built in support for static pages; even if you set other methods to `true`, they will return a status code of 405 (Method Not Supported) if the request does not invoke a CGI file for dynamic content.
---
--- A companion module supporting the methods required for WebDAV is being considered.


--- hs._asm.hsminweb.dateFormatString
--- Constant
--- A format string, usable with `os.date`, which will display a date in the format expected for HTTP communications as described in RFC 822, updated by RFC 1123.
module.dateFormatString = HTTPdateFormatString

--- hs._asm.hsminweb.formattedDate([date]) -> string
--- Function
--- Returns the current or specified time in the format expected for HTTP communications as described in RFC 822, updated by RFC 1123.
---
--- Parameters:
---  * date - an optional integer specifying the date as the number of seconds since 00:00:00 UTC on 1 January 1970.  Defaults to the current time as returned by `os.time()`
---
--- Returns:
---  * the time indicated as a string in the format expected for HTTP communications as described in RFC 822, updated by RFC 1123.
module.formattedDate    = HTTPformattedDate

return module
