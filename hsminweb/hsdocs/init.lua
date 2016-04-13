--
-- This is an example web server which serves dynamically generated Hammerspoon documentation
--
-- It's rough, but serves as an example of using lua in templates with `hs._asm.hsminweb`
--

local module = {}
local hsminweb = require("hs._asm.hsminweb")

module.documentRoot = package.searchpath("hs._asm.hsminweb.hsdocs", package.path):match("^(/.*/).*%.lua$")
module.port         = 12345

module.start = function()
    if module.server then
        error("documentation server already running")
    else
        module.server = hsminweb.new(module.documentRoot)
        module.server:port(module.port)
                     :name("Hammerspoon Documentation")
                     :bonjour(true)
                     :luaTemplateExtension("lp")
                     :directoryIndex{
                         "index.html", "index.lp",
                     }:start()
    end
end

module.stop = function()
    if not module.server then
        error("documentation server not running")
    else
        module.server:stop()
        module.server = nil
    end
end

return module