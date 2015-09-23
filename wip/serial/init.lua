--- === hs._asm.serial ===
---
--- Basic serial port support for Hammerspoon
---
--- A module to facilitate serial port communications within Hammerspoon.  The motivation behind this module is to facilitate communications with Arduino devices communicating via a USB or Bluetooth Serial Port adapter but should work with any device which shows up under OS X as a serial port device.
---
--- This module is largely based on code found at http://playground.arduino.cc/Interfacing/Cocoa and https://github.com/armadsen/ORSSerialPort.

local module   = require("hs._asm.serial.internal")
local internal = hs.getObjectMetatable("hs._asm.serial")
local timer    = require("hs.timer")

-- private variables and methods -----------------------------------------

local _kMetaTable = {}
_kMetaTable._k = {}
_kMetaTable.__index = function(obj, key)
        if _kMetaTable._k[obj] then
            if _kMetaTable._k[obj][key] then
                return _kMetaTable._k[obj][key]
            else
                for k,v in pairs(_kMetaTable._k[obj]) do
                    if v == key then return k end
                end
            end
        end
        return nil
    end
_kMetaTable.__newindex = function(obj, key, value)
        error("attempt to modify a table of constants",2)
        return nil
    end
_kMetaTable.__pairs = function(obj) return pairs(_kMetaTable._k[obj]) end
_kMetaTable.__tostring = function(obj)
        local result = ""
        if _kMetaTable._k[obj] then
            local width = 0
            for k,v in pairs(_kMetaTable._k[obj]) do width = width < #k and #k or width end
            for k,v in require("hs.fnutils").sortByKeys(_kMetaTable._k[obj]) do
                result = result..string.format("%-"..tostring(width).."s %s\n", k, tostring(v))
            end
        else
            result = "constants table missing"
        end
        return result
    end
_kMetaTable.__metatable = _kMetaTable -- go ahead and look, but don't unset this

local _makeConstantsTable = function(theTable)
    local results = setmetatable({}, _kMetaTable)
    _kMetaTable._k[results] = theTable
    return results
end

local expandFlags = function(value, from)
    local results = {}
    for k,v in pairs(from) do
        if (value & v) == v then table.insert(results, k) end
    end
    return table.concat(results, ", ")
end
-- Public interface ------------------------------------------------------

module.attributeFlags.iflag = _makeConstantsTable(module.attributeFlags.iflag)
module.attributeFlags.oflag = _makeConstantsTable(module.attributeFlags.oflag)
module.attributeFlags.cflag = _makeConstantsTable(module.attributeFlags.cflag)
module.attributeFlags.lflag = _makeConstantsTable(module.attributeFlags.lflag)
module.attributeFlags.cc = _makeConstantsTable(module.attributeFlags.cc)
module.attributeFlags.action = _makeConstantsTable(module.attributeFlags.action)
module.attributeFlags.baud = _makeConstantsTable(module.attributeFlags.baud)

--- hs._asm.serial:unoReset([delay]) -> serialPortObject
--- Method
--- Triggers the reset process for an Arduino UNO (and similar) by setting the DTR high for `delay` microseconds and then pulling it low.
---
--- Parameters:
---  * delay - an optional parameter indicating how long in microseconds the DTR should be held high.  Defaults to 100000 microseconds.
---
--- Returns:
---  * the serial port object
---
--- Notes:
---  * the delay is performed via `hs.timer.usleep` and is blocking, so it should be kept as short as necessary.  My experience is that 100000 microseconds is sufficient, but the parameter is provided if circumstances require another value.
internal.unoReset = function(self, delay)
    delay = tonumber(delay) or 100000
    self:DTR(true)
    timer.usleep(delay)
    return self:DTR(false)
end

--- hs._asm.serial:dataBits([bits]) -> serialPortObject | integer
--- Method
--- Get or set the serial port's character data size in bits.
---
--- Parameters:
---   * bits - an optional integer between 5 and 8 inclusive specifying the serial port's character data size in bits.
---
--- Returns:
---   * the serial port object if a bit size is specified, otherwise, the current setting
---
--- Notes:
---   * the data bit size does not include any parity (if any) or stop bits.
internal.dataBits = function(self, bits)
    local attributes = self:getAttributes()

    if bits == nil then
        return ((attributes.cflag & module.attributeFlags.cflag.CSIZE) >> 8) + 5
    else
        assert(type(bits) == "number" and bits >= 5 and bits <= 8 and bits == math.tointeger(bits),
            "hs._asm.serial:dataBits - number of data bits must be an integer between 5 and 8 inclusive")

        attributes.cflag = attributes.cflag & ~module.attributeFlags.cflag.CSIZE
        attributes.cflag = attributes.cflag | module.attributeFlags.cflag["CS"..tostring(bits)]
        return self:setAttributes(attributes, module.attributeFlags.action.TCSAFLUSH)
    end
end

--- hs._asm.serial:stopBits([bits]) -> serialPortObject | integer
--- Method
--- Get or set the serial port's number of stop bits.
---
--- Parameters:
---   * bits - an optional integer between 1 and 2 inclusive specifying the serial port's number of stop bits.
---
--- Returns:
---   * the serial port object if a bit size is specified, otherwise, the current setting
internal.stopBits = function(self, bits)
    local attributes = self:getAttributes()

    if bits == nil then
        return ((attributes.cflag & module.attributeFlags.cflag.CSTOPB) >> 10) + 1
    else
        assert(type(bits) == "number" and bits >= 1 and bits <= 2 and bits == math.tointeger(bits),
            "hs._asm.serial:stopBits - number of data bits must be an integer between 1 and 2 inclusive")

        if bits == 1 then
            attributes.cflag = attributes.cflag & ~module.attributeFlags.cflag.CSTOPB
        else
            attributes.cflag = attributes.cflag | module.attributeFlags.cflag.CSTOPB
        end
        return self:setAttributes(attributes, module.attributeFlags.action.TCSAFLUSH)
    end
end

--- hs._asm.serial:parity([type]) -> serialPortObject | integer
--- Method
--- Get or set the serial port's parity type.
---
--- Parameters:
---   * type - an optional string indicating the type of parity to use for error detection.  Recognized values are:
---     * N or None - No parity: do not use parity for error detection
---     * E or Even - Use even parity
---     * O or Odd  - Use odd parity
---
--- Returns:
---   * the serial port object if a parity setting is specified, otherwise, the current setting
internal.parity = function(self, parity)
    local attributes = self:getAttributes()

    if parity == nil then
        if (attributes.cflag & module.attributeFlags.cflag.PARENB == 0) then
            return "None"
        else
            return ((attributes.cflag & module.attributeFlags.cflag.PARODD) == 0) and "Odd" or "Even"
        end
    else
        assert(type(parity) == "string",
            "hs._asm.serial:parity - parity must be specified as a string")

        if parity == "N" or parity == "None" then
            attributes.cflag = attributes.cflag & ~module.attributeFlags.cflag.PARENB
        elseif parity == "E" or parity == "Even" then
            attributes.cflag = attributes.cflag | module.attributeFlags.cflag.PARENB
            attributes.cflag = attributes.cflag & ~module.attributeFlags.cflag.PARODD
        elseif parity == "O" or parity == "Odd" then
            attributes.cflag = attributes.cflag | module.attributeFlags.cflag.PARENB
            attributes.cflag = attributes.cflag | module.attributeFlags.cflag.PARODD
        else
            error("hs._asm.serial:parity - parity must be N(one), E(ven), or O(dd)", 2)
        end
        return self:setAttributes(attributes, module.attributeFlags.action.TCSAFLUSH)
    end
end

--- hs._asm.serial:softwareFlowControl([state]) -> serialPortObject | boolean
--- Method
--- Get or set whether or not software flow control is enable for the serial port
---
--- Parameters:
---  * an optional boolean parameter indicating if software flow control should be enabled for the serial port
---
--- Returns:
---  * if a value was provided, then the serial port object is returned; otherwise the current value is returned
---
--- Notes:
---  * This method turns software flow control fully on or fully off (i.e. bi-directional).  If you have manipulated the serial port attributes directly, it is possible that software flow control may be only partially enabled - using this method to check on flow control status (i.e. without providing a boolean parameter) will report this condition as false since at least one direction of communication doesn not have software flow control enabled.
internal.softwareFlowControl = function(self, flow)
    local attributes = self:getAttributes()

    if flow == nil then
        return (attributes.iflag & module.attributeFlags.iflag.IXON ~= 0) and
               (attributes.iflag & module.attributeFlags.iflag.IXOFF ~= 0)
    else
        assert(type(flow) == "boolean", "hs._asm.serial:softwareFlowControl requires a boolean parameter")

        if flow then
            attributes.iflag = attributes.iflag |  (module.attributeFlags.iflag.IXON | module.attributeFlags.iflag.IXOFF)
        else
            attributes.iflag = attributes.iflag & ~(module.attributeFlags.iflag.IXON | module.attributeFlags.iflag.IXOFF)
        end
        return self:setAttributes(attributes, module.attributeFlags.action.TCSAFLUSH)
    end
end

--- hs._asm.serial:hardwareFlowControl([state]) -> serialPortObject | boolean
--- Method
--- Get or set whether or not hardware (RTSCTS) flow control is enable for the serial port
---
--- Parameters:
---  * an optional boolean parameter indicating if hardware flow control should be enabled for the serial port
---
--- Returns:
---  * if a value was provided, then the serial port object is returned; otherwise the current value is returned
---
--- Notes:
---  * This method only manages RTSCTS hardware flow control as this is the most commonly supported.  By adjusting the serial port attributes directly, DTRDSR hardware flow control and DCDOutputFlowControl may also be available if your device or driver support them.
---  * This method turns hardware flow control fully on or fully off (i.e. bi-directional).  If you have manipulated the serial port attributes directly, it is possible that hardware flow control may be only partially enabled - using this method to check on flow control status (i.e. without providing a boolean parameter) will report this condition as false since at least one direction of communication doesn not have hardware flow control enabled.
internal.hardwareFlowControl = function(self, flow)
    local attributes = self:getAttributes()

    if flow == nil then
        return (attributes.cflag & module.attributeFlags.cflag.CRTSCTS ~= 0)
    else
        assert(type(flow) == "boolean", "hs._asm.serial:softwareFlowControl requires a boolean parameter")

        if flow then
            attributes.cflag = attributes.cflag | module.attributeFlags.cflag.CRTSCTS
        else
            attributes.cflag = attributes.cflag & ~module.attributeFlags.cflag.CRTSCTS
        end
        return self:setAttributes(attributes, module.attributeFlags.action.TCSAFLUSH)
    end
end

internal.expandIflag = function(self) return expandFlags(self:getAttributes().iflag, module.attributeFlags.iflag) end
internal.expandOflag = function(self) return expandFlags(self:getAttributes().oflag, module.attributeFlags.oflag) end
internal.expandCflag = function(self) return expandFlags(self:getAttributes().cflag, module.attributeFlags.cflag) end
internal.expandLflag = function(self) return expandFlags(self:getAttributes().lflag, module.attributeFlags.lflag) end

-- Return Module Object --------------------------------------------------

return module
