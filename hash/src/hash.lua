--- === hs.hash ===
---
--- Various hashing algorithms
---
--- This module provides access to various hashing algorithms and functions for use within Hammerspoon. The following hash protocols are supported:
---
--- CRC32
--- MD2, MD4, MD5
--- SHA1, SHA224, SHA256, SHA384, SHA512
--- hmacMD5, hmacSHA1, hmacSHA256, hmacSHA384, hmacSHA224, hmacSHA512

local USERDATA_TAG = "hs.hash"
local module       = require(table.concat({ USERDATA_TAG:match("^([%w%._]+%.)([%w_]+)$") }, "lib"))
local fnutils      = require("hs.fnutils")
local fs           = require("hs.fs")

-- settings with periods in them can't be watched via KVO with hs.settings.watchKey, so
-- in general it's a good idea not to include periods
local SETTINGS_TAG = USERDATA_TAG:gsub("%.", "_")
local settings     = require("hs.settings")
local log          = require("hs.logger").new(USERDATA_TAG, settings.get(SETTINGS_TAG .. "_logLevel") or "warning")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

table.sort(module.types)
module.types = ls.makeConstantsTable(module.types)

--- hs.hash.convertHexHashToBinary(input) -> string
--- Function
--- Converts a string containing a hash value as a string of hexadecimal digits into its binary equivalent.
---
--- Parameters:
---  * input - a string containing the hash value you wish to convert into its binary equivalent. The string must be a sequence of hexadecimal digits with an even number of characters.
---
--- Returns:
---  * a string containing the equivalent binary hash
---
--- Notes:
---  * this is a convenience function for use when you already have a hash value that you wish to convert to its binary equivalent. Beyond checking that the input string contains only hexadecimal digits and is an even length, the value is not actually validated as the actual hash value for anything specific.
module.convertHashToBinary = function(...)
    local args = table.pack(...)
    local input = args[1]
    assert(args.n == 1 and type(input) == "string" and #input % 2 == 0 and input:match("^%x+$"), "expected a string of hexidecimal digits")
    local output = ""
    for p in input:gmatch("%x%x") do output = output .. string.char(tonumber(p, 16)) end
    return output
end

--- hs.hash.convertBinaryHashToHex(input) -> string
--- Function
--- Converts a string containing a binary hash value to its equivalent hexadecimal digits.
---
--- Parameters:
---  * input - a string containing the binary hash value you wish to convert into its equivalent hexadecimal digits.
---
--- Returns:
---  * a string containing the equivalent hash as a string of hexadecimal digits
---
--- Notes:
---  * this is a convenience function for use when you already have a binary hash value that you wish to convert to its hexadecimal equivalent -- he value is not actually validated as the actual hash value for anything specific.
module.convertBinaryHashToHEX = function(...)
    local args = table.pack(...)
    local input = args[1]
    assert(args.n == 1 and type(input) == "string", "expected a string")
    local output = ""
    for p in input:gmatch(".") do output = output .. string.format("%02x", string.byte(p)) end
    return output
end

module.forFile = function(...)
    local args = { ... }
    local hashFn = args[1]
    assert(type(hashFn) == "string" and fnutils.contains(module.types, hashFn), "hash type must be a string specifying one of the following -- " .. table.concat(module.types, ", "))

    local key  = hashFn:match("^hmac") and args[2] or nil
    local path = hashFn:match("^hmac") and args[3] or args[2]

    local object = hashFn:match("^hmac") and module.new(hashFn, key) or module.new(hashFn)
    return object:appendFile(path):finish():value()
end

module.defaultPathListExcludes = {
    "^\\..*$",
--     "^\\.git",
--     "^\\.DS_Store$",
--     "^\\.metadata_never_index$",
--     "^\\.fseventsd$",
--     "^\\.Trashes$",
--     "^\\.luarc.json$",
--     "^\\._",
}

-- Return Module Object --------------------------------------------------

return setmetatable(module, {
    __index = function(_, key)
        local realKey = key:match("^b(%w+)$") or key
        if fnutils.contains(module.types, realKey) then
            return function(...)
                local args   = { ... }
                local object
                if realKey:match("^hmac") then
                    local secret = table.remove(args, 1)
                    object = module.new(realKey, secret)
                else
                    object = module.new(realKey)
                end
                for _, v in ipairs(args) do object:append(v) end
                return object:finish():value(not not key:match("^b"))
            end
        end
    end,
    __call = function(_, key, ...)
        if fnutils.contains(module.types, key) then
            return _[key](...)
        else
            error(3, "attempt to call a table value")
        end
    end,
})
