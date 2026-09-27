local inspect = require("hs.inspect")
local uitk    = require("hs._asm.uitk")
local btle    = require("hs._asm.btle")
local screen  = require("hs.screen")
local host    = require("hs.host")

local module = {}

local finspect = function(...) return (inspect({...}):gsub("%s+", " ")) end

local simpleTableCopy
simpleTableCopy = function(t, seen)
    seen = seen or {}
    if type(t) == "table" then
        if seen[t] then return seen[t] end
        local nt = {}
        seen[t] = nt
        local k, v = next(t)
        while k do
            nt[k] = simpleTableCopy(v, seen)
            k, v = next(t, k)
        end
        return nt
    else
        return t
    end
end

local defaultFrame = { x = 100, y = 100, h = 200, w = 1000 }
local xWinOffset = 20
local yWinOffset = xWinOffset

local nextDefaultWindowFrame = function()
    local screenFrame = screen.mainScreen():frame()
    local frame = simpleTableCopy(defaultFrame)
    defaultFrame.x = defaultFrame.x + xWinOffset
    defaultFrame.y = defaultFrame.y + yWinOffset

    if ((defaultFrame.x + defaultFrame.w) > (screenFrame.x + screenFrame.w)) then
        defaultFrame.x = 100
    end
    if ((defaultFrame.y + defaultFrame.h) > (screenFrame.y + screenFrame.h)) then
        defaultFrame.y = 100
    end

    return frame
end

local newWindow = function(name, frame)
    frame = frame or nextDefaultWindowFrame()
    name  = name or "window"

    local win = uitk.window(frame):title(name)
                                  :show()
                                  :styleMask("resizable") -- toggle resizable
                                  :passthroughCallback(function(...)
                                      print("windowPassthrough", finspect(...))
                                  end)
    return win
end

local btleMgr = btle.manager()
local foundPeripherals = {}

local primaryWindow  = newWindow("BTLE Devices")
local primaryContent = uitk.element.container.scroller{ h = defaultFrame.h - 25, w = defaultFrame.w}
primaryWindow:content(primaryContent:verticalScroller(true))

local tableView = uitk.element.container.table()
                  :addColumn(uitk.element.container.table.newColumn("name"):title("Name"):width(375))
                  :addColumn(uitk.element.container.table.newColumn("rssi"):title("RSSI"):width(50))
                  :addColumn(uitk.element.container.table.newColumn("state"):title("State"):width(350))
                  :addColumn(uitk.element.container.table.newColumn("adv"):title("Adv"):width(25))
                  :addColumn(uitk.element.container.table.newColumn("action"):title("Action"))
                  :passthroughCallback(function(...)
                      print("tablePassthrough", finspect(...))
                  end)
                  :alternatingRowBgColors(true)
                  :columnReordering(false)
                  :columnResizing(false)
                  :callback(function(self, row, col) end) -- ignore for now

primaryContent:document(tableView)

local dictionaryName = host.globallyUniqueString()
local tbd = uitk.toolbar.dictionary(dictionaryName)
tbd:addItem("value", {
    label = "<unknown>",
    enabled = false,
})
tbd:addItem("button", {
    label = "startScan",
    enabled = false,
    callback = function(tb, msg, item)
        if item:label() == "startScan" then
            item:label("stopScan")
            for _, v in ipairs(foundPeripherals) do v.peripheral:disconnect() end
            foundPeripherals = {}
            tableView:reloadData()
            btleMgr:startScan()
        else
            item:label("startScan")
            btleMgr:stopScan()
        end
    end,
})
tbd:allowedItems({ "value", "NSToolbarFlexibleSpaceItem", "button" })
tbd:defaultItems({ "value", "NSToolbarFlexibleSpaceItem", "button", "NSToolbarFlexibleSpaceItem" })
local primaryToolbar = uitk.toolbar(dictionaryName):canCustomize(false)
                                                   :callback(_cbinspect("toolbarFallback"))
                                                   :displayMode("label")
primaryWindow:toolbar(primaryToolbar)

btleMgr:callback(function(self, msg, ...)
    if msg == "stateChanged" then
        local state = ...
        tbd:modifyItem("value", { label = state })
        tbd:modifyItem("button", { enabled = (state == "poweredOn") })
    elseif msg == "discovered" then
        local peripheral, advertisement, rssi = ...
        local name  = peripheral:name()
        local uuid  = peripheral:identifier()
        local label = (not name or name == "") and uuid or name

        local newP = true
        for _, v in ipairs(foundPeripherals) do
            if newP then
                newP = (v.peripheral ~= peripheral)
                if not newP then -- data may have changed
                    v.adv   = advertisement
                    v.rssi  = rssi
                    v.name  = name
                    v.uuid  = uuid
                    v.label = label
                    v.err   = nil
                    table.sort(foundPeripherals, function(a, b) return a.label:lower() < b.label:lower() end)
                    tableView:reloadData()
                end
            end
         end

        if newP then
            table.insert(foundPeripherals, {
                peripheral = peripheral,
                adv        = advertisement,
                rssi       = rssi,
                name       = name,
                uuid       = uuid,
                label      = label,
            })
            table.sort(foundPeripherals, function(a, b) return a.label < b.label end)
            tableView:reloadData()
        end
    elseif msg == "connected" then
        local peripheral = ...
        tableView:reloadData()
    elseif msg == "disconnected" then
        local peripheral, err = ...
        if err then
            for _, v in ipairs(foundPeripherals) do
                if v.peripheral == peripheral then v.err = err end
            end
        end
        tableView:reloadData()
    elseif msg == "connectionFailed" then
        local peripheral, err = ...
        if err then
            for _, v in ipairs(foundPeripherals) do
                if v.peripheral == peripheral then v.err = err end
            end
        else
            v.err = "connection failed"
        end
        tableView:reloadData()
    elseif msg == "peripheralCB" then
        local callbackArguments = ...
        local peripheral, pMsg = callbackArguments[1], callbackArguments[2]
        if pMsg == "nameChanged" then
            for _, v in ipairs(foundPeripherals) do
                if v.peripheral == peripheral then
                    v.name  = peripheral:name()
                    v.uuid  = peripheral:identifier()
                    v.label = (not v.name or v.name == "") and v.uuid or v.name
                end
            end
            table.sort(foundPeripherals, function(a, b) return a.label:lower() < b.label:lower() end)
            tableView:reloadData()
        else
            print("btleMgr", msg, finspect(table.unpack(callbackArguments)))
        end
    else
        print("btleMgr", msg, finspect(...))
    end
end)

tableView:dataSourceCallback(function(tbl, action, ...)
    if action == "count" then
        return #foundPeripherals
    elseif action == "view" then
        local r, c = ...
        local row = foundPeripherals[r]
        local connectable = (row.adv.kCBAdvDataIsConnectable == 1)
        if row then
            if c == "name" then
                local value = uitk.element.textField.newLabel(row.label):expansionToolTip(true)
                local col = value:textColor()
                if not connectable then col.alpha = .5 end
                return value:textColor(col)
            elseif c == "rssi" then
                return uitk.element.textField.newLabel(tostring(row.rssi))
            elseif c == "state" then
                if row.err then
                    return uitk.element.textField.newLabel(row.err):expansionToolTip(true):textColor{ red = 1 }
                else
                    return uitk.element.textField.newLabel(row.peripheral:state())
                end
            elseif c == "adv" then
                return uitk.element.textField.newLabel("  ..."):tooltip(inspect(row.adv))
            elseif c == "action" then
                local actionMenu = uitk.menu(row.uuid)
                actionMenu[#actionMenu + 1] = {
                    title    = "Connect",
                    enabled  = (row.peripheral:state() == "disconnected"),
                    callback = function(self)
                        row.peripheral:connect()
                        row.err = nil
                        tableView:reloadData()
                    end,
                }
                actionMenu[#actionMenu + 1] = {
                    title = "-"
                }
                actionMenu[#actionMenu + 1] = {
                    title    = "Scan for services",
                    enabled  = (row.peripheral:state() == "connected"),
                    callback = function(self) end,
                }
                actionMenu[#actionMenu + 1] = {
                    title    = "Disconnect",
                    enabled  = (row.peripheral:state() == "connected"),
                    callback = function(self) row.peripheral:disconnect() end,
                }

                return uitk.element.popUpButton(actionMenu)
            end
        end
    else
        return "unknown: " .. tostring(action)
    end
    return nil
end)

module.window = primaryWindow
module.btle   = btleMgr

return module
