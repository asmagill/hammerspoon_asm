mb = require("hs._asm.guitk.menubar")

m   = mb.menu.new("myMenu"):callback(function(...) print("m", timestamp(), finspect(...)) end)

si  = mb.new(true):callback(function(...) print("si", timestamp(), finspect(...)) end)
                 :title(hs.styledtext.new("yes", { color = { green = 1 } }))
                 :alternateTitle(hs.styledtext.new("no", { color = { red = 1 } }))
                 :menu(m)

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
end
