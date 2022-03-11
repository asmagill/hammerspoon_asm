-- M1 Big Sur
--
-- 0xff00 0x04 : 1
-- 0xff00 0x05 : 57
-- 0xff00 0x0b : 2
-- 0xff00 0x17 : 1
-- 0xff00 0xff : 1
-- 0xff08 0x02 : 36
-- 0xff08 0x03 : 38


local sensors = require("hs._asm.sensors")
local canvas = require("hs.canvas")

local c = canvas.new{ x = 100, y = 100, h = 50, w = 300 }:show()
c[#c + 1] = {
    type             = "rectangle",
    action           = "fill",
    fillColor        = { blue = .5, alpha = 0.5 },
    roundedRectRadii = { xRadius = 10, yRadius = 10 },
}

c[#c + 1] = {
    id            = "page",
    type          = "text",
    frame         = { x = 0, y = 0, h = 50, w = 150 },
    text          = "0xff00",
    textSize      = 36,
    textAlignment = "center",
    textColor     = { white = 1 },
}

c[#c + 1] = {
    id            = "usage",
    type          = "text",
    frame         = { x = 150, y = 0, h = 50, w = 150 },
    text          = "0x00",
    textSize      = 36,
    textAlignment = "center",
    textColor     = { white = 1 },
}

local cr
cr = coroutine.wrap(function()
    for i = 0xff00, 0xffff, 1 do
        for j = 0x00, 0xff, 1 do
            c.page.text = string.format("0x%04x", i)
            c.usage.text = string.format("0x%02x", j)
            local n = sensors.names(i,j)
            if #n > 0 then
                print(string.format("0x%04x 0x%02x : %d", i, j, #n))
            end
            coroutine.applicationYield()
            if abort then break end
        end
        if abort then break end
    end

    cr = nil
    c = nil
    collectgarbage()
end)

cr()
