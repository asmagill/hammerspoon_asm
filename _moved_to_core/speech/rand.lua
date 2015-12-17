-- creates random words for testing speech with something less monotonous than the same thing
-- over and over and over and over and...
--
-- > sp, r = require("hs.speech"), require("hs.speech.rand")
-- > v = sp.new():setCallback(function(...) print(inspect(table.pack(...)):gsub("[\r\n]","")) end):speak(r.random(5))

local f = io.open("/usr/share/dict/words", "r")
local a = f:read("a")
f:close()
local module = {}

local fnutils = require("hs.fnutils")
module.words = fnutils.split(a, "[\r\n]")
module.random = function(count)
    count = tonumber(count) or 1
    local someWords = {}
    for i = 1, count, 1 do
        table.insert(someWords, module.words[math.random(1,#module.words)])
    end
    return table.concat(someWords, " ")
end

return module