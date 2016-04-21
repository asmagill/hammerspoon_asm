hs._asm.hsminweb
================

*This documentation is preliminary and is subject to change.*

Most notably:
 * POST support is incomplete for Lua Template pages.
 * documentation on writing custom functions for the various HTTP methods and support variables available is lacking.

- - -

Minimalist Web Server for Hammerspoon

This module aims to be a minimal, but (mostly) standards-compliant web server for use within Hammerspoon.  Expanding upon the Hammerspoon module, `hs.httpserver`, this module adds support for serving static pages stored at a specified document root as well as serving dynamic content from user defined functions, lua files interpreted within the Hammerspoon environment, and external executables which support the CGI/1.1 framework.

This module aims to provide a fully functional, and somewhat extendable, web server foundation, but will never replace a true dedicated web server application.  Some limitations include:
 * It is single threaded within the Hammerspoon environment and can only serve one resource at a time
 * As with all Hammerspoon modules, while dynamic content is being generated, Hammerspoon cannot respond to other callback functions -- a complex or time consuming script may block other Hammerspoon activity in a noticeable manner.
 * All document requests and responses are handled in memory only -- because of this, maximum resource size is limited to what you are willing to allow Hammerspoon to consume and memory limitations of your computer.

While some of these limitations may be mitigated to an extent in the future with additional modules and additions to `hs.httpserver`, Hammerspoon's web serving capabilities will never replace a dedicated web server when volume or speed is required.

An example web site is provided in the `hsdocs` folder.  This web site can serve documentation for Hammerspoon dynamically generated from the json file included with the Hammerspoon application for internal documentation.  It serves as a basic example of what is possible with this module.

You can start this web server by typing the following into your Hammerspoon console:
`require("hs._asm.hsminweb.hsdocs").start()`

Now, type `http://localhost:12345/` into your web browser.  The markdown conversion is still rough, but the documentation should be presented in a format similar to that as provided in the Hammerspoon docset for Dash.

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

- - -

<a name="urlParts"></a>
~~~lua
hsminweb.urlParts(url) -> table
~~~
Parse the specified URL into it's constituant parts.

Parameters:
 * url - the url to parse

Returns:
 * a table containing the constituant parts of the provided url.  The table will contain one or more of the following key-value pairs:
   * fragment           - the anchor name a URL refers to within an HTML document.  Appears after '#' at the end of a URL.  Note that not all web clients include this in an HTTP request since its normal purpose is to indicate where to scroll to within a page after the content has been retrieved.
   * host               - the host name portion of the URL, if any
   * lastPathComponent  - the last component of the path portion of the URL
   * password           - the password specified in the URL.  Note that this is not the password that would be entered when using Basic or Digest authentication; rather it is a password included in the URL itself -- for security reasons, use of this field has been deprecated in most situations and modern browsers will often prompt for confirmation before allowing URL's which contain a password to be transmitted.
   * path               - the full path specified in the URL
   * pathComponents     - an array containing the path components as individual strings.  Components which specify a sub-directory of the path will end with a "/" character.
   * pathExtension      - if the final component of the path refers to a file, the file's extension, if any.
   * port               - the port specified in the URL, if any
   * query              - the portion of the URL after a '?' character, if any; used to contain query information often from a form submitting it's input with the GET method.
   * resourceSpecifier  - the portion of the URL after the scheme
   * scheme             - the URL scheme; for web traffic, this will be "http" or "https"
   * standardizedURL    - the URL with any path components of ".." or "." normalized.  The use of ".." that would cause the URL to refer to something preceding its root is simply removed.
   * URL                - the URL as it was provided to this function (no changes)
   * user               - the user name specified in the URL.  Note that this is not the user name that would be entered when using Basic or Digest authentication; rather it is a user name included in the URL itself -- for security reasons, use of this field has been deprecated in most situations and modern browsers will often prompt for confirmation before allowing URL's which contain a user name to be transmitted.

Notes:
 * This function differs from the similar function `hs.http.urlParts` in a few ways:
   * To simplify the logic used by this module to determine if a request for a directory is properly terminated with a "/", the path components returned by this function do not remove this character from the component, if present.
   * Some extraneous or duplicate keys have been removed.
   * This function is patterned after RFC 3986 while `hs.http.urlParts` uses OS X API functions which are patterned after RFC 1808. RFC 3986 obsoletes 1808.  The primary distinction that affects this module is in regards to `parameters` for path components in the URI -- RFC 3986 disallows them in schema based URI's (like the URL's that are used for web based traffic).

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
     * header     - a string value matching the name of a header.  While the header name must match exactly, the comparison is case-insensitive (i.e. "X-Remote-addr" and "x-remote-addr" will both match the actual header name used, which is "X-Remote-Addr").
     * value      - a string value specifying the value to compare the header key's value to.
     * isPattern  - a boolean indicating whether or not the header key's value should be compared to `value` as a pattern match (true) -- see Lua documentation 6.4.1, `help.lua._man._6_4_1` in the console, or as an exact match (false)
     * isAccepted - a boolean indicating whether or not a match should be accepted (true) or rejected (false)
   * A special entry of the form { '\*', '\*', '\*', true } accepts all further requests and can be used as the final entry if you wish for the access list to function as a list of requests to reject, but to accept any requests which do not match a previous test.
   * A special entry of the form { '\*', '\*', '\*', false } rejects all further requests and can be used as the final entry if you wish for the access list to function as a list of requests to accept, but to reject any requests which do not match a previous test.  This is the implicit "default" final test if a table is assigned with the access-list method and does not actually need to be specified, but is included for completeness.
   * Note that any entry after an entry in which the first two parameters are equal to '\*' will never actually be used.

 * The tests are performed in order; if you wich to allow one IP address in a range, but reject all others, you should list the accepted IP addresses first. For example:
    ~~~
    {
       { 'X-Remote-Addr', '192.168.1.100',  false, true },  -- accept requests from 192.168.1.100
       { 'X-Remote-Addr', '^192%.168%.1%.', true,  false }, -- reject all others from the 192.168.1 subnet
       { '*',             '*',              '*',   true }   -- accept all other requests
    }
    ~~~

 * Most of the headers available are provided by the requesting web browser, so the exact headers available will vary.  You can find some information about common HTTP request headers at: https://en.wikipedia.org/wiki/List_of_HTTP_header_fields.

 * The following headers are inserted automatically by `hs.httpserver` and are probably the most useful for use in an access list:
   * X-Remote-Addr - the remote IPv4 or IPv6 address of the machine making the request,
   * X-Remote-Port - the TCP port of the remote machine where the request originated.
   * X-Server-Addr - the server IPv4 or IPv6 address that the web server received the request from.  For machines with multiple interfaces, this will allow you to determine which interface the request was received on.
   * X-Server-Port - the TCP port of the web server that received the request.

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

<a name="luaTemplateExtension"></a>
~~~lua
hsminweb:luaTemplateExtension([string]) -> hsminwebTable | current-value
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

<a name="queryLogging"></a>
~~~lua
hsminweb:queryLogging([flag]) -> hsminwebTable | current-value
~~~
Get or set the whether or not requests to this web server are logged.

Parameters:
 * flag - an optional boolean, defaults to false, indicating whether or not query requests are logged.

Returns:
 * the hsminwebTable object if a parameter is provided, or the current value if no parameter is specified.

Notes:
 * If logging is enabled, an Apache common style log entry is appended to [self._accesslog](#_accessLog) for each request made to the web server.
 * Error messages during content generation are always logged to the Hammerspoon console via the `hs.logger` instance saved to [hs._asm.hsminweb.log](#log).

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

<a name="_accessLog"></a>
~~~lua
hsminweb._accessLog
~~~
Accessed as `self._accessLog`.  If query logging is enabled for the web server, an Apache style common log entry will be appended to this string for each request.  See [hs._asm.hsminweb:queryLogging](#queryLogging).

- - -

<a name="_errorHandlers"></a>
~~~lua
hsminweb._errorHandlers
~~~
Accessed as `self._errorHandlers[errorCode]`.  A table whose keyed entries specify the function to generate the error response page for an HTTP error.

HTTP uses a three digit numeric code for error conditions.  Some servers have introduced subcodes, which are appended as a decimal added to the error condition.

You can assign your own handler to customize the response for a specific error code by specifying a function for the desired error condition as the value keyed to the error code as a string key in this table.  The function should expect three arguments:
 * method  - the method for the HTTP request
 * path    - the full path, including any GET query items
 * headers - a table containing key-value pairs for the HTTP request headers

If you override the default handler, "default", the function should expect four arguments instead:  the error code as a string, followed by the same three arguments defined above.

In either case, the function should return three values:
 * body    - the content to be returned, usually HTML for a basic error description page
 * code    - a 3 digit integer specifying the HTTP Response status (see https://en.wikipedia.org/wiki/List_of_HTTP_status_codes)
 * headers - a table containing any headers which should be included in the HTTP response.

- - -

<a name="_serverAdmin"></a>
~~~lua
hsminweb._serverAdmin
~~~
Accessed as `self._serverAdmin`.  A string containing the administrator for the web server.  Defaults to the currently logged in user's short form username and the computer's localized name as returned by `hs.host.localizedName()` (e.g. "user@computer").

This value is often used in error messages or on error pages indicating a point of contact for administrative help.  It can be accessed from within helper functions as `headers._.serverAdmin`.

- - -

<a name="_supportMethods"></a>
~~~lua
hsminweb._supportMethods
~~~
Accessed as `self._supportMethods[method]`.  A table whose keyed entries specify whether or not a specified HTTP method is supported by this server.

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

If you assign `false` to a method, then any request utilizing that method will return a status of 405 (Method Not Supported).  E.g. `self._supportMethods["POST"] = false` will prevent the POST method from being supported.

There are some functions and conventions used within this module which can simplify generating appropriate content within your custom functions.  Currently, you should review the module source, but a companion document describing these functions and conventions is expected to follow in the near future.

Common HTTP request methods can be found at https://en.wikipedia.org/wiki/Hypertext_Transfer_Protocol#Request_methods and https://en.wikipedia.org/wiki/WebDAV.  Currently, only HEAD, GET, and POST have built in support for static pages; even if you set other methods to `true`, they will return a status code of 405 (Method Not Supported) if the request does not invoke a CGI file for dynamic content.

A companion module supporting the methods required for WebDAV is being considered.

- - -

<a name="log"></a>
~~~lua
hsminweb.log
~~~
The `hs.logger` instance for the `hs._asm.hsminweb` module. See the documentation for `hs.logger` for more information.

### Module Constants

<a name="dateFormatString"></a>
~~~lua
hsminweb.dateFormatString
~~~
A format string, usable with `os.date`, which will display a date in the format expected for HTTP communications as described in RFC 822, updated by RFC 1123.

- - -

<a name="statusCodes"></a>
~~~lua
hsminweb.statusCodes
~~~
HTTP Response Status Codes

This table contains a list of common HTTP status codes identified from various sources (see Notes below). Because some web servers append a subcode after the official HTTP status codes, the keys in this table are the string representation of the numeric code so a distinction can be made between numerically "identical" keys (for example, "404.1" and "404.10").  You can reference this table with a numeric key, however, and it will be converted to its string representation internally.

Notes:
 * The keys and labels in this table have been combined from a variety of sources including, but not limited to:
   * "Official" list at https://en.wikipedia.org/wiki/List_of_HTTP_status_codes
   * KeplerProject's wsapi at https://github.com/keplerproject/wsapi
   * IIS additions from https://support.microsoft.com/en-us/kb/943891
 * This table has metatable additions which allow you to review its contents from the Hammerspoon console by typing `hs._asm.hsminweb.statusCodes`

* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

hs._asm.hsminweb.cgilua
=======================

This file contains functions which attempt to mimic as closely as possible the functions available to lua template files in the CGILua module provided by the Kepler Project at http://keplerproject.github.io/cgilua/index.html

Because of the close integration with Hammerspoon and the hs._asm.hsminweb module that I am attempting to provide with this, I decided that it was easier to "replicate" the functionality of some of the CGILua functions, rather than attempt to bridge the differences between how CGILua and Hammerspoon/this module handle their implementation of the HTTP protocol.

The goal of this file is to provide most of the same functionality that CGILua does to template files. Any differences in the results or errors are most likely due to my code and you should direct all error reports or code change suggestions to the hs._asm.hsminweb github repository at https://github.com/asmagill/hammerspoon_asm, rather than the Kepler Project.

### Usage
This module is included in a Lua template file's environment automatically -- you should not explicitly `require` it in your code.

### Module Functions

<a name="contentheader"></a>
~~~lua
cgilua.contentheader(maintype, subtype) -> none
~~~
Sets the HTTP response type for the content being generated to maintype/subtype.

Parameters:
 * maintype - the primary content type (e.g. "text")
 * subtype  - the sub-type for the content (e.g. "plain")

Returns:
 * None

Notes:
 * This sets the `Content-Type` header field for the HTTP response being generated.  This will override any previous setting, including the default of "text/html".

- - -

<a name="doif"></a>
~~~lua
cgilua.doif(filename) -> results
~~~
Executes a lua file (given by filepath) if it exists.

Parameters:
 * filepath - the file to interpret as Lua code

Returns:
 * the values returned by the execution, or nil followed by an error message if the file does not exists.

Notes:
 * This function only interprets the file if it exists; if the file does not exist, it returns an error to the calling code (not the web client)
 * During the processing of a web request, the local directory is temporarily changed to match the local directory of the path of the file being served, as determined by the URL of the request.  This is usually different than the Hammerspoon default directory which corresponds to the directory which contains the `init.lua` file for Hammerspoon.

- - -

<a name="doscript"></a>
~~~lua
cgilua.doscript(filename) -> results
~~~
Executes a lua file (given by filepath).

Parameters:
 * filepath - the file to interpret as Lua code

Returns:
 * the values returned by the execution, or nil followed by an error message if the file does not exists.

Notes:
 * If the file does not exist, an Internal Server error is returned to the client and an error is logged to the Hammerspoon console.
 * During the processing of a web request, the local directory is temporarily changed to match the local directory of the path of the file being served, as determined by the URL of the request.  This is usually different than the Hammerspoon default directory which corresponds to the directory which contains the `init.lua` file for Hammerspoon.

- - -

<a name="errorlog"></a>
~~~lua
cgilua.errorlog(msg) -> nil
~~~
Sends the message to the `hs._asm.hsminweb` log, tagged as an error.

Parameters:
 * msg - the message to send to the module's error log

Returns:
 * None

Notes:
 * Available within a lua template file as `cgilua.errorlog`
 * By default, messages logged with this method will appear in the Hammerspoon console and are available in the `hs.logger` history.

- - -

<a name="header"></a>
~~~lua
cgilua.header(key, value) -> none
~~~
Sets the HTTP response header `key` to `value`

Parameters:
 * key - the HTTP response header to set a value to.  This should be a string.
 * value - the value for the header.  This should be a string or a value representable as a string.

Returns:
 * None

Notes:
 * You should not use this function to set the value for the "Content-Type" key; instead use [cgilua.contentheader](#contentheader) or [cgilua.htmlheader](#htmlheader).

- - -

<a name="htmlheader"></a>
~~~lua
cgilua.htmlheader() -> none
~~~
Sets the HTTP response type to "text/html"

Parameters:
 * None

Returns:
 * None

Notes:
 * This sets the `Content-Type` header field for the HTTP response being generated to "text/html".  This is the default value, so generally you should not need to call this function unless you have previously changed it with the [cgilua.contentheader](#contentheader) function.

- - -

<a name="mkabsoluteurl"></a>
~~~lua
cgilua.mkabsoluteurl(uri) -> string
~~~
Returns an absolute URL for the given URI by prepending the path with the scheme, hostname, and port of this web server.

Parameters:
 * URI - A path to a resource served by this web server.  A "/" will be prepended to the path if it is not present.

Returns:
 * An absolute URL for the given path of the form "scheme://hostname:port/path" where `scheme` will be either "http" or "https", and the hostname and port will match that of this web server.

Notes:
 * If you wish to append query items to the path or expand a relative path into it's full path, see [cgilua.mkurlpath](#mkurlpath).

- - -

<a name="mkurlpath"></a>
~~~lua
cgilua.mkurlpath(uri, [args]) -> string
~~~
Creates a full document URI from a partial URI, including query arguments if present.

Parameters:
 * uri  - the full or partial URI (path and file component of a URL) of the document
 * args - an optional table which should have key-value pairs that will be encoded to form a valid query at the end of the URI (see [cgilua.urlcode.encodetable](#encodetable).

Returns:
 * A full URI including any query arguments, if present.

Notes:
 * This function is intended to be used in conjunction with [cgilua.mkabsoluteurl](#mkabsoluteurl) to generate a full URL.  If the `uri` provided does not begin with a "/", then the current directory path is prepended to the uri and any query arguments are appended.
 * e.g. `cgilua.mkabsoluteurl(cgiurl.mkurlpath("file.lp", { key = value, ... }))` will return a full URL specifying the file `file.lp` in the current directory with the specified key-value pairs as query arguments.

- - -

<a name="print"></a>
~~~lua
cgilua.print(...) -> nil
~~~
Appends the given arguments to the response body.

Parameters:
 * ... - a list of comma separated arguments to add to the response body

Returns:
 * None

Notes:
 * Available within a lua template file as `cgilua.print`
 * This function works like the lua builtin `print` command in that it converts all its arguments to strings, separates them with tabs (`\t`), and ends the line with a newline (`\n`) before appending them to the current response body.

- - -

<a name="put"></a>
~~~lua
cgilua.put(...) -> nil
~~~
Appends the given arguments to the response body.

Parameters:
 * ... - a list of comma separated arguments to add to the response body

Returns:
 * None

Notes:
 * Available within a lua template file as `cgilua.put`
 * This function works by flattening tables and converting all values except for `nil` and `false` to their string representation and then appending them in order to the response body. Unlike `cgilua.print`, it does not separate values with a tab character or terminate the line with a newline character.

- - -

<a name="redirect"></a>
~~~lua
cgilua.redirect(url, [args]) -> none
~~~
Sends the headers to force a redirection to the given URL adding the parameters in table args to the new URL.

Parameters:
 * url  - the URL the client should be redirected to
 * args - an optional table which should have key-value pairs that will be encoded to form a valid query at the end of the URL (see [cgilua.urlcode.encodetable](#encodetable).

Returns:
 * None

Notes:
 * This function should generally be followed by a `return` in your lua template page as no additional processing or output should occur when a request is to be redirected.

- - -

<a name="servervariable"></a>
~~~lua
cgilua.servervariable(varname) -> string
~~~
Returns a string with the value of the CGI environment variable correspoding to varname.

Parameters:
 * varname - the name of the CGI variable to get the value of.

Returns:
 * the value of the CGI variable as a string, or nil if no such variable exists.

Notes:
 * CGI Variables include server defined values commonly shared with CGI scripts and the HTTP request headers from the web request.  The server variables include the following (note that depending upon the request and type of resource the URL refers to, not all values may exist for every request):
   * "AUTH_TYPE"         - If the server supports user authentication, and the script is protected, this is the protocol-specific authentication method used to validate the user.
   * "CONTENT_LENGTH"    - The length of the content itself as given by the client.
   * "CONTENT_TYPE"      - For queries which have attached information, such as HTTP POST and PUT, this is the content type of the data.
   * "DOCUMENT_ROOT"     - the real directory on the server that corresponds to a DOCUMENT_URI of "/".  This is the first directory which contains files or sub-directories which are served by the web server.
   * "DOCUMENT_URI"      - the path portion of the HTTP URL requested
   * "GATEWAY_INTERFACE" - The revision of the CGI specification to which this server complies. Format: CGI/revision
   * "PATH_INFO"         - The extra path information, as given by the client. In other words, scripts can be accessed by their virtual pathname, followed by extra information at the end of this path. The extra information is sent as PATH_INFO. This information should be decoded by the server if it comes from a URL before it is passed to the CGI script.
   * "PATH_TRANSLATED"   - The server provides a translated version of PATH_INFO, which takes the path and does any virtual-to-physical mapping to it.
   * "QUERY_STRING"      - The information which follows the "?" in the URL which referenced this script. This is the query information. It should not be decoded in any fashion. This variable should always be set when there is query information, regardless of command line decoding.
   * "REMOTE_ADDR"       - The IP address of the remote host making the request.
   * "REMOTE_HOST"       - The hostname making the request. If the server does not have this information, it should set REMOTE_ADDR and leave this unset.
   * "REMOTE_IDENT"      - If the HTTP server supports RFC 931 identification, then this variable will be set to the remote user name retrieved from the server. Usage of this variable should be limited to logging only.
   * "REMOTE_USER"       - If the server supports user authentication, and the script is protected, this is the username they have authenticated as.
   * "REQUEST_METHOD"    - The method with which the request was made. For HTTP, this is "GET", "HEAD", "POST", etc.
   * "REQUEST_TIME"      - the time the server received the request represented as the number of seconds since 00:00:00 UTC on 1 January 1970.  Usable with `os.date` to provide the date and time in whatever format you require.
   * "REQUEST_URI"       - the DOCUMENT_URI with any query string present in the request appended.  Usually this corresponds to the URL without the scheme or host information.
   * "SCRIPT_FILENAME"   - the actual path to the script being executed.
   * "SCRIPT_NAME"       - A virtual path to the script being executed, used for self-referencing URLs.
   * "SERVER_NAME"       - The server's hostname, DNS alias, or IP address as it would appear in self-referencing URLs.
   * "SERVER_PORT"       - The port number to which the request was sent.
   * "SERVER_PROTOCOL"   - The name and revision of the information protcol this request came in with. Format: protocol/revision
   * "SERVER_SOFTWARE"   - The name and version of the web server software answering the request (and running the gateway). Format: name/version

* The HTTP Request header names are prefixed with "HTTP_", converted to all uppercase, and have all hyphens converted into underscores.  Common headers (converted to their CGI format) might include, but are not limited to:
   * HTTP_ACCEPT, HTTP_ACCEPT_ENCODING, HTTP_ACCEPT_LANGUAGE, HTTP_CACHE_CONTROL, HTTP_CONNECTION, HTTP_DNT, HTTP_HOST, HTTP_USER_AGENT
 * This server also defines the following (which are replicated in the CGI variables above, so those should be used for portability):
   * HTTP_X_REMOTE_ADDR, HTTP_X_REMOTE_PORT, HTTP_X_SERVER_ADDR, HTTP_X_SERVER_PORT
 * A list of common request headers and their definitions can be found at https://en.wikipedia.org/wiki/List_of_HTTP_header_fields

- - -

<a name="splitfirst"></a>
~~~lua
cgilua.splitfirst(path) -> path component, path remainder
~~~
Returns two strings with the "first directory" and the "remaining paht" of the given path string splitted on the first separator ("/" or "\").

Parameters:
 * path - the path to split

Returns:
 * the first directory component, the remainder of the path

- - -

<a name="splitonlast"></a>
~~~lua
cgilua.splitonlast(path) -> directory, file
~~~
Returns two strings with the "directory path" and "file" parts of the given path string splitted on the last separator ("/" or "\").

Parameters:
 * path - the path to split

Returns:
 * the directory path, the file

Notes:
 * This function used to be called cgilua.splitpath and still can be accessed by this name for compatibility reasons. cgilua.splitpath may be deprecated in future versions.

- - -

<a name="tmpfile"></a>
~~~lua
cgilua.tmpfile([dir], [namefunction]) -> file[, err]
~~~
Returns the file handle to a temporary file for writing, or nil and an error message if the file could not be created for any reason.

Parameters:
 * dir          - the system directory where the temporary file should be created.  Defaults to `cgilua.tmp_path`.
 * namefunction - an optional function used to generate unique file names for use as temporary files.  Defaults to `cgilua.tmpname`.

Returns:
 * the created file's handle and the filename or nil and an error message if the file could not be created.

Notes:
 * The file is automatically deleted when the HTTP request has been completed, so if you need for the data to persist, make sure to `io.flush` or `io.close` the file handle yourself and copy the file to a more permanent location.

- - -

<a name="tmpname"></a>
~~~lua
cgilua.tmpname() -> string
~~~
Returns a temporary file name used by `cgilua.tmpfile`.

Parameters:
 * None

Returns:
 * a temporary filename, without the path.

Notes:
 * This function uses `hs.host.globallyUniqueString` to generate a unique file name.

### Module Variables

<a name="script_file"></a>
~~~lua
cgilua.script_file
~~~
The file name of the running script. Obtained from cgilua.script_path.

Notes:
 * CGILua supports being invoked through a URL that amounts to set of chained paths and script names; this is not necessary for this module, so these variables may differ somewhat from a true CGILua installation; the intent of the variable has been maintained as closely as I can determine at present.  If this changes, so will this documentation.

- - -

<a name="script_path"></a>
~~~lua
cgilua.script_path
~~~
The system path of the running script. Equivalent to the CGI environment variable SCRIPT_FILENAME.

Notes:
 * CGILua supports being invoked through a URL that amounts to set of chained paths and script names; this is not necessary for this module, so these variables may differ somewhat from a true CGILua installation; the intent of the variable has been maintained as closely as I can determine at present.  If this changes, so will this documentation.

- - -

<a name="script_pdir"></a>
~~~lua
cgilua.script_pdir
~~~
The directory of the running script. Obtained from cgilua.script_path.

Notes:
 * CGILua supports being invoked through a URL that amounts to set of chained paths and script names; this is not necessary for this module, so these variables may differ somewhat from a true CGILua installation; the intent of the variable has been maintained as closely as I can determine at present.  If this changes, so will this documentation.

- - -

<a name="script_vdir"></a>
~~~lua
cgilua.script_vdir
~~~
If PATH_INFO represents a directory (i.e. ends with "/"), then this is equal to `cgilua.script_vpath`.  Otherwise, this contains the directory portion of `cgilua.script_vpath`.

Notes:
 * CGILua supports being invoked through a URL that amounts to set of chained paths and script names; this is not necessary for this module, so these variables may differ somewhat from a true CGILua installation; the intent of the variable has been maintained as closely as I can determine at present.  If this changes, so will this documentation.

- - -

<a name="script_vpath"></a>
~~~lua
cgilua.script_vpath
~~~
Equivalent to the CGI environment variable PATH_INFO or "/", if no PATH_INFO is set.

Notes:
 * CGILua supports being invoked through a URL that amounts to set of chained paths and script names; this is not necessary for this module, so these variables may differ somewhat from a true CGILua installation; the intent of the variable has been maintained as closely as I can determine at present.  If this changes, so will this documentation.

- - -

<a name="tmp_path"></a>
~~~lua
cgilua.tmp_path
~~~
The directory used by `cgilua.tmpfile`

This variable contains the location where temporary files should be created.  Defaults to the user's temporary directory as returned by `hs.fs.temporaryDirectory`.

- - -

<a name="urlpath"></a>
~~~lua
cgilua.urlpath
~~~
The name of the script as requested in the URL. Equivalent to the CGI environment variable SCRIPT_NAME.

Notes:
 * CGILua supports being invoked through a URL that amounts to set of chained paths and script names; this is not necessary for this module, so these variables may differ somewhat from a true CGILua installation; the intent of the variable has been maintained as closely as I can determine at present.  If this changes, so will this documentation.

* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

hs._asm.hsminweb.cgilua.lp
==========================

Support functions for the CGILua compatibility module for including and translating Lua template pages into Lua code for execution within the Hammerspoon environment to provide dynamic content for http requests.

The most commonly used function is likely to be [cgilua.lp.include](#include), which allows including a template driven file during rendering so that common code can be reused more easily.  While passing in your own environment table for upvalues is possible, this is not recommended for general use because the default environment passed to each included file ensures that all server variables and the CGILua compatibility functions are available with the same names, and any new non-local (i.e. "global") variable defined are shared with the calling environment and not shared with the Hammerspoon global environment.

If your template file requires the ability to create variables in the Hammerspoon global environment, access the global environment directly through `_G`.

Note that the above considerations only apply to creating new "global" variables.  Any currently defined global variables (for example, the `hs` table where Hammerspoon module functions are stored) are available within the template file as long as no local or CGILua environment variable shares the same name (e.g. `_G["hs"]` and `hs` refer to the same table.

See the documentation for the [cgilua.lp.include](#include) for more information.

### Usage
This module is included in a Lua template file's environment automatically -- you should not explicitly `require` it in your code.

### Module Functions

<a name="compile"></a>
~~~lua
cgilua.lp.compile(source, name, [env]) -> function
~~~
Converts the specified Lua template source into a Lua function.

Parameters:
 * source - a string containing the contents of a Lua/HTML template to be converted into a function
 * name   - a label used in an error message if execution of the returned function results in a run-time error
 * env    - an optional table specifying the environment to be used by the lua builtin function `load` when converting the source into a function.  By default, the function will inherit its caller's environment.

Returns:
 * A lua function which should take no arguments.

Notes:
 * The source provided is first compared to a stored cache of previously translated templates and will re-use an existing translation if the template has been seen before.  If the source is unique, [cgilua.lp.translate](#translate) is called on the template source.
 * This function is used internally by [cgilua.lp.include](#include), and probably won't be useful unless you want to translate a dynamically generated template -- which has security implications, depending upon what inputs you use to generate this template, because the resulting Lua code will execute within your Hammerspoon environment.  Be very careful about your inputs if you choose to ignore this warning.

- - -

<a name="include"></a>
~~~lua
cgilua.lp.include(file, [env]) -> none
~~~
Includes the template specified by the `file` parameter.

Parameters:
 * file - a string containing the file system path to the template to include.
 * env  - an optional table specifying the environment to be used by the included template.  By default, the template will inherit its caller's environment.

Returns:
 * None

Notes:
* This function is called by the web server to process the template specified by the requested URL.  Subsequent invocations of this function can be used to include common or re-used code from other template files and will be included in-line where the `cgilua.lp.include` function is invoked in the originating template.
 * During the processing of a web request, the local directory is temporarily changed to match the local directory of the path of the file being served, as determined by the URL of the request.  This is usually different than the Hammerspoon default directory which corresponds to the directory which contains the `init.lua` file for Hammerspoon.

* The default template environment provides the following:
  * the `__index` metamethod points to the `_G` environment variable in the Hammerspoon Lua instance; this means that any global variable in the Hammerspoon environment is available to the lua code in a template file.
  * the `__newindex` metamethod points to a function which creates new "global" variables in the template files environment; this means that if a template includes another template file, and that second template file creates a "global" variable, that new variable will be available in the environment of the calling template, but will not be shared with the Hammerspoon global variable space;  "global" variables created in this manner will be released when the HTTP request is completed.

  * `print` is overridden so that its output is streamed into the response body to be returned when the web request completes.  It follows the traditional pattern of the `print` builtin function: multiple arguments are separated by a tab character, the output is terminated with a new-line character, non-string arguments are converted to strings via the `tostring` builtin function.
  * `write` is defined as an alternative to `print` and differs in the following ways from the `print` function described above:  no intermediate tabs or newline are included in the output streamed to the response body.
  * `cgilua` is defined as a table containing all of the functions included in this support sub-module.
  * `hsminweb` is defined as a table which contains the following tables which may be of use:
    * CGIVariables - a table containing key-value pairs of the same data available through the [cgilua.servervariable](#servervariable) function.
    * id           - a string, generated via `hs.host.globallyUniqueString`, unique to this specific HTTP request.
    * log          - a table/object representing the `hs._asm.hsminweb` instance of `hs.logger`.  This can be used to log messages to the Hammerspoon console as described in the documentation for `hs.logger`.
    * request      - a table containing data representing the details of the HTTP request as it was made by the web client to the server.  The following keys are commonly found:
      * headers - a table containing key-value pairs representing the headers included in the HTTP request; unlike the values available through [cgilua.servervariable](#servervariable) or found in `CGIVariables`, these are available in their raw form.
        * this table also contains a table with the key "_".  This table contains functions and data used internally, and is described more fully in a supporting document (TBD).  It is targeted primarily at custom functions designed for use with `hs._asm.hsminweb` directly and should not generally be necessary for Lua template files.
      * method  - the method of the HTTP request, most commonly "GET" or "POST"
      * path    - the path portion of the requested URL.
    * response     - a table containing data representing the response being formed for the response to the HTTP request.  This is generally handled for you by the `cgilua` support functions, but for special cases, you can modify it directly; this should contain only the following keys:
      * body    - a string containing the response body.  As the lua template outputs content, this string is appended to.
      * code    - an integer representing the currently expected response code for the HTTP request.
      * headers - a table containing key-value pairs of the currently defined response headers
    * server       - a reference to the table/object representing the web server instance serving this HTTP request.
    * _tmpfiles    - used internally to track temporary files used in the completion of this HTTP request; do not modify directly.

- - -

<a name="translate"></a>
~~~lua
cgilua.lp.translate(source) -> luaCode
~~~
Converts the specified Lua template source into Lua code executable within the Hammerspoon environment.

Parameters:
 * source - a string containing the contents of a Lua/HTML template to be converted into true Lua code

Returns:
 * The lua code corresponding to the provided source which can be fed into the `load` lua builtin to generate a Lua function.

Notes:
 * This function is used internally by [cgilua.lp.include](#include), and probably won't be useful unless you want to translate a dynamically generated template -- which has security implications, depending upon what inputs you use to generate this template, because the resulting Lua code will execute within your Hammerspoon environment.  Be very careful about your inputs if you choose to ignore this warning.
 * To ensure that the translated code has access to the `cgilua` support functions, pass `_ENV` as the environment argument to the `load` lua builtin; otherwise any output generated by the resulting function will be sent to the Hammerspoon console and not included in the HTTP response sent back to the client.

* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

hs._asm.hsminweb.cgilua.urlcode
===============================

Support functions for the CGILua compatibility module for encoding and decoding URL components in accordance with RFC 3986.

### Usage
This module is included in a Lua template file's environment automatically -- you should not explicitly `require` it in your code.

### Module Functions

<a name="encodetable"></a>
~~~lua
cgilua.urlcode.encodetable(table) -> string
~~~
Encodes the table of key-value pairs as a query string suitable for inclusion in a URL.

Parameters:
 * table - a table of key-value pairs to be converted into a query string

Returns:
 * a query string as specified in RFC 3986.

Notes:
 * the string will be of the form: "key1=value1&key2=value2..." where all of the keys and values are properly escaped using [cgilua.urlcode.escape](#escape).  If you are crafting a URL by hand, the result of this function should be appended to the end of the URL after a "?" character to specify where the query string begins.

- - -

<a name="escape"></a>
~~~lua
cgilua.urlcode.escape(string) -> string
~~~
URL encodes the provided string, making it safe as a component within a URL.

Parameters:
 * string - the string to encode

Returns:
 * a string with non-alphanumeric characters percent encoded and spaces converted into "+" as per RFC 3986.

Notes:
 * this function assumes that the provided string is a single component and URL encodes *all* non-alphanumeric characters.  Do not use this function to generate a URL query string -- use [cgilua.urlcode.encodetable](#encodetable).

- - -

<a name="insertfield"></a>
~~~lua
cgilua.urlcode.insertfield(table, key, value) -> none
~~~
Inserts the specified key and value into the table of key-value pairs.

Parameters:
 * table - the table of arguments being built
 * key   - the key name
 * value - the value to assign to the key specified

Returns:
 * None

Notes:
 * If the key already exists in the table, its value is converted to a table (if it isn't already) and the new value is added to the end of the array of values for the key.
 * This function is used internally by [cgilua.urlcode.parsequery](#parsequery) or can be used to prepare a table of key-value pairs for [cgilua.urlcode.encodetable](#encodetable).

- - -

<a name="parsequery"></a>
~~~lua
cgilua.urlcode.parsequery(query, table) -> none
~~~
Parse the query string and store the key-value pairs in the provided table.

Parameters:
 * query - a URL encoded query string, either from a URL or from the body of a POST request encoded in the "x-www-form-urlencoded" format.
 * table - the table to add the key-value pairs to

Returns:
 * None

Notes:
 * The specification allows for the same key to be assigned multiple values in an encoded string, but does not specify the behavior; by convention, web servers assign these multiple values to the same key in an array (table).  This function follows that convention.  This is most commonly used by forms which allow selecting multiple options via check boxes or in a selection list.
 * This function uses [cgilua.urlcode.insertfield](#insertfield) to build the key-value table.

- - -

<a name="unescape"></a>
~~~lua
cgilua.urlcode.unescape(string) -> string
~~~
Removes any URL encoding in the provided string.

Parameters:
 * string - the string to decode

Returns:
 * a string with all "+" characters converted to spaces and all percent encoded sequences converted to their ascii equivalents.


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

Portions of this module are derived or inspired by the [Kepler Project's CGILua](http://keplerproject.github.io/cgilua/index.html), which is licensed as follows:

> Copyright © 2003 Kepler Project.
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Support script `timeout3` is licensed under the GPL v3 license. See [LICENSE.timeout3](LICENSE.timeout3) for the license description.
