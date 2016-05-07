--- === hs._asm.watchable ===
---
--- Creates a watchable table object.  Setting a key-value pair within the returned table will trigger callbacks automatically to other modules which have registered as watchers.
---
--- This module allows you to generate a table with a defined label or path that can be used to share data with other modules or code.  Other modules can register as watchers to a specific key-value pair within the watchable object table and will be automatically notified when the key-value pair changes.
---
--- The goal is to provide a mechanism for sharing state information between separate and (mostly) unrelated code easily and in an independent fashion.

local USERDATA_TAG = "hs._asm.watchable"
-- local module       = require(USERDATA_TAG..".internal")
local module = {}

-- private variables and methods -----------------------------------------

local validTypes = {
    change = true,
    create = true,
    delete = true,
}

local mt_object, mt_watcher
mt_object = {
    __watchers = {},
    __objects = setmetatable({}, {__mode = "kv"}),
    __values = setmetatable({}, {__mode = "k"}),
    __name = USERDATA_TAG,
    __type = USERDATA_TAG,
    __index = function(self, index)
        return mt_object.__values[self][index]
    end,
    __newindex = function(self, index, value)
        local oldValue = mt_object.__values[self][index]
        mt_object.__values[self][index] = value
        if oldValue ~= value then
            local objectPath = mt_object.__objects[self]
            if mt_object.__watchers[objectPath] then
                if mt_object.__watchers[objectPath][index] then
                    for k, v in pairs(mt_object.__watchers[objectPath][index]) do
                        if v._active then
                            v._callback(v, objectPath, index, oldValue, value)
                        end
                    end
                end
                if mt_object.__watchers[objectPath]["*"] then
                    for k, v in pairs(mt_object.__watchers[objectPath]["*"]) do
                        if v._active then
                            v._callback(v, objectPath, index, oldValue, value)
                        end
                    end
                end
            end
        end
    end,
    __pairs = function(self)
        return function(_, k)
            local v
            k, v = next(mt_object.__values[self], k)
            return k, v
        end, self, nil
    end,
    __len = function(self)
        return #mt_object.__values[self]
    end,
    __pairs = function(self) return pairs(mt_object.__values[self]) end,
    __tostring = function(self) return USERDATA_TAG .. " table for path " .. mt_object.__objects[self] end,
}
-- mt_object.__metatable = mt_object.__index

mt_watcher = {
    __name = USERDATA_TAG .. ".watcher",
    __type = USERDATA_TAG .. ".watcher",
    __index = {
        pause = function(self) self._active = false end,
        resume = function(self) self._active = true end,
        release = function(self)
            self._active = false
            for k,v in pairs(mt_object.__watchers[self._objPath][self._objKey]) do
                if v == self then mt_object.__watchers[self._objPath][self._objKey] = nil end
            end
            setmetatable(self, nil)
            return nil
        end,
        callback = function(self, callback)
            if not callback then
                return self._callback
            elseif type(callback) == "function" then
                self._callback = callback
                return self
            else
                error("callback must be a function", 2)
            end
        end,
        value = function(self, key)
            local lookupKey = self._objKey
            if lookupKey == "*" and key == nil then
                error("key required for path with wildcard key", 2)
            elseif lookupKey == "*" then
                lookupKey = key
            end
            local object = mt_object.__objects[self._objPath]
            return object and object[lookupKey]
        end,
    },
    __gc = function(self) self.release(self) end,
    __tostring = function(self) return USERDATA_TAG .. ".watcher for path " .. self._path end,
}
-- mt_watcher.__metatable = mt_watcher.__index


-- for testing; will remove in the future:
module.mt_object = mt_object
module.mt_watcher = mt_watcher

-- Public interface ------------------------------------------------------

module.new = function(path)
    if type(path) ~= "string" then error ("path must be a string", 2) end
    local self = setmetatable({}, mt_object)
    mt_object.__objects[path] = self
    mt_object.__objects[self] = path
    mt_object.__values[self] = {}
    return self
end

module.watch = function(path, key, callback)
    if type(path) ~= "string" then error ("path must be a string", 2) end
    if type(key) == "function" then
        callback = key
        local objPath, objKey = path:match("^(.+)%.([^%.]+)$")
        if not (objPath and objKey) then error ("malformed path; must be of the form 'path.key' or path and key must be separate arguments", 2) end
        path = objPath
        key = objKey
    end
    if type(callback) ~= "function" then error ("callback must be a function", 2) end
    initial = initial or false

    local objPath, objKey = path, key

    local self = setmetatable({
        _path = objPath .. "." .. objKey,
        _objKey = objKey,
        _objPath = objPath,
        _active = true,
        _types = { "create", "change", "delete" },
        _callback = callback,
    }, mt_watcher)

    if not mt_object.__watchers[objPath] then mt_object.__watchers[objPath] = {} end
    if not mt_object.__watchers[objPath][objKey] then mt_object.__watchers[objPath][objKey] = setmetatable({}, {__mode = "v"}) end
    table.insert(mt_object.__watchers[objPath][objKey], self)

    return self
end

-- Return Module Object --------------------------------------------------

return module
