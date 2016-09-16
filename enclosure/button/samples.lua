c = require("hs._asm.canvas")
a = c.new{x = 100, y = 100, h = 500, w = 500}:show()
a[1] = {
  action = "fill",
  fillColor = { alpha = 0.4, white = 1.0 },
  padding = 0,
  type = "rectangle",
}
a[2] = {
  action = "fill",
  fillColor = { image = graphpaperImage },
  padding = 0,
  type = "rectangle",
}
a:mouseCallback(function(...)
    local args = table.pack(...)
    print(inspect(args))
    if args[2] == "_subview_" then
        local b = args[3]
        print(b:state(), b:value(), b:value(true))
    end
end)
button = require("hs._asm.canvas.button")
for i,v in ipairs({ "momentaryLight", "pushOnPushOff", "toggle", "switch", "radio", "momentaryChange", "onOff", "momentaryPushIn", "accelerator", "multiLevelAccelerator" }) do
    a[2 + i] = {
        type = "view",
        frame = { x = 50, y = 50 * (i - 1), h = 50, w = 400 },
        view = button.new(v):title(v):alternateTitle("Not " .. v)
    }
end

c = require("hs._asm.canvas")
a = c.new{x = 100, y = 100, h = 500, w = 500}:show()
a[1] = {
  action = "fill",
  fillColor = { alpha = 0.4, white = 1.0 },
  padding = 0,
  type = "rectangle",
}
a[2] = {
  action = "fill",
  fillColor = { image = graphpaperImage },
  padding = 0,
  type = "rectangle",
}
a:mouseCallback(function(...)
    local args = table.pack(...)
    print(inspect(args))
    if args[2] == "_subview_" then
        local b = args[3]
        print(b:title(), b:state(), b:value(), b:value(true))
    end
end)
button = require("hs._asm.canvas.button")
for i,v in ipairs({ "momentaryLight", "pushOnPushOff", "toggle", "switch", "radio", "momentaryChange", "onOff", "momentaryPushIn", "accelerator", "multiLevelAccelerator" }) do
    a[2 + i] = {
        type = "view",
        frame = { x = 50, y = 50 * (i - 1), h = 50, w = 400 },
        view = button.new("radio"):title(v):alternateTitle("Not " .. v)
    }
end