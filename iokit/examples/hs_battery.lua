local iokit   = require("hs._asm.iokit")
local fnutils = require("hs.fnutils")

local module = {}

-- private variables and methods -----------------------------------------

local check_list = {
    "cycles",
    "name",
    "maxCapacity",
    "capacity",
    "designCapacity",
    "percentage",
    "voltage",
    "amperage",
    "watts",
    "health",
    "healthCondition",
    "timeRemaining",
    "timeToFullCharge",
    "isCharging",
    "isCharged",
    "isFinishingCharge",
    "powerSource",
    "powerSourceType",
    "batteryType",
    "adapterSerialNumber",
    "batterySerialNumber",
    "otherBatteryInfo",
    "privateBluetoothBatteryInfo",
}

-- Public interface ------------------------------------------------------

module._adapterDetails = function() return iokit.power.externalAdapterDetails() end

module._appleSmartBattery = function()
    local entry = iokit.serviceForName("AppleSmartBattery")
    if entry then
        return entry:properties()
    else
        return nil, "unable to retrieve AppleSmartBattery IOService"
    end
end

module._iopmBatteryInfo = function() return iokit.power.intelBatteryInfo() end

module._powerSources = function()
    local temp = iokit.power.powerSources()
    if type(temp) == "table" and #temp == 0 then
        temp = { {} }
    end
    return temp
end

module.otherBatteryInfo = function()
    local nodes   = iokit.rootEntry():childrenInPlane(true)
    local results = {}
    for _, v in ipairs(nodes) do
        local percent = v:propertyValue("BatteryPercent")
        if math.type(percent) == "integer" then
            table.insert(results, v:properties())
        end
    end
    return results
end

module.powerSource = function() return iokit.power.currentPowerSource() end

module.timeRemaining = function() return iokit.power.estimatedTimeRemaining() / 60 end

module.warningLevel = function() return iokit.power.batteryWarningLevel() end

module.cycles = function()
    local appleSmartBattery = module._appleSmartBattery() or {}
    return appleSmartBattery.CycleCount
end

module.name = function()
    local powerSourceDescription = module._powerSources() or { {} }
    return powerSourceDescription[1].Name
end

module.maxCapacity = function()
    local appleSmartBattery = module._appleSmartBattery() or {}
    return appleSmartBattery.AppleRawMaxCapacity
end

module.capacity = function()
    local appleSmartBattery = module._appleSmartBattery() or {}
    return appleSmartBattery.AppleRawCurrentCapacity
end

module.designCapacity = function()
    local appleSmartBattery = module._appleSmartBattery() or {}
    return appleSmartBattery.DesignCapacity
end

module.percentage = function()
    local powerSourceDescription = module._powerSources() or { {} }
    local appleSmartBattery      = module._appleSmartBattery() or {}
    local maxCapacity = powerSourceDescription[1]["Max Capacity"] or appleSmartBattery["MaxCapacity"]
    local curCapacity = powerSourceDescription[1]["Current Capacity"] or appleSmartBattery["CurrentCapacity"]

    if maxCapacity and curCapacity then
        return 100.0 * curCapacity / maxCapacity
    else
        return nil
    end
end

module.voltage = function()
    local appleSmartBattery = module._appleSmartBattery() or {}
    return appleSmartBattery.Voltage
end

module.amperage = function()
    local appleSmartBattery = module._appleSmartBattery() or {}
    return appleSmartBattery.Amperage
end

module.watts = function()
    local appleSmartBattery = module._appleSmartBattery() or {}
    local voltage           = appleSmartBattery.Voltage
    local amperage          = appleSmartBattery.Amperage

    if amperage and voltage then
        return (amperage * voltage) / 1000000
    else
        return nil
    end
end

module.health = function()
    local powerSourceDescription = module._powerSources() or { {} }
    return powerSourceDescription[1].BatteryHealth
end

module.healthCondition = function()
    local powerSourceDescription = module._powerSources() or { {} }
    return powerSourceDescription[1].BatteryHealthCondition
end

module.timeToFullCharge = function()
    local powerSourceDescription = module._powerSources() or { {} }
    return powerSourceDescription[1]["Time to Full Charge"]
end

module.isCharging = function()
    local powerSourceDescription = module._powerSources() or { {} }
    return powerSourceDescription[1]["Is Charging"]
end

module.isCharged = function()
    local powerSourceDescription = module._powerSources() or { {} }
    return powerSourceDescription[1]["Is Charged"]
end

module.isFinishingCharge = function()
    local powerSourceDescription = module._powerSources() or { {} }
    return powerSourceDescription[1]["Is Finishing Charge"]
end

module.powerSourceType = function()
    local powerSourceDescription = module._powerSources() or { {} }
    return powerSourceDescription[1]["Power Source State"]
end

module.batteryType = function()
    local powerSourceDescription = module._powerSources() or { {} }
    return powerSourceDescription[1]["Type"]
end

module.adapterSerialNumber = function()
    local adapterDetails = module._adapterDetails() or {}
    return adapterDetails.SerialNumber or adapterDetails.SerialString
end

module.batterySerialNumber = function()
    local powerSourceDescription = module._powerSources() or { {} }
    return powerSourceDescription[1]["Hardware Serial Number"]
end

module.getAll = function()
    local t = {}

    for _, v in ipairs(check_list) do
        t[v] = module[v]()
        if t[v] == nil then t[v] = "n/a" end
    end

    return ls.makeConstantsTable(t)
end

module._report = function()
    return {
        _adapterDetails    = module._adapterDetails()    or "** not available **",
        _powerSources      = module._powerSources()      or "** not available **",
        _appleSmartBattery = module._appleSmartBattery() or "** not available **",
        _iopmBatteryInfo   = module._iopmBatteryInfo()   or "** not available **",
    }
end

--   privateBluetoothBatteryInfo = <function 25>,
--   watcher = {...},

-- Return Module Object --------------------------------------------------

return module
