local guitk      = require("hs._asm.guitk")
local styledtext = require("hs.styledtext")

local module = {}

local gui = guitk.new{x = 100, y = 100, h = 300, w = 300 }:show()
local manager = guitk.manager.new()
gui:contentManager(manager)

manager:add(guitk.element.textfield.newLabel("I am a label, not selectable"):tooltip("newLabel"))
manager:add(guitk.element.textfield.newLabel(styledtext.new({
    "I am a StyledText selectable label",
    { starts = 8,  ends = 13, attributes = { color = { red  = 1 }, font = { name = "Helvetica-Bold", size = 12 } } },
    { starts = 14, ends = 17, attributes = { color = { blue = 1 }, font = { name = "Helvetica-Oblique", size = 12 } } },
    { starts = 19, ends = 28, attributes = { strikethroughStyle = styledtext.lineAppliesTo.word | styledtext.lineStyles.single } },
})):tooltip("newLabel with styledtext"))
manager:add(guitk.element.textfield.newTextField("I am a text field"):tooltip("newTextField"))
manager:add(guitk.element.textfield.newWrappingLabel("I am a wrapping label\nthe only difference so far is that I'm selectable"):tooltip("newWrappingLabel -- still trying to figure out what that means"))

-- testing tab/shift-tab works; note if you're testing this before I create formal releases, this required a change to
-- the root module (hs._asm.guitk) as well, so you'll need to recompile that too.
manager:add(guitk.element.textfield.newTextField("Another one!"):tooltip("added for tabbing"))
manager:add(guitk.element.textfield.newTextField("Another two!"):tooltip("and shift-tabbing"))

module.manager = manager

return module
