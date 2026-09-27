--
-- heavily inspired by https://github.com/cedstrom/powermate-osx
--
local module = {}

local btle    = require("hs._asm.btle")
local inspect = require("hs.inspect")

local powermateServiceUUID            = ("25598cf7-4240-40a6-9910-080f19f91ebc"):upper()
local powermateKnobCharacteristicUUID = ("9cf53570-ddd9-47f3-ba63-09acefc60415"):upper()
local powermateLedCharacteristicUUID  = ("847d189e-86ee-4bd2-966f-800832b1259d"):upper()

local powermateKnobStates = {
  [0x65] = "knobPress",
  [0x66] = "knobRelease",
  [0x67] = "knobCounterClockwise",
  [0x68] = "knobClockwise",
  [0x69] = "knobPressedCounterClockwise",
  [0x70] = "knobPressedClockwise",
  [0x72] = "knobPressed1Second",
  [0x73] = "knobPressed2Second",
  [0x74] = "knobPressed3Second",
  [0x75] = "knobPressed4Second",
  [0x76] = "knobPressed5Second",
  [0x77] = "knobPressed6Second",
}

local cmd_ledPower      = 0x80
local cmd_ledBlink      = 0xC0
local cmd_ledQuickBlink = 0xA0
local cmd_ledBrightness = 0xA1

local _internalState = {}

local printf    = function(...) print(string.format(...)) end
local finspect  = function(...) return inspect({...}, { newline = " ", indent = "" }) end
local cbinspect = function(label, ...) return label .. ":: " .. finspect(...) end

local sendLedAction = function(value)
    assert(_internalState.ledCharacteristic, "powermate must be on and connected for this function to work")
    _internalState.ledCharacteristic:writeValue(string.char(value), true)
end

local resetState = function()
    _internalState.ledCharacteristic  = nil
    _internalState.knobCharacteristic = nil
end

local knobCallbackFN = function(self, msg, ...)
    if msg == "valueUpdated" then
        local err = ...
        if not err then
            local value  = string.byte(self:value())
            local action = powermateKnobStates[value]
            if not action then
                printf("*** unknown knob action: 0x%x", value)
                action = string.format("unknown: 0x%x", value)
            end
            if _internalState.knobCallback then _internalState.knobCallback(action,value) end
            return
        end
    elseif msg == "notificationStateChanged" then
        local err = ...
        if not err then return end -- ignore
    end
    print(cbinspect("c-knob", msg, ...))
end

local ledCallbackFN = function(self, msg, ...)
    if msg == "valueWritten" then
        local err = ...
        if not err then return end -- ignore
    end
    print(cbinspect("c-led", msg, ...))
end

local serviceCallbackFN = function(self, msg, ...)
    if msg == "discoveredCharacteristics" then
        local err = ...
        if not err then
            for _, c in ipairs(self:characteristics()) do
                local uuid = c:uuid():upper()
                if uuid == powermateKnobCharacteristicUUID then
                    _internalState.knobCharacteristic = c:callback(knobCallbackFN):notify(true) end
                if uuid == powermateLedCharacteristicUUID then
                    _internalState.ledCharacteristic = c:callback(ledCallbackFN)
                end
            end
            return
        end
    end
    print(cbinspect("s", msg, ...))
end

local peripheralCallbackFN = function(self, msg, ...)
    if msg == "discoveredServices" then
        local err = ...
        if not err then
            self:services()[1]:callback(serviceCallbackFN):discoverCharacteristics()
            return
        end
    end
    print(cbinspect("p", msg, ...))
end

local managerCallbackFN = function(self, msg, ...)
    if msg == "stateChanged" then
        local state = ...
        if state == "poweredOn" then
            self:startScan(powermateServiceUUID)
        elseif state == "poweredOff" then
            resetState()
        else
            printf("*** bluetooth state: %s", state)
            resetState()
        end
        return
    elseif msg == "discovered" then
        local peripheral, advertisementData, RSSI = ...
        peripheral:connect()
        self:stopScan()
        return
    elseif msg == "disconnected" then
        local peripheral, err = ...
        resetState()
        self:startScan(powermateServiceUUID)
        return
    elseif msg == "connected" then
        local peripheral = ...
        peripheral:callback(peripheralCallbackFN):discoverServices(powermateServiceUUID)
        return
    end
    print(cbinspect("m", msg, ...))
end

module.stop = function()
    if _internalState.manager then
        _internalState.manager:stopScan()
        for _, p in ipairs(_internalState.manager:connectedPeripherals(powermateServiceUUID)) do
            p:disconnect()
        end
        resetState()
        _internalState.manager = nil
    end
end

module.start = function()
    if not _internalState.manager then
        _internalState.manager = btle.manager():callback(managerCallbackFN)
    end
end

module.ledOn = function() sendLedAction(cmd_ledPower + 0x01) end

module.ledOff = function() sendLedAction(cmd_ledPower + 0x00) end

module.ledQuickBlink = function() sendLedAction(cmd_ledQuickBlink) end

module.ledBlink = function(speed)
    assert(speed >= 0.0 and speed <= 1.0, "led blink speed must be between 0.0 and 1.0 inclusive")
    local value = math.floor(31 * (1.0 - speed))
    sendLedAction(cmd_ledBlink + value)
end

module.ledBrightness = function(level)
    assert(level >= 0.0 and level <= 1.0, "led brightness level must be between 0.0 and 1.0 inclusive")
    local value = math.floor(30 * level)
    sendLedAction(cmd_ledBrightness + value)
end

module.knobCallback = function(fn)
    _internalState.knobCallback = fn
end

module.knobCallback(function(action, value) printf("(0x%x) %s", value, action) end)
module.start()

return setmetatable(module, {
    __gc    = module.stop,
    __index = function(self, key)
        if key == "debug" then return _internalState end
        return nil
    end,
})

