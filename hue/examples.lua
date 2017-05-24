local lights = {
    h.default:paths("lights", { name = "BR North" })[1] .. "/state",
    h.default:paths("lights", { name = "BR East" })[1] .. "/state",
    h.default:paths("lights", { name = "BR South" })[1] .. "/state",
    h.default:paths("lights", { name = "BR West" })[1] .. "/state",
}

local pos = 0
for i, v in ipairs(lights) do h.default:put(v, { on = false, transitiontime = 0 }) end
lightShow = true
local t
t = hs.timer.doEvery(1, function()
    if lightShow then
        h.default:put(lights[pos + 1], { on = false, transitiontime = 0 })
        pos = (pos + 1) % #lights
        h.default:put(lights[pos + 1], { on = true, transitiontime = 0, bri = 254 })
    else
        for i, v in ipairs(lights) do h.default:put(v, { on = true, transitiontime = 0, bri = 254 }) end
        t:stop()
        t = nil
    end
end)



local colorLight = h.default:paths("lights", { type = "color" }, true)[1]
for i, v in ipairs(h.default:paths("lights", {})) do h.default:put(v .. "/state", { on = (v == colorLight) }) end
lightShow = true
local t2
t2 = hs.timer.doEvery(1, function()
    if lightShow then
        local r = h.hueColor({ red = math.random(), blue = math.random(), green = math.random() })
--         r.transitiontime = 0
        r.bri = 0
        h.default:put(colorLight .. "/state", r)
    else
        for i, v in ipairs(h.default:paths("lights", {})) do h.default:put(v .. "/state", { on = true, ct = 366, bri = 254 }) end
        t2:stop()
        t2 = nil
    end
end)
