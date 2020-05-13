--- === hs._asm.btle ===
---
--- Hammerspoon module for Core Bluetooth Objects.
---
--- This module provides an interface to the Core Bluetooth OS X Object classes for accessing BTLE devices.
---
--- Currently this module only supports Hammerspoon as a BTLE Manager, not as a BTLE Peripheral.
---
--- This code is still very experimental.

local USERDATA_TAG = "hs._asm.btle"
local module       = {}
module.manager     = require(USERDATA_TAG..".manager")

require(USERDATA_TAG .. ".characteristic")
require(USERDATA_TAG .. ".descriptor")
require(USERDATA_TAG .. ".peripheral")
require(USERDATA_TAG .. ".service")

local basePath = package.searchpath(USERDATA_TAG, package.path)
if basePath then
    basePath = basePath:match("^(.+)/init.lua$")
    if require"hs.fs".attributes(basePath .. "/docs.json") then
        require"hs.doc".registerJSONFile(basePath .. "/docs.json")
    end
end

local inspect = require("hs.inspect")
local utf8    = require("hs.utf8")

-- flatten inspect results to one line
local finspect = function(...) return (inspect(...):gsub("%s+", " ")) end

-- private variables and methods -----------------------------------------

local managerMT        = hs.getObjectMetatable(USERDATA_TAG .. ".manager")
local characteristicMT = hs.getObjectMetatable(USERDATA_TAG .. ".characteristic")
local descriptorMT     = hs.getObjectMetatable(USERDATA_TAG .. ".descriptor")
local peripheralMT     = hs.getObjectMetatable(USERDATA_TAG .. ".peripheral")
local serviceMT        = hs.getObjectMetatable(USERDATA_TAG .. ".service")

local gattDataFile = basePath .. "/org.bluetooth.txt"

local log = require("hs.logger").new(USERDATA_TAG, require"hs.settings".get(USERDATA_TAG .. ".logLevel") or "warning")

-- Public interface ------------------------------------------------------

module.log = log

module.gattByUUID, module.gattByName = {}, {}
local tableType, url
for line in io.lines(gattDataFile) do
    if line:match("^https:") then
        tableType = line:match("^https:.*/(%w+)Home.*%.aspx$"):lower()
        url = line
    elseif line ~= "" then
        local desc, name, number = line:match("^([^\t]+)\t([^\t]+)\t0[xX]([^\t]+)$")
        module.gattByUUID[number] = {
            uuid = number,
            description = desc,
            name = name,
            ["type"] = tableType,
            url = url
        }
        module.gattByName[name] = module.gattByUUID[number]
    end
end
module.gattByUUID = ls.makeConstantsTable(module.gattByUUID)
module.gattByName = ls.makeConstantsTable(module.gattByName)

-- FIXME: rework so creates table object for wrapper

module.userCallbacks = {}
module.discovered    = {}

peripheralMT.setCallback = function(self, fn)
    local device = module.discovered[self:identifier()]
    if device then
        if fn == nil then
            device.fn = nil
        elseif type(fn) == "function" or ((type(fn) == "table") and getmetatable(fn) and getmetatable(fn).__call) then
            device.fn = fn
        else
            error("expected fn or nil", 2)
        end
    else
        log.wf("peripheral:setCallback - %s is not in discovered list", self:identifier())
        return nil
    end
    return self
end

module.create = function()
    if module._manager then
        log.d("manager already initialized")
    else
        module._manager = module.manager.create():setCallback(function(manager, message, peripheral, ...)
            log.vf("manager callback:%s (%s) -- %s", message, peripheral, utf8.asciiOnly(finspect(table.pack(...))))

            local device = peripheral and module.discovered[peripheral:identifier()]

            if message == "didConnectPeripheral" then
                if device then
                    device.state           = peripheral:state()
                    device.disconnectError = nil
                    device.connectError    = nil
                    device.services        = {}
                    device.updated         = os.time()
                else -- in case it was connected to directly by stored identifier rather than discovered
                    device = {
                        peripheral    = peripheral,
                        RSSI          = peripheral:RSSI(),
                        name          = peripheral:name(),
                        updated       = os.time(),
                        state         = peripheral:state(),
                        identifier    = peripheral:identifier(),
                        services      = {},
                    }
                    module.discovered[peripheral:identifier()] = device
                end
                device.peripheral:discoverServices()

            elseif message == "didDisconnectPeripheral" then
                local errMsg = ...
                if device then
                    device.state           = peripheral:state()
                    device.disconnectError = errMsg
                    device.updated         = os.time()
                    device.services        = {}
                end

            elseif message == "didFailToConnectPeripheral" then
                local errMsg = ...
                if device then
                    device.state         = peripheral:state()
                    device.connectError  = errMsg
                    device.updated       = os.time()
                    device.services      = {}
                end

            elseif message == "didDiscoverPeripheral" then
                local advertisementData, RSSI = ...
                if not device then
                    device = { peripheral = peripheral }
                    module.discovered[peripheral:identifier()] = device
                end
                device.advertisement = advertisementData
                device.RSSI          = RSSI
                device.name          = peripheral:name()
                device.updated       = os.time()
                device.state         = peripheral:state()
                device.identifier    = peripheral:identifier()

            elseif message == "didUpdateState" then
                local state = manager:state()
                if state == "poweredOn" then
                    log.i("btle powered on")
                -- uses more power, so don't auto-enable scan
                --     manager:startScan()
                elseif state == "poweredOff" then
                -- probably automatically turned off, but lets be explicit
                    manager:stopScan()
                    log.i("btle powered off, any running scans disabled")
                else
                -- any other state invalidates any peripheral records we may already have
                    log.wf("btle state %s: invalidating discovered peripherals", state)
                    module.discovered = {}
                end
            end

            -- needs to be after didDiscoverPeripheral
            if peripheral and not device then
                log.wf("manager callback:%s - %s is not in discovered list", message, peripheral:identifier())
            end

-- FIXME: need to decide what to do about user callbacks once I move this into a table object

        end):setPeripheralCallback(function(peripheral, message, ...)
            log.vf("peripheral callback:%s -- %s", message, utf8.asciiOnly(finspect(table.pack(...))))

            local device = module.discovered[peripheral:identifier()]

            if not device then
                log.wf("peripheral callback:%s - %s is not in discovered list", message, peripheral:identifier())
            else
                local errorToLog = nil

                if message == "didDiscoverServices" then
                    local errMsg = ...
                    if errMsg then
                        errorToLog = errMsg
                    else
                        for i, svc in ipairs(peripheral:services()) do
                            local label = svc:UUID()
                            device.services[label] = {
                                characteristics  = {},
                                includedServices = {},
                                primary          = svc:primary(),
                                uuid             = label,
                                service          = svc,
                                updated          = os.time(),
                                label            = module.gattByUUID[label:upper()] and module.gattByUUID[label:upper()].name,
                            }
                            svc:discoverIncludedServices()
                            svc:discoverCharacteristics()
                        end
                    end

                elseif message == "didDiscoverIncludedServicesForService" then
                    local service, errMsg = ...
                    if errMsg then
                        errorToLog = errMsg
                    else
                        local serviceLabel = service:UUID()
                        for i, svc in ipairs(service:includedServices()) do
                            local label = svc:UUID()
                            if not device.services[label] then
                                device.services[label] = {
                                    characteristics  = {},
                                    includedServices = {},
                                    primary          = svc:primary(),
                                    uuid             = label,
                                    service          = svc,
                                    updated          = os.time(),
                                    label            = module.gattByUUID[label:upper()] and module.gattByUUID[label:upper()].name,
                                }
                                svc:discoverIncludedServices()
                                svc:discoverCharacteristics()
                            end
                            device.services[serviceLabel].includedServices[label] = device.services[label]
                        end
                    end

                elseif message == "didDiscoverCharacteristicsForService" then
                    local service, errMsg = ...
                    local serviceLabel = service:UUID()
                    if errMsg then
                        errorToLog = errMsg
                    else
                        for i, characteristic in ipairs(service:characteristics()) do
                            local label = characteristic:UUID()
                            device.services[serviceLabel].characteristics[label] = {
                                uuid           = label,
                                descriptors    = {},
                                properties     = characteristic:properties(),
                                isNotifying    = characteristic:isNotifying(),
                                characteristic = characteristic,
                                updated        = os.time(),
                                label          = module.gattByUUID[label:upper()] and module.gattByUUID[label:upper()].name,
                                value          = characteristic:value(),
                            }
                            characteristic:discoverDescriptors()
                        end
                    end
                    if device.services[serviceLabel].fn then
                        device.services[serviceLabel].fn(peripheral, message, ...)
                    end

                elseif message == "didDiscoverDescriptorsForCharacteristic" then
                    local characteristic, errMsg = ...
                    local serviceLabel = characteristic:service():UUID()
                    local charLabel    = characteristic:UUID()
                    if errMsg then
                        errorToLog = errMsg
                    else
                        for i, descriptor in ipairs(characteristic:descriptors()) do
                            local label = descriptor:UUID()
                            device.services[serviceLabel].characteristics[charLabel].descriptors[label] = {
                                uuid       = label,
                                descriptor = descriptor,
                                updated    = os.time(),
                                label      = module.gattByUUID[label:upper()] and module.gattByUUID[label:upper()].name,
                                value      = descriptor:value(),
                            }
                        end
                    end
                    if device.services[serviceLabel].fn then
                        device.services[serviceLabel].fn(peripheral, message, ...)
                    end
                    if device.services[serviceLabel].characteristics[charLabel].fn then
                        device.services[serviceLabel].characteristics[charLabel].fn(peripheral, message, ...)
                    end

                elseif message == "didUpdateValueForCharacteristic" then
                    local characteristic, errMsg = ...
                    local serviceLabel = characteristic:service():UUID()
                    local charLabel    = characteristic:UUID()
                    if errMsg then
                        errorToLog = errMsg
                    else
                        device.services[serviceLabel].characteristics[charLabel].updated = os.time()
                        device.services[serviceLabel].characteristics[charLabel].value   = characteristic:value()
                    end
                    if device.services[serviceLabel].fn then
                        device.services[serviceLabel].fn(peripheral, message, ...)
                    end
                    if device.services[serviceLabel].characteristics[charLabel].fn then
                        device.services[serviceLabel].characteristics[charLabel].fn(peripheral, message, ...)
                    end

                elseif message == "didUpdateValueForDescriptor" then
                    local descriptor, errMsg = ...
                    local serviceLabel   = descriptor:characteristic():service():UUID()
                    local charLabel      = descriptor:characteristic():UUID()
                    local descLabel      = descriptor:UUID()
                    if errMsg then
                        errorToLog = errMsg
                    else
                        device.services[serviceLabel].characteristics[charLabel].descriptors[descLabel].updated = os.time()
                        device.services[serviceLabel].characteristics[charLabel].descriptors[descLabel].value   = descriptor:value()
                    end
                    if device.services[serviceLabel].fn then
                        device.services[serviceLabel].fn(peripheral, message, ...)
                    end
                    if device.services[serviceLabel].characteristics[charLabel].fn then
                        device.services[serviceLabel].characteristics[charLabel].fn(peripheral, message, ...)
                    end
                    if device.services[serviceLabel].characteristics[charLabel].descriptors[descLabel].fn then
                        device.services[serviceLabel].characteristics[charLabel].descriptors[descLabel].fn(peripheral, message, ...)
                    end

                elseif message == "didWriteValueForCharacteristic" then
                    local characteristic, errMsg = ...
                    local serviceLabel = characteristic:service():UUID()
                    local charLabel    = characteristic:UUID()
                    if errMsg then
                        errorToLog = errMsg
                    else
                        device.services[serviceLabel].characteristics[charLabel].updated = os.time()
                    end
                    if device.services[serviceLabel].fn then
                        device.services[serviceLabel].fn(peripheral, message, ...)
                    end
                    if device.services[serviceLabel].characteristics[charLabel].fn then
                        device.services[serviceLabel].characteristics[charLabel].fn(peripheral, message, ...)
                    end

                elseif message == "didWriteValueForDescriptor" then
                    local descriptor, errMsg = ...
                    local serviceLabel   = descriptor:characteristic():service():UUID()
                    local charLabel      = descriptor:characteristic():UUID()
                    local descLabel      = descriptor:UUID()
                    if errMsg then
                        errorToLog = errMsg
                    else
                        device.services[serviceLabel].characteristics[charLabel].descriptors[descLabel].updated = os.time()
                    end
                    if device.services[serviceLabel].fn then
                        device.services[serviceLabel].fn(peripheral, message, ...)
                    end
                    if device.services[serviceLabel].characteristics[charLabel].fn then
                        device.services[serviceLabel].characteristics[charLabel].fn(peripheral, message, ...)
                    end
                    if device.services[serviceLabel].characteristics[charLabel].descriptors[descLabel].fn then
                        device.services[serviceLabel].characteristics[charLabel].descriptors[descLabel].fn(peripheral, message, ...)
                    end

                elseif message == "didUpdateNotificationStateForCharacteristic" then
                    local characteristic, errMsg = ...
                    local serviceLabel = characteristic:service():UUID()
                    local charLabel    = characteristic:UUID()
                    if errMsg then
                        errorToLog = errMsg
                    else
                        device.services[serviceLabel].characteristics[charLabel].isNotifying = characteristic:isNotifying()
                        device.services[serviceLabel].characteristics[charLabel].updated     = os.time()
                    end
                    if device.services[serviceLabel].fn then
                        device.services[serviceLabel].fn(peripheral, message, ...)
                    end
                    if device.services[serviceLabel].characteristics[charLabel].fn then
                        device.services[serviceLabel].characteristics[charLabel].fn(peripheral, message, ...)
                    end

                elseif message == "peripheralDidReadRSSI" then
                    local errMsgOrRSSI = ...
                    if type(errMsgOrRSSI) == "string" then
                        errorToLog = errMsgOrRSSI
                    else
                        device.RSSI    = errMsgOrRSSI
                        device.updated = os.time()
                    end

                elseif message == "peripheralDidUpdateName" then
                    device.name    = peripheral:name()
                    device.updated = os.time()

                elseif message == "didModifyServices" then
                    local invalidatedServices = ...
                    for i, v in ipairs(invalidatedServices) do device.services[v:UUID()] = nil end
                    peripheral:discoverServices() -- in case a new one was added or an old one was moved
                end

                if errorToLog then
                    log.ef("peripheral %s callback:%s error %s", message, peripheral:identifier(), errorToLog)
                end

--  FIXME: Gotta think about how I want to handle user callbacks...
                if device.fn then device.fn(peripheral, message, ...) end

            end
        end)
    end
end

module.delete = function()
    if not module._manager then
        log.e("manager has not been created")
    else
        module._manager:stopScan()
        module._manager = nil
    end
end

module.startScanning = function(...)
    if not module._manager then
        log.e("manager has not been created")
    else
        local state = module._manager:state()
        if state ~= "poweredOn" then
            log.wf("btle state %s: scanning disabled", state)
        else
            module._manager:startScan(...)
        end
    end
end

module.stopScanning = function()
    if not module._manager then
        log.e("manager has not been created")
    else
        module._manager:stopScan()
    end
end


-- Return Module Object --------------------------------------------------

-- module.create()

return module
