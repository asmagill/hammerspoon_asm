hs._asm.hsminweb
================

*This documentation is preliminary and is subject to change.*

- - -

Minimalist Web Server for Hammerspoon

Note that his module is in development; not all methods described here are fully functional yet.  Others may change slightly during development, so be aware, if you choose to start using this module, that things may change somewhat before it stabilizes.

This module aims to be a minimal, but reasonably functional, web server for use within Hammerspoon.  Expanding upon the Hammerspoon module, `hs.httpserver`, this module adds support for serving static pages stored at a specified document root as well as serving dynamic content from user defined functions, lua files interpreted within the Hammerspoon environment, and external executables which support the CGI/1.1 framework.

This module aims to provide a fully functional, and somewhat extendable, web server foundation, but will never replace a true dedicated web server application.  Some limitations include:
 * It is single threaded within the Hammerspoon environment and can only serve one resource at a time
 * As with all Hammerspoon modules, while dynamic content is being generated, Hammerspoon cannot respond to other callback functions -- a complex or time consuming script may block other Hammerspoon activity in a noticeable manner.
 * All document requests and responses are handled in memory only -- because of this, maximum resource size is limited to what you are willing to allow Hammerspoon to consume and memory limitations of your computer.

While some of these limitations may be mitigated to an extent in the future with additional modules and additions to `hs.httpserver`, Hammerspoon's web serving capabilities will never replace a dedicated web server when volume or speed is required.

### Usage
~~~lua
hsminweb = require("hs._asm.hsminweb")
~~~

### Module Constructors

<a name="new"></a>
~~~lua
hsminweb.new([documentRoot]) -> hsminwebTable
~~~
Create a new hsminweb table object representing a Hammerspoon Web Server.

Parameters:
 * documentRoot - an optional string specifying the document root for the new web server.  Defaults to the Hammerspoon users `Sites` sub-directory (i.e. `os.getenv("HOME").."/Sites"`).

Returns:
 * a table representing the hsminweb object.

Notes:
 * a web server's document root is the directory which contains the documents or files to be served by the web server.
 * while an hs.minweb object is actually represented by a Lua table, it has been assigned a meta-table which allows methods to be called directly on it like a user-data object.  For most purposes, you should think of this table as the module's userdata.

### Module Functions

<a name="formattedDate"></a>
~~~lua
hsminweb.formattedDate([date]) -> string
~~~
Returns the current or specified time in the format expected for HTTP communications as described in RFC 822, updated by RFC 1123.

Parameters:
 * date - an optional integer specifying the date as the number of seconds since 00:00:00 UTC on 1 January 1970.  Defaults to the current time as returned by `os.time()`

Returns:
 * the time indicated as a string in the format expected for HTTP communications as described in RFC 822, updated by RFC 1123.

### Module Methods

<a name="accessList"></a>
~~~lua
hsminweb:accessList([table]) -> hsminwebTable | current-value
~~~
Get or set the access-list table for the hsminweb web server

Parameters:
 * table - an optional table or `nil` containing the access list for the web server, default `nil`.

Returns:
 * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.

Notes:
 * The access-list feature works by comparing the request headers against a list of tests which either accept or reject the request.  If no access list is set (i.e. it is assigned a value of `nil`), then all requests are served.  If a table is passed into this method, then any request which is not explicitly accepted by one of the tests provided is rejected (i.e. there is an implicit "reject" at the end of the list).
 * The access-list table is a list of tests which are evaluated in order.  The first test which matches a given request determines whether or not the request is accepted or rejected.
 * Each entry in the access-list table is also a table with the following format:
   * { 'header', 'value', isPattern, isAccepted }
     * header     - a string value matching the name of a header.  While the header name must match exactly, the comparison is case-insensitive (i.e. "X-Client-IP" and "x-client-ip" will both match the actual header name used, which is "X-Client-Ip").
     * value      - a string value specifying the value to compare the header key's value to.
     * isPattern  - a boolean indicating whether or not the header key's value should be compared to `value` as a pattern match (true) -- see Lua documentation 6.4.1, `help.lua._man._6_4_1` in the console, or as an exact match (false)
     * isAccepted - a boolean indicating whether or not a match should be accepted (true) or rejected (false)
   * A special entry of the form { '\*', '\*', '\*', true } accepts all further requests and can be used as the final entry if you wish for the access list to function as a list of requests to reject, but to accept any requests which do not match a previous test.
   * A special entry of the form { '\*', '\*', '\*', false } rejects all further requests and can be used as the final entry if you wish for the access list to function as a list of requests to accept, but to reject any requests which do not match a previous test.  This is the implicit "default" final test if a table is assigned with the access-list method and does not actually need to be specified, but is allowed for "completeness".
   * Note that any entry after an entry in which the first two parameters are equal to '*' will never actually be used.

 * The tests are performed in order; if you wich to allow one IP address in a range, but reject all others, you should list the accepted IP addresses first. For example:
    ~~~
    {
       { 'X-Client-IP', '192.168.1.100',  false, true },  -- accept requests from 192.168.1.100
       { 'X-Client-IP', '^192%.168%.1%.', true,  false }, -- reject all others from the 192.168.1 subnet
       { '*',           '*',              '*',   true }   -- accept all other requests
    }
    ~~~

- - -

<a name="allowDirectory"></a>
~~~lua
hsminweb:allowDirectory([flag]) -> hsminwebTable | current-value
~~~
Get or set the whether or not a directory index is returned when the requested URL specifies a directory and no file matching an entry in the directory indexes table is found.

Parameters:
 * flag - an optional boolean, defaults to false, indicating whether or not a directory index can be returned when a default file cannot be located.

Returns:
 * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.

Notes:
 * if this value is false, then an attempt to retrieve a URL specifying a directory that does not contain a default file as identified by one of the entries in the [hs._asm.hsminweb:directoryIndex](#directoryIndex) list will result in a "403.2" error.

- - -

<a name="bonjour"></a>
~~~lua
hsminweb:bonjour([flag]) -> hsminwebTable | current-value
~~~
Get or set the whether or not the web server should advertise itself via Bonjour when it is running.

Parameters:
 * flag - an optional boolean, defaults to true, indicating whether or not the server should advertise itself via Bonjour when it is running.

Returns:
 * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.

Notes:
 * this flag can only be changed when the server is not running (i.e. the [hs._asm.hsminweb:start](#start) method has not yet been called, or the [hs._asm.hsminweb:stop](#stop) method is called first.)

- - -

<a name="cgiEnabled"></a>
~~~lua
hsminweb:cgiEnabled([flag]) -> hsminwebTable | current-value
~~~
Get or set the whether or not CGI file execution is enabled.

Parameters:
 * flag - an optional boolean, defaults to false, indicating whether or not CGI script execution is enabled for the web server.

Returns:
 * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.

- - -

<a name="cgiExtensions"></a>
~~~lua
hsminweb:cgiExtensions([table]) -> hsminwebTable | current-value
~~~
Get or set the file extensions which identify files which should be executed as CGI scripts to provide the results to an HTTP request.

Parameters:
 * table - an optional table or `nil`, defaults to `{ "cgi", "pl" }`, specifying a list of file extensions which indicate that a file should be executed as CGI scripts to provide the content for an HTTP request.

Returns:
 * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.

Notes:
 * this list is ignored if [hs._asm.hsminweb:cgiEnabled](#cgiEnabled) is not also set to true.

- - -

<a name="directoryIndex"></a>
~~~lua
hsminweb:directoryIndex([table]) -> hsminwebTable | current-value
~~~
Get or set the file names to look for when the requested URL specifies a directory.

Parameters:
 * table - an optional table or `nil`, defaults to `{ "index.html", "index.htm" }`, specifying a list of file names to look for when the requested URL specifies a directory.  If a file with one of the names is found in the directory, this file is served instead of the directory.

Returns:
 * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.

Notes:
 * Files listed in this table are checked in order, so the first matched is served.  If no file match occurs, then the server will return a generated list of the files in the directory, or a "403.2" error, depending upon the value controlled by [hs._asm.hsminweb:allowDirectory](#allowDirectory).

- - -

<a name="dnsLookup"></a>
~~~lua
hsminweb:dnsLookup([flag]) -> hsminwebTable | current-value
~~~
Get or set the whether or not DNS lookups are performed.

Parameters:
 * flag - an optional boolean, defaults to false, indicating whether or not DNS lookups are performed.

Returns:
 * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.

Notes:
 * DNS lookups can be time consuming or even block Hammerspoon for a short time, so they are disabled by default.
 * Currently DNS lookups are (optionally) performed for CGI scripts, but may be added for other purposes in the future (logging, etc.).

- - -

<a name="documentRoot"></a>
~~~lua
hsminweb:documentRoot([path]) -> hsminwebTable | current-value
~~~
Get or set the document root for the web server.

Parameters:
 * path - an optional string, default `os.getenv("HOME") .. "/Sites"`, specifying where documents for the web server should be served from.

Returns:
 * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.

- - -

<a name="inHammerspoonExtension"></a>
~~~lua
hsminweb:inHammerspoonExtension([string]) -> hsminwebTable | current-value
~~~
Get or set the extension of files which contain Lua code which should be executed within Hammerspoon to provide the results to an HTTP request.

Parameters:
 * string - an optional string or `nil`, defaults to `nil`, specifying the file extension which indicates that a file should be executed as Lua code within the Hammerspoon environment to provide the content for an HTTP request.

Returns:
 * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.

Notes:
 * This extension is checked after the extensions given to [hs._asm.hsminweb:cgiExtensions](#cgiExtensions); this means that if the same extension set by this method is also in the CGI extensions list, then the file will be interpreted as a CGI script and ignore this setting.

- - -

<a name="maxBodySize"></a>
~~~lua
hsminweb:maxBodySize([size]) -> hsminwebTable | current-value
~~~
Get or set the maximum body size for an HTTP request

Parameters:
 * size - An optional integer value specifying the maximum body size allowed for an incoming HTTP request in bytes.  Defaults to 10485760 (10 MB).

Returns:
 * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.

Notes:
 * Because the Hammerspoon http server processes incoming requests completely in memory, this method puts a limit on the maximum size for a POST or PUT request.
 * If the request body excedes this size, `hs.httpserver` will respond with a status code of 405 for the method before this module ever receives the request.

- - -

<a name="name"></a>
~~~lua
hsminweb:name([name]) -> hsminwebTable | current-value
~~~
Get or set the name the web server uses in Bonjour advertisement when the web server is running.

Parameters:
 * name - an optional string specifying the name the server advertises itself as when Bonjour is enabled and the web server is running.  Defaults to `nil`, which causes the server to be advertised with the computer's name as defined in the Sharing preferences panel for the computer.

Returns:
 * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.

- - -

<a name="password"></a>
~~~lua
hsminweb:password([password]) -> hsminwebTable | boolean
~~~
Set a password for the hsminweb web server, or return a boolean indicating whether or not a password is currently set for the web server.

Parameters:
 * password - An optional string that contains the server password, or an explicit `nil` to remove an existing password.

Returns:
 * the hsminwebTable object if a parameter is provided, or a boolean indicathing whether or not a password has been set if no parameter is specified.

Notes:
 * the password, if set, is server wide and causes the server to use the Basic authentication scheme with an empty string for the username.
 * this module is an extension to the Hammerspoon core module `hs.httpserver`, so it has the limitations regarding server passwords. See the documentation for `hs.httpserver.setPassword` (`help.hs.httpserver.setPassword` in the Hammerspoon console).

- - -

<a name="port"></a>
~~~lua
hsminweb:port([port]) -> hsminwebTable | current-value
~~~
Get or set the name the port the web server listens on

Parameters:
 * port - an optional integer specifying the TCP port the server listens for requests on when it is running.  Defaults to `nil`, which causes the server to randomly choose a port when it is started.

Returns:
 * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.

Notes:
 * due to security restrictions enforced by OS X, the port must be a number greater than 1023

- - -

<a name="scriptTimeout"></a>
~~~lua
hsminweb:scriptTimeout([integer]) -> hsminwebTable | current-value
~~~
Get or set the timeout for a CGI script

Parameters:
 * integer - an optional integer, defaults to 30, specifying the length of time in seconds a CGI script should be allowed to run before being forcibly terminated if it has not yet completed its task.

Returns:
 * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.

Notes:
 * With the current functionality available in `hs.httpserver`, any script which is expected to return content for an HTTP request must run in a blocking manner -- this means that no other Hammerspoon activity can be occurring while the script is executing.  This parameter lets you set the maximum amount of time such a script can hold things up before being terminated.
 * An alternative implementation of at least some of the methods available in `hs.httpserver` is being considered which may make it possible to use `hs.task` for these scripts, which would alleviate this blocking behavior.  However, even if this is addressed, a timeout for scripts is still desirable so that a client making a request doesn't sit around waiting forever if a script is malformed.

- - -

<a name="ssl"></a>
~~~lua
hsminweb:ssl([flag]) -> hsminwebTable | current-value
~~~
Get or set the whether or not the web server utilizes SSL for HTTP request and response communications.

Parameters:
 * flag - an optional boolean, defaults to false, indicating whether or not the server utilizes SSL for HTTP request and response traffic.

Returns:
 * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.

Notes:
 * this flag can only be changed when the server is not running (i.e. the [hs._asm.hsminweb:start](#start) method has not yet been called, or the [hs._asm.hsminweb:stop](#stop) method is called first.)
 * this module is an extension to the Hammerspoon core module `hs.httpserver`, so it has the considerations regarding SSL. See the documentation for `hs.httpserver.new` (`help.hs.httpserver.new` in the Hammerspoon console).

- - -

<a name="start"></a>
~~~lua
hsminweb:start() -> hsminwebTable
~~~
Start serving pages for the hsminweb web server.

Parameters:
 * None

Returns:
 * the hsminWebTable object

- - -

<a name="stop"></a>
~~~lua
hsminweb:stop() -> hsminwebTable
~~~
Stop serving pages for the hsminweb web server.

Parameters:
 * None

Returns:
 * the hsminWebTable object

Notes:
 * this method is called automatically during garbage collection.

### Module Variables

<a name="_errorHandlers"></a>
~~~lua
hsminweb._errorHandlers
~~~
Accessed as `object._errorHandlers[errorCode]`.  A table whose keyed entries specify the function to generate the error response page for an HTTP error.

HTTP uses a three digit numeric code for error conditions.  Some servers have introduced subcodes, which are appended as a decimal added to the error condition.  To allow for both types, this module uses the string representation of the error code as its keys.  In addition, the key "default" is used for error codes which do not have a defined function.

Built in handlers exist for the following error codes:
 * "403"   - Forbidden, usually used when authentication is required, but no authentication token exists or an invalid token is used
 * "403.2" - Read Access Forbidden, usually specified when a file is not readable by the server, or directory indexing is not allowed and no default file exists for a URL specifying a directory
 * "404"   - Object Not Found, usually indicating that the URL specifies a non-existant destination or file
 * "405"   - Method Not Supported, indicating that the HTTP request specified a method not supported by the web server

The "default" key specifies a "500" error, which indicates a "Internal Server Error", in this case because an error condition occurred for which there is no handler.

You can provide your own handler by specifying a function for the desired error condition.  The function should expect three arguments:
 * method  - the method for the HTTP request
 * path    - the full path, including any GET query items
 * headers - a table containing key-value pairs for the HTTP request headers

If you override the default handler, the function should expect four arguments:  the error code as a string, followed by the same three arguments defined above.

In either case, the function should return three values:
 * body    - the content to be returned, usually HTML for a basic error description page
 * code    - a 3 digit integer specifying the HTTP Response status (see https://en.wikipedia.org/wiki/List_of_HTTP_status_codes)
 * headers - a table containing any headers which should be included in the HTTP response.  Usually this will just be an empty table (e.g. {})

- - -

<a name="_supportMethods"></a>
~~~lua
hsminweb._supportMethods
~~~
Accessed as `object._supportMethods[method]`.  A table whose keyed entries specify whether or not a specified HTTP method is supported by this server.

The default methods supported internally are:
 * HEAD - an HTTP method which verifies whether or not a resource is available and it's last modified date
 * GET  - an HTTP method requesting content; the default method used by web browsers for bookmarks or URLs typed in by the user
 * POST - an HTTP method requesting content that includes content in the request body, most often used by forms to include user input or file data which may affect the content being returned.

These methods are included by default in this variable and are set to the boolean value true to indicate that they are supported and that the internal support code should be used.

You can assign a function to these methods if you wish for a custom handler to be invoked when the method is used in an HTTP request.  The function should accept five arguments:
 * self    - the `hsminwebTable` object representing the web server
 * method  - the method for the HTTP request
 * path    - the full path, including any GET query items
 * headers - a table containing the HTTP request headers
 * body    - the content of the request body, if available, otherwise nil.  Currently only the POST and PUT methods will contain a request body, but this may change in the future.

The function should return one or three values:
 * body    - the content to be returned.  If this is the boolean `false` or `nil`, then the request will fall through to the default handlers as if this function had never been called (this can be used in cases where you want to override the default behavior only for certain requests based on header or path details)
 * code    - a 3 digit integer specifying the HTTP Response status (see https://en.wikipedia.org/wiki/List_of_HTTP_status_codes)
 * headers - a table containing any headers which should be included in the HTTP response.  If `Server` or `Last-Modified` are not present, they will be provided automatically.

If you assign `false` to a method, then any request utilizing that method will return a status of 405 (Method Not Supported).  E.g. `object._supportMethods["POST"] = false` will prevent the POST method from being supported.

There are some functions and conventions used within this module which can simplify generating appropriate content within your custom functions.  Currently, you should review the module source, but a companion document describing these functions and conventions is expected to follow in the near future.

Common HTTP request methods can be found at https://en.wikipedia.org/wiki/Hypertext_Transfer_Protocol#Request_methods and https://en.wikipedia.org/wiki/WebDAV.  Currently, only HEAD, GET, and POST have built in support, so even if you set other methods to `true`, they will return a statuc code of 405 (Method Not Supported).  You must provide your own function, at present, if you wish to support additional methods.
A companion module supporting the methods required for WebDAV is being considered.

### Module Constants

<a name="dateFormatString"></a>
~~~lua
hsminweb.dateFormatString
~~~
A format string, usable with `os.date`, which will display a date in the format expected for HTTP communications as described in RFC 822, updated by RFC 1123.

### License

> The MIT License (MIT)
>
> Copyright (c) 2016 Aaron Magill
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
>
>The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
