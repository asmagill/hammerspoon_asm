
--- === hs.doc ===
---
--- HS.DOC, The Rewrite: Bigger, bolder, and coming to a thater near you... IN 3D!!!!!
---
--- Create documentation objects for interactive help within Hammerspoon
---
--- The documentation object created is a table with tostring metamethods allowing access to a specific functions documentation by appending the path to the method or function to the object created.
---
--- From the Hammerspoon console:
---
---       doc = require("hs.doc")
---       doc.hs.application
---
--- Results in:
---       Manipulate running applications
---
---       [submodules]
---       hs.application.watcher
---
---       [subitems]
---       hs.application:activate([allWindows]) -> bool
---       hs.application:allWindows() -> window[]
---           ...
---       hs.application:visibleWindows() -> win[]
---
--- By default, the internal core documentation and portions of the Lua 5.3 manual, located at http://www.lua.org/manual/5.3/manual.html, are already registered for inclusion within this documentation object, but you can register additional documentation from 3rd party modules with `hs.registerJSONFile(...)`.

local USERDATA_TAG  = "hs.doc"
local module        = require(USERDATA_TAG..".internal")
module.spoonsupport = require("hs.doc.spoonsupport")

local fnutils   = require("hs.fnutils")
local watchable = require("hs.watchable")

-- local log = require("hs.logger").new(USERDATA_TAG, require"hs.settings".get(USERDATA_TAG .. ".logLevel") or "warning")

-- private variables and methods -----------------------------------------

local submodules = {
    markdown = "hs.doc.markdown",
    hsdocs   = "hs.doc.hsdocs",
    builder  = "hs.doc.builder",
}

local changeCount = watchable.new("hs.doc")
changeCount.changeCount = 0

local triggerChangeCount = function()
    changeCount.changeCount = changeCount.changeCount + 1
end

-- so we can trigger this from the C side
getmetatable(module)._registerTriggerFunction(triggerChangeCount)

-- forward declarations for hsdocs
local _jsonForSpoons = nil
local _jsonForModules = nil

module._moduleListChanges = watchable.watch("hs.doc", "changeCount", function(w, p, k, o, n)
    _jsonForSpoons = nil
    _jsonForModules = nil
end)

-- forward declaration of things we're going to wrap
local _help = module.help
local _registeredFilesFunction = module.registeredFiles

local helperMT
helperMT = {
    __index = function(self, key)
        local parent = rawget(self, "_parent") or ""
        if parent ~= "" then parent = parent .. "." end
        parent = parent .. self._key
        local children = module._children(parent)
        if fnutils.contains(children, key) then
            return setmetatable({ _key = key, _parent = parent }, helperMT)
        end
    end,
    __tostring = function(self)
        local entry = rawget(self, "_parent")
        if entry then entry = entry .. "." else entry = "" end
        entry = entry .. self._key
        return _help(entry)
    end,
    __pairs = function(self)
        local parent = rawget(self, "_parent") or ""
        if parent ~= "" then parent = parent .. "." end
        parent = parent .. self._key
        local children = {}
        for i, v in ipairs(module._children(parent)) do children[v] = i end
        return function(_, k)
                local v
                k, v = next(children, k)
                return k, v
            end, self, nil
    end,
    __len = function(self)
        local parent = rawget(self, "_parent") or ""
        if parent ~= "" then parent = parent .. "." end
        parent = parent .. self._key
        return #module._children(parent)
    end,
}

-- Public interface ------------------------------------------------------

--- hs.doc.registeredFiles() -> table
--- Function
--- Returns the list of registered JSON files.
---
--- Parameters:
---  * None
---
--- Returns:
---  * a table containing the list of registered JSON files
---
--- Notes:
---  * The table returned by this function has a metatable including a __tostring method which allows you to see the list of registered files by simply typing `hs.doc.registeredFiles()` in the Hammerspoon Console.
---
---  * By default, the internal core documentation and portions of the Lua 5.3 manual, located at http://www.lua.org/manual/5.3/manual.html, are already registered for inclusion within this documentation object.
---
---  * You can unregister these defaults if you wish to start with a clean slate with the following commands:
---    * `hs.doc.unregisterJSONFile(hs.docstrings_json_file)` -- to unregister the Hammerspoon API docs
---    * `hs.doc.unregisterJSONFile((hs.docstrings_json_file:gsub("/docs.json$","/extensions/hs/doc/lua.json")))` -- to unregister the Lua 5.3 Documentation.
module.registeredFiles = function(...)
    return setmetatable(_registeredFilesFunction(...), {
        __tostring = function(self)
            local result = ""
            for _,v in pairs(self) do
                result = result..v.."\n"
            end
            return result
        end,
    })
end

--- hs.doc.help(identifier)
--- Function
--- Prints the documentation for some part of Hammerspoon's API and Lua 5.3.  This function has also been aliased as `hs.help` and `help` as a shorthand for use within the Hammerspoon console.
---
--- Parameters:
---  * identifier - A string containing the signature of some part of Hammerspoon's API (e.g. `"hs.reload"`)
---
--- Returns:
---  * None
---
--- Notes:
---  * This function is mainly for runtime API help while using Hammerspoon's Console
---
---  * You can also access the results of this function by the following methods from the console:
---    * help("prefix.path") -- quotes are required, e.g. `help("hs.reload")`
---    * help.prefix.path -- no quotes are required, e.g. `help.hs.reload`
---      * `prefix` can be one of the following:
---        * `hs`    - provides documentation for Hammerspoon's builtin commands and modules
---        * `spoon` - provides documentation for the Spoons installed on your system
---        * `lua`   - provides documentation for the version of lua Hammerspoon is using, currently 5.3
---          * `lua._man` - provides the table of contents for the Lua 5.3 manual.  You can pull up a specific section of the lua manual by including the chapter (and subsection) like this: `lua._man._3_4_8`.
---          * `lua._C`   - provides documentation specifically about the Lua C API for use when developing modules which require external libraries.
module.help = function(...)
    local answer = _help(...)
    return setmetatable({}, {
        __tostring = function(self) return answer end,
    })
end

--- hs.doc.locateJSONFile(module) -> path | false, message
--- Function
--- Locates the JSON file corresponding to the specified module by searching package.path and package.cpath.
---
--- Parameters:
---  * module - the name of the module to locate a JSON file for
---
--- Returns:
---  * the path to the JSON file, or `false, error` if unable to locate a corresponding JSON file.
---
--- Notes:
---  * The JSON should be named 'docs.json' and located in the same directory as the `lua` or `so` file which is used when the module is loaded via `require`.
module.locateJSONFile = function(moduleName)
    local asLua = package.searchpath(moduleName, package.path)
    local asC   = package.searchpath(moduleName, package.cpath)

    if asLua then
        local pathPart = asLua:match("^(.*/).+%.lua$")
        if pathPart then
            if fs.attributes(pathPart.."docs.json") then
                return pathPart.."docs.json"
            else
                return false, "No JSON file for "..moduleName.." found"
            end
        else
            return false, "Unable to parse package.path for "..moduleName
        end
    elseif asC then
        local pathPart = asC:match("^(.*/).+%.so$")
        if pathPart then
            if fs.attributes(pathPart.."docs.json") then
                return pathPart.."docs.json"
            else
                return false, "No JSON file for "..moduleName.." found"
            end
        else
            return false, "Unable to parse package.cpath for "..moduleName
        end
    else
        return false, "Unable to locate module path for "..moduleName
    end
end


-- Return Module Object --------------------------------------------------

module.registerJSONFile(hs.docstrings_json_file)
module.registerJSONFile((hs.docstrings_json_file:gsub("/docs.json$","/extensions/hs/doc/lua.json")))

module.spoonsupport.updateDocsFiles()
local _, details = module.spoonsupport.findSpoons()
for _,v in pairs(details) do if v.hasDocs then module.registerJSONFile(v.docPath, true) end end

-- we hide some debugging stuff in the metatable but we want to modify it here, so...
local _mt = getmetatable(module) or {} -- in case we delete the metatable later
setmetatable(module, nil)
_mt.__call = function(_, ...) return module.help(...) end
_mt.__tostring = function() return _help() end
_mt.__index = function(self, key)
    if submodules[key] then
        self[key] = require(submodules[key])
    end
    -- massage the result for hsdocs, which we should really rewrite at some point
    if key == "_jsonForSpoons" or key == "_jsonForModules" then
        if not _jsonForSpoons  then _jsonForSpoons  = module._moduleJson("spoon") end
        if not _jsonForModules then _jsonForModules = module._moduleJson("hs") end
        return (key == "_jsonForModules") and _jsonForModules or _jsonForSpoons
    end
    local children = module._children()
    if fnutils.contains(children, key) then
        return setmetatable({ _key = key }, helperMT)
    end
    return rawget(self, key)
end

return setmetatable(module, _mt)
