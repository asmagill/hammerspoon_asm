hs.spotlight
============

This module allows Hammerspoon to preform Spotlight metadata queries.

This module will only be able to perform queries on volumes and folders which are not blocked by the Privacy settings in the System Preferences Spotlight panel.

A Spotlight query consists of two phases: an initial gathering phase where information currently in the Spotlight database is collected and returned, and a live-update phase which occurs after the gathering phase and consists of changes made to the Spotlight database, such as new entries being added, information in existing entries changing, or entities being removed.

Depending upon the callback messages enabled with the [hs.spotlight:callbackMessages](#callbackMessages) method, your callback assigned with the [hs.spotlight:setCallback](#setCallback) method, you can determine the query phase by noting which messages you have received.  During the initial gathering phase, the following callback messages may be observed: "didStart", "inProgress", and "didFinish".  Once the initial gathering phase has completed, you will only observe "didUpdate" messages until the query is stopped with the [hs.spotlight:stop](#stop) method.

You can also check to see if the initial gathering phase is in progress with the [hs.spotlight:isGathering](#isGathering) method.

You can access the individual results of the query with the [hs.spotlight:resultAtIndex](#resultAtIndex) method. For convenience, metamethods have been added to the spotlightObject which make accessing individual results easier:  an individual spotlightItemObject may be accessed from a spotlightObject by treating the spotlightObject like an array; e.g. `spotlightObject[n]` will access the n'th spotlightItemObject in the current results.

### Installation

A precompiled version of this module can be found in this directory with a name along the lines of `spotlight-v0.x.tar.gz`. This can be installed by downloading the file and then expanding it as follows:

~~~sh
$ cd ~/.hammerspoon # or wherever your Hammerspoon init.lua file is located
$ tar -xzf ~/Downloads/spotlight-v0.x.tar.gz # or wherever your downloads are located
~~~

If you wish to build this module yourself, and have XCode installed on your Mac, the best way (you are welcome to clone the entire repository if you like, but no promises on the current state of anything) is to download `init.lua`, `internal.m`, and `Makefile` (at present, nothing else is required) into a directory of your choice and then do the following:

~~~sh
$ cd wherever-you-downloaded-the-files
$ [HS_APPLICATION=/Applications] [PREFIX=~/.hammerspoon] make install
~~~

If your Hammerspoon application is located in `/Applications`, you can leave out the `HS_APPLICATION` environment variable, and if your Hammerspoon files are located in their default location, you can leave out the `PREFIX` environment variable.  For most people it will be sufficient to just type `make install`.

As always, whichever method you chose, if you are updating from an earlier version it is recommended to fully quit and restart Hammerspoon after installing this module to ensure that the latest version of the module is loaded into memory.

### Usage
~~~lua
spotlight = require("hs.spotlight")
~~~

### Contents


##### Module Constructors
* <a href="#new">spotlight.new() -> spotlightObject</a>
* <a href="#newWithin">spotlight.newWithin(spotlightObject) -> spotlightObject</a>

##### Module Methods
* <a href="#callbackMessages">spotlight:callbackMessages([messages]) -> table | spotlightObject</a>
* <a href="#count">spotlight:count() -> integer</a>
* <a href="#groupedResults">spotlight:groupedResults() -> table</a>
* <a href="#groupingAttributes">spotlight:groupingAttributes([attributes]) -> table | spotlightObject</a>
* <a href="#isGathering">spotlight:isGathering() -> boolean</a>
* <a href="#isRunning">spotlight:isRunning() -> boolean</a>
* <a href="#queryString">spotlight:queryString(query) -> spotlightObject</a>
* <a href="#resultAtIndex">spotlight:resultAtIndex(index) -> spotlightItemObject</a>
* <a href="#searchScopes">spotlight:searchScopes([scope]) -> table | spotlightObject</a>
* <a href="#setCallback">spotlight:setCallback(fn | nil) -> spotlightObject</a>
* <a href="#sortDescriptors">spotlight:sortDescriptors([attributes]) -> table | spotlightObject</a>
* <a href="#start">spotlight:start() -> spotlightObject</a>
* <a href="#stop">spotlight:stop() -> spotlightObject</a>
* <a href="#updateInterval">spotlight:updateInterval([interval]) -> number | spotlightObject</a>
* <a href="#valueListAttributes">spotlight:valueListAttributes([attributes]) -> table | spotlightObject</a>
* <a href="#valueLists">spotlight:valueLists() -> table</a>

##### Module Constants
* <a href="#commonAttributeKeys">spotlight.commonAttributeKeys[]</a>
* <a href="#definedSearchScopes">spotlight.definedSearchScopes[]</a>

- - -

### Module Constructors

<a name="new"></a>
~~~lua
spotlight.new() -> spotlightObject
~~~
Creates a new spotlightObject to use for Spotlight searches.

Parameters:
 * None

Returns:
 * a new spotlightObject

- - -

<a name="newWithin"></a>
~~~lua
spotlight.newWithin(spotlightObject) -> spotlightObject
~~~
Creates a new spotlightObject that limits its searches to the current results of another spotlightObject.

Parameters:
 * `spotlightObject` - the object whose current results are to be used to limit the scope of the new Spotlight search.

Returns:
 * a new spotlightObject

### Module Methods

<a name="callbackMessages"></a>
~~~lua
spotlight:callbackMessages([messages]) -> table | spotlightObject
~~~
Get or specify the specific messages that should generate a callback.

Parameters:
 * `messages` - an optional table or list of items specifying the specific callback messages that will generate a callback.  Defaults to { "didFinish" }.

Returns:
 * if an argument is provided, returns the spotlightObject; otherwise returns the current values

Notes:
 * Valid messages for the table are: "didFinish", "didStart", "didUpdate", and "inProgress".  See [hs.spotlight:setCallback](#setCallback) for more details about the messages.

- - -

<a name="count"></a>
~~~lua
spotlight:count() -> integer
~~~
Returns the number of results for the spotlightObject's query

Parameters:
 * None

Returns:
 * if the query has collected results, returns the number of results that match the query; if the query has not been started, this value will be 0.

Notes:
 * Just because the result of this method is 0 does not mean that the query has not been started; the query itself may not match any entries in the Spotlight database.
 * A query which ran in the past but has been subsequently stopped will retain its queries unless the parameters have been changed.  The result of this method will indicate the number of results still attached to the query, even if it has been previously stopped.

 * For convenience, metamethods have been added to the spotlightObject which allow you to use `#spotlightObject` as a shortcut for `spotlightObject:count()`.

- - -

<a name="groupedResults"></a>
~~~lua
spotlight:groupedResults() -> table
~~~
Returns the grouped results for a Spotlight query.

Parameters:
 * None

Returns:
 * an array table containing the grouped results for the Spotlight query as specified by the [hs.spotlight:groupingAttributes](#groupingAttributes) method.  Each member of the array will be a spotlightGroupObject which is detailed in the `hs.spotlight.group` module documentation.

Notes:
 * The spotlightItemObjects available with the `hs.spotlight.group:resultAtIndex` method are the subset of the full results of the spotlightObject that match the attribute and value of the spotlightGroupObject.  The same item is available through the spotlightObject and the spotlightGroupObject, though likely at different indicies.

- - -

<a name="groupingAttributes"></a>
~~~lua
spotlight:groupingAttributes([attributes]) -> table | spotlightObject
~~~
Get or set the grouping attributes for the Spotlight query.

Parameters:
 * `attributes` - an optional table or list of items specifying the grouping attributes for the Spotlight query.  Defaults to an empty array.

Returns:
 * if an argument is provided, returns the spotlightObject; otherwise returns the current values

Notes:
 * Setting this property while a query is running stops the query and discards the current results. The receiver immediately starts a new query.
 * Setting this property will increase CPU and memory usage while performing the Spotlight query.

 * Thie method allows you to access results grouped by the values of specific attributes.  See `hs.spotlight.group` for more information on using and accessing grouped results.
 * Note that not all attributes can be used as a grouping attribute.  In such cases, the grouped result will contain all results and an attribute value of nil.

- - -

<a name="isGathering"></a>
~~~lua
spotlight:isGathering() -> boolean
~~~
Returns a boolean specifying whether or not the query is in the active gathering phase.

Parameters:
 * None

Returns:
 * a boolean value of true if the query is in the active gathering phase or false if it is not.

Notes:
 * An inactive query will also return false for this method since an inactive query is neither gathering nor waiting for updates.  To determine if a query is active or inactive, use the [hs.spotlight:isRunning](#isRunning) method.

- - -

<a name="isRunning"></a>
~~~lua
spotlight:isRunning() -> boolean
~~~
Returns a boolean specifying if the query is active or inactive.

Parameters:
 * None

Returns:
 * a boolean value of true if the query is active or false if it is inactive.

Notes:
 * An active query may be gathering query results (in the initial gathering phase) or listening for changes which should cause a "didUpdate" message (after the initial gathering phase). To determine which state the query may be in, use the [hs.spotlight:isGathering](#isGathering) method.

- - -

<a name="queryString"></a>
~~~lua
spotlight:queryString(query) -> spotlightObject
~~~
Specify the query string for the spotlightObject

Parameters:
 * a string containing the query for the spotlightObject

Returns:
 * the spotlightObject

Notes:
 * Setting this property while a query is running stops the query and discards the current results. The receiver immediately starts a new query.

 * The query string syntax is not simple enough to fully describe here.  It is a subset of the syntax supported by the Objective-C NSPredicate class.  Some references for this syntax can be found at:
   * https://developer.apple.com/library/content/documentation/Carbon/Conceptual/SpotlightQuery/Concepts/QueryFormat.html
   * https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/Predicates/Articles/pSyntax.html

 * If the query string does not conform to an NSPredicate query string, this method will return an error.  If the query string does conform to an NSPredicate query string, this method will accept the query string, but if it does not conform to the Metadata query format, which is a subset of the NSPredicate query format, the error will be generated when you attempt to start the query with [hs.spotlight:start](#start). At present, starting a query is the only way to fully guarantee that a query is in a valid format.

 * Some of the query strings which have been used during the testing of this module are as follows (note that [[ ]] is a Lua string specifier that allows for double quotes in the content of the string):
   * [[ kMDItemContentType == "com.apple.application-bundle" ]]
   * [[ kMDItemFSName like "*Explore*" ]]
   * [[ kMDItemFSName like "AppleScript Editor.app" or kMDItemAlternateNames like "AppleScript Editor"]]

 * Not all attributes appear to be usable in a query; see `hs.spotlight.item:attributes` for a possible explanation.

 * As a convenience, the __call metamethod has been setup for spotlightObject so that you can use `spotlightObject("query")` as a shortcut for `spotlightObject:queryString("query"):start`.  Because this shortcut includes an explicit start, this should be appended after you have set the callback function if you require a callback (e.g. `spotlightObject:setCallback(fn)("query")`).

- - -

<a name="resultAtIndex"></a>
~~~lua
spotlight:resultAtIndex(index) -> spotlightItemObject
~~~
Returns the spotlightItemObject at the specified index of the spotlightObject

Parameters:
 * `index` - an integer specifying the index of the result to return.

Returns:
 * the spotlightItemObject at the specified index or an error if the index is out of bounds.

Notes:
 * For convenience, metamethods have been added to the spotlightObject which allow you to use `spotlightObject[index]` as a shortcut for `spotlightObject:resultAtIndex(index)`.

- - -

<a name="searchScopes"></a>
~~~lua
spotlight:searchScopes([scope]) -> table | spotlightObject
~~~
Get or set the search scopes allowed for the Spotlight query.

Parameters:
 * `scope` - an optional table or list of items specifying the search scope for the Spotlight query.  Defaults to an empty array, specifying that the search is not limited in scope.

Returns:
 * if an argument is provided for `scope`, returns the spotlightObject; otherwise returns a table containing the current search scopes.

Notes:
 * Setting this property while a query is running stops the query and discards the current results. The receiver immediately starts a new query.

 * Each item listed in the `scope` table may be a string or a file URL table as described in documentation for the `hs.sharing.URL` and `hs.sharing.fileURL` functions.
   * if an item is a string and matches one of the values in the [hs.spotlight.definedSearchScopes](#definedSearchScopes) table, then the scope for that item will be added to the valid search scopes.
   * if an item is a string and does not match one of the predefined values, it is treated as a path on the local system and will undergo tilde prefix expansion befor being added to the search scopes (i.e. "~/" will be expanded to "/Users/username/").
   * if an item is a table, it will be treated as a file URL table.

- - -

<a name="setCallback"></a>
~~~lua
spotlight:setCallback(fn | nil) -> spotlightObject
~~~
Set or remove the callback function for the Spotlight search object.

Parameters:
 * `fn` - the function to replace the current callback function.  If this argument is an explicit nil, removes the current callback function and does not replace it.  The function should expect 2 or 3 arguments and should return none.

Returns:
 * the spotlightObject

Notes:
 * Depending upon the messages set with the [hs.spotlight:callbackMessages](#callbackMessages) method, the following callbacks may occur:

   * obj, "didStart" -- occurs when the initial gathering phase of a Spotlight search begins.
     * `obj`     - the spotlightObject performing the search
     * `message` - the message to the callback, in this case "didStart"

   * obj, "inProgress", updateTable -- occurs during the initial gathering phase at intervals set by the [hs.spotlight:updateInterval](#updateInterval) method.
     * `obj`         - the spotlightObject performing the search
     * `message`     - the message to the callback, in this case "inProgress"
     * `updateTable` - a table containing one or more of the following keys:
       * `kMDQueryUpdateAddedItems`   - an array table of spotlightItem objects that have been added to the results
       * `kMDQueryUpdateChangedItems` - an array table of spotlightItem objects that have changed since they were first added to the results
       * `kMDQueryUpdateRemovedItems` - an array table of spotlightItem objects that have been removed since they were first added to the results

   * obj, "didFinish" -- occurs when the initial gathering phase of a Spotlight search completes.
     * `obj`     - the spotlightObject performing the search
     * `message` - the message to the callback, in this case "didFinish"

   * obj, "didUpdate", updateTable -- occurs after the initial gathering phase has completed. This indicates that a change has occurred after the initial query that affects the result set.
     * `obj`         - the spotlightObject performing the search
     * `message`     - the message to the callback, in this case "didUpdate"
     * `updateTable` - a table containing one or more of the keys described for the `updateTable` argument of the "inProgress" message.

 * All of the results are always available through the [hs.spotlight:resultAtIndex](#resultAtIndex) method and metamethod shortcuts described in the `hs.spotlight` and `hs.spotlight.item` documentation headers; the results provided by the "didUpdate" and "inProgress" messages are just a convenience and can be used if you wish to parse partial results.

- - -

<a name="sortDescriptors"></a>
~~~lua
spotlight:sortDescriptors([attributes]) -> table | spotlightObject
~~~
Get or set the sorting preferences for the results of a Spotlight query.

Parameters:
 * `attributes` - an optional table or list of items specifying sort descriptors which affect the sorting order of results for a Spotlight query.  Defaults to an empty array.

Returns:
 * if an argument is provided, returns the spotlightObject; otherwise returns the current values

Notes:
 * Setting this property while a query is running stops the query and discards the current results. The receiver immediately starts a new query.

 * A sort descriptor may be specified as a string or as a table of key-value pairs.  In the case of a string, the sort descriptor will sort items in an ascending manner.  When specified as a table, at least the following keys should be specified:
   * `key`       - a string specifying the attribute to sort by
   * `ascending` - a boolean, default true, specifying whether the sort order should be ascending (true) or descending (false).

 * This method attempts to specify the sorting order of the results returned by the Spotlight query.
 * Note that not all attributes can be used as an attribute in a sort descriptor.  In such cases, the sort descriptor will have no affect on the order of returned items.

- - -

<a name="start"></a>
~~~lua
spotlight:start() -> spotlightObject
~~~
Begin the gathering phase of a Spotlight query.

Parameters:
 * None

Returns:
 * the spotlightObject

Notes:
 * If the query string set with [hs.spotlight:queryString](#queryString) is invalid, an error message will be logged to the Hammerspoon console and the query will not start.  You can test to see if the query is actually running with the [hs.spotlight:isRunning](#isRunning) method.

- - -

<a name="stop"></a>
~~~lua
spotlight:stop() -> spotlightObject
~~~
Stop the Spotlight query.

Parameters:
 * None

Returns:
 * the spotlightObject

Notes:
 * This method will prevent further gathering of items either during the initial gathering phase or from updates which may occur after the gathering phase; however it will not discard the results already discovered.

- - -

<a name="updateInterval"></a>
~~~lua
spotlight:updateInterval([interval]) -> number | spotlightObject
~~~
Get or set the time interval at which the spotlightObject will send "didUpdate" messages during the initial gathering phase.

Parameters:
 * `interval` - an optional number, default 1.0, specifying how often in seconds the "didUpdate" message should be generated during the initial gathering phase of a Spotlight query.

Returns:
 * if an argument is provided, returns the spotlightObject object; otherwise returns the current value.

- - -

<a name="valueListAttributes"></a>
~~~lua
spotlight:valueListAttributes([attributes]) -> table | spotlightObject
~~~
Get or set the attributes for which value list summaries are produced for the Spotlight query.

Parameters:
 * `attributes` - an optional table or list of items specifying the attributes for which value list summaries are produced for the Spotlight query.  Defaults to an empty array.

Returns:
 * if an argument is provided, returns the spotlightObject; otherwise returns the current values

Notes:
 * Setting this property while a query is running stops the query and discards the current results. The receiver immediately starts a new query.
 * Setting this property will increase CPU and memory usage while performing the Spotlight query.

 * This method allows you to specify attributes for which you wish to gather summary information about.  See [hs.spotlight:valueLists](#valueLists) for more information about value list summaries.
 * Note that not all attributes can be used as a value list attribute.  In such cases, the summary for the attribute will specify all results and an attribute value of nil.

- - -

<a name="valueLists"></a>
~~~lua
spotlight:valueLists() -> table
~~~
Returns the value list summaries for the Spotlight query

Parameters:
 * None

Returns:
 * an array table of the value list summaries for the Spotlight query as specified by the [hs.spotlight:valueListAttributes](#valueListAttributes) method.  Each member of the array will be a table with the following keys:
   * `attribute` - the attribute for the summary
   * `value`     - the value of the attribute for the summary
   * `count`     - the number of Spotlight items in the spotlightObject results for which this attribute has this value

Notes:
 * Value list summaries are a quick way to gather statistics about the number of results which match certain criteria - they do not allow you easy access to the matching members, just information about their numbers.

### Module Constants

<a name="commonAttributeKeys"></a>
~~~lua
spotlight.commonAttributeKeys[]
~~~
A list of defined attribute keys as discovered in the macOS 10.12 SDK framework headers.

This table contains a list of attribute strings that may be available for spotlightSearch result items.  This list is by no means complete, and not every result will contain all or even most of these keys.

Notes:
 * This list was generated by searching the Framework header files for string constants which matched one of the following regular expressions: "kMDItem.+", "NSMetadataItem.+", and "NSMetadataUbiquitousItem.+"

- - -

<a name="definedSearchScopes"></a>
~~~lua
spotlight.definedSearchScopes[]
~~~
A table of key-value pairs describing predefined search scopes for Spotlight queries

The keys for this table are as follows:
 * `iCloudData`              - Search all files not in the Documents directories of the app’s iCloud container directories.
 * `iCloudDocuments`         - Search all files in the Documents directories of the app’s iCloud container directories.
 * `iCloudExternalDocuments` - Search for documents outside the app’s container.
 * `indexedLocalComputer`    - Search all indexed local mounted volumes including the current user’s home directory (even if the home directory is remote).
 * `indexedNetwork`          - Search all indexed user-mounted remote volumes.
 * `localComputer`           - Search all local mounted volumes, including the user home directory. The user’s home directory is searched even if it is a remote volume.
 * `network`                 - Search all user-mounted remote volumes.
 * `userHome`                - Search the user’s home directory.

Notes:
 * It is uncertain at this time if the `iCloud*` search scopes are actually useful within Hammerspoon as Hammerspoon is not a sandboxed application that uses the iCloud API fo document storage. Further information on your experiences with these scopes, if you use them, is welcome in the Hammerspoon Google Group or at the Hammerspoon Github web site.

* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

hs.spotlight.group
==================

This sub-module is used to access results to a spotlightObject query which have been grouped by one or more attribute values.

A spotlightGroupObject is a special object created when you specify one or more grouping attributes with [hs.spotlight:groupingAttributes](#groupingAttributes). Spotlight items which match the Spotlight query and share a common value for the specified attribute will be grouped in objects you can retrieve with the [hs.spotlight:groupedResults](#groupedResults) method. This method returns an array of spotlightGroupObjects.

For each spotlightGroupObject you can identify the attribute and value the grouping represents with the [hs.spotlight.group:attribute](#attribute) and [hs.spotlight.group:value](#value) methods.  An array of the results which belong to the group can be retrieved with the [hs.spotlight.group:resultAtIndex](#resultAtIndex) method.  For convenience, metamethods have been added to the spotlightGroupObject which make accessing individual results easier:  an individual spotlightItemObject may be accessed from a spotlightGroupObject by treating the spotlightGroupObject like an array; e.g. `spotlightGroupObject[n]` will access the n'th spotlightItemObject in the grouped results.

### Usage
~~~lua
group = require("hs.spotlight.group")
~~~

### Contents


##### Module Methods
* <a href="#attribute">group:attribute() -> string</a>
* <a href="#count">group:count() -> integer</a>
* <a href="#resultAtIndex">group:resultAtIndex(index) -> spotlightItemObject</a>
* <a href="#subgroups">group:subgroups() -> table</a>
* <a href="#value">group:value() -> value</a>

- - -

### Module Methods

<a name="attribute"></a>
~~~lua
group:attribute() -> string
~~~
Returns the name of the attribute the spotlightGroupObject results are grouped by.

Parameters:
 * None

Returns:
 * the attribute name as a string

- - -

<a name="count"></a>
~~~lua
group:count() -> integer
~~~
Returns the number of query results contained in the spotlightGroupObject.

Parameters:
 * None

Returns:
 * an integer specifying the number of results that match the attribute and value represented by this spotlightGroup object.

Notes:
 * For convenience, metamethods have been added to the spotlightGroupObject which allow you to use `#spotlightGroupObject` as a shortcut for `spotlightGroupObject:count()`.

- - -

<a name="resultAtIndex"></a>
~~~lua
group:resultAtIndex(index) -> spotlightItemObject
~~~
Returns the spotlightItemObject at the specified index of the spotlightGroupObject

Parameters:
 * `index` - an integer specifying the index of the result to return.

Returns:
 * the spotlightItemObject at the specified index or an error if the index is out of bounds.

Notes:
 * For convenience, metamethods have been added to the spotlightGroupObject which allow you to use `spotlightGroupObject[index]` as a shortcut for `spotlightGroupObject:resultAtIndex(index)`.

- - -

<a name="subgroups"></a>
~~~lua
group:subgroups() -> table
~~~
Returns the subgroups of the spotlightGroupObject

Parameters:
 * None

Returns:
 * an array table containing the subgroups of the spotlightGroupObject or nil if no subgroups exist

Notes:
 * Subgroups are created when you supply more than one grouping attribute to `hs.spotlight:groupingAttributes`.

- - -

<a name="value"></a>
~~~lua
group:value() -> value
~~~
Returns the value for the attribute the spotlightGroupObject results are grouped by.

Parameters:
 * None

Returns:
 * the attribute value as an appropriate data type

* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

hs.spotlight.item
=================

This sub-module is used to access the individual results of a spotlightObject or a spotlightGroupObject.

Each Spotlight item contains attributes which you can access with the [hs.spotlight.item:valueForAttribute](#valueForAttribute) method. An array containing common attributes for the type of entity the item represents can be retrieved with the [hs.spotlight.item:attributes](#attributes) method, however this list of attributes is usually not a complete list of the attributes available for a given spotlightItemObject. Many of the known attribute names are included in the `hs.spotlight.commonAttributeKeys` constant array, but even this is not an exhaustive list -- an application may create and assign any key it wishes to an entity for inclusion in the Spotlight metadata database.

A common attribute, which is not usually included in the results of the [hs.spotlight.item:attributes](#attributes) method is the "kMDItemPath" attribute which specifies the local path to the file the entity represents. This is included here for reference, as it is a commonly desired value that is not obviously available for almost all Spotlight entries. It is believed that only those keys which are explicitly set when an item is added to the Spotlight database are included in the array returned by the [hs.spotlight.item:attributes](#attributes) method. Any attribute which is calculated or restricted in a sandboxed application appears to require an explicit request. This is, however, conjecture, and when in doubt you should explicitly check for the attributes you require with [hs.spotlight.item:valueForAttribute](#valueForAttribute) and not rely solely on the results from [hs.spotlight.item:attributes](#attributes).

For convenience, metamethods have been added to the spotlightItemObjects as a shortcut to the [hs.spotlight.item:valueForAttribute](#valueForAttribute) method; e.g. you can access the value of a specific attribute by treating the attribute as a key name: `spotlightItemObject.kMDItemPath` will return the path to the entity the spotlightItemObject refers to.

### Usage
~~~lua
item = require("hs.spotlight.item")
~~~

### Contents


##### Module Methods
* <a href="#attributes">item:attributes() -> table</a>
* <a href="#valueForAttribute">item:valueForAttribute(attribute) -> value</a>

- - -

### Module Methods

<a name="attributes"></a>
~~~lua
item:attributes() -> table
~~~
Returns a list of attributes associated with the spotlightItemObject

Parameters:
 * None

Returns:
 * an array table containing a list of attributes associated with the result item.

Notes:
 * This list of attributes is usually not a complete list of the attributes available for a given spotlightItemObject. Many of the known attribute names are included in the `hs.spotlight.commonAttributeKeys` constant array, but even this is not an exhaustive list -- an application may create and assign any key it wishes to an entity for inclusion in the Spotlight metadata database.
 * It is believed that only those keys which are explicitly set when an item is added to the Spotlight database are included in the array returned by this method. Any attribute which is calculated or restricted in a sandboxed application appears to require an explicit request. This is, however, conjecture, and when in doubt you should explicitly check for the attributes you require with [hs.spotlight.item:valueForAttribute](#valueForAttribute) and not rely solely on the results from [hs.spotlight.item:attributes](#attributes).

- - -

<a name="valueForAttribute"></a>
~~~lua
item:valueForAttribute(attribute) -> value
~~~
Returns the value for the specified attribute of the spotlightItemObject

Parameters:
 * `attribute` - a string specifying the attribute to get the value of for the spotlightItemObject

Returns:
 * the attribute value as an appropriate data type or nil if the attribute does not exist or contains no value

Notes:
 * See [hs.spotlight.item:attributes](#attributes) for information about possible attribute names.

 * For convenience, metamethods have been added to the spotlightItemObject which allow you to use `spotlightItemObject.attribute` as a shortcut for `spotlightItemObject:valueForAttribute(attribute)`.

- - -

### License

>     The MIT License (MIT)
>
> Copyright (c) 2016 Aaron Magill
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
>

