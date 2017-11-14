local mb = require("hs._asm.guitk.menubar")

-- development __gc wrapper to verify when it's being invoked
if _asm and _asm.gc and _asm.gc.patch then
    _asm.gc.patch("hs._asm.guitk.menubar")
    _asm.gc.patch("hs._asm.guitk.menubar.menu")
    _asm.gc.patch("hs._asm.guitk.menubar.menu.item")
end

local m   = mb.menu.new("myMenu"):callback(function(...) print("m", timestamp(), finspect(...)) end)

si  = mb.new(true):callback(function(...) print("si", timestamp(), finspect(...)) end)
                 :title(hs.styledtext.new("yes", { color = { green = 1 } }))
                 :alternateTitle(hs.styledtext.new("no", { color = { red = 1 } }))
                 :menu(m)

local i = 0
for k, v in hs.fnutils.sortByKeys(mb.menu.item._characterMap) do
    m:insert(mb.menu.item.new(k):callback(function(...) print("i", timestamp(), finspect(...)) end)
                                :keyEquivalent(k)
    )
    m:insert(mb.menu.item.new("Alt " .. k):callback(function(...) print("i", timestamp(), finspect(...)) end)
                                          :keyEquivalent(k)
                                          :alternate(true)
                                          :keyModifiers{ alt = true }
    )
    m:insert(mb.menu.item.new("Shift " .. k):callback(function(...) print("i", timestamp(), finspect(...)) end)
                                            :keyEquivalent(k)
                                            :alternate(true)
                                            :keyModifiers{ shift = true }
    )
    i = (i + 1) % 10
    if i == 0 then m:insert(mb.menu.item.new("-")) end
end
