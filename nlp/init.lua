--- === hs._asm.nlp ===
---
--- Stuff about the module

local USERDATA_TAG = "hs._asm.nlp"
local module       = require(USERDATA_TAG..".nlpObjc")

local basePath = package.searchpath(USERDATA_TAG, package.path)
if basePath then
    basePath = basePath:match("^(.+)/init.lua$")
    if require"hs.fs".attributes(basePath .. "/docs.json") then
        require"hs.doc".registerJSONFile(basePath .. "/docs.json")
    end
end

-- if hs.text exists, load it for utf16 compatibility
if package.searchpath("hs.text", package.path) then require("hs.text") end

-- settings with periods in them can't be watched via KVO with hs.settings.watchKey, so
-- in general it's a good idea not to include periods
-- local SETTINGS_TAG = USERDATA_TAG:gsub("%.", "_")
-- local settings     = require("hs.settings")
-- local log          = require("hs.logger").new(USERDATA_TAG, settings.get(SETTINGS_TAG .. "_logLevel") or "warning")

module.tokenizer = module.available()          and require(USERDATA_TAG..".tokenizer") or {}
module.language  = module.available()          and require(USERDATA_TAG..".language")  or {}
module.tagger    = module.available()          and require(USERDATA_TAG..".tagger")    or {}
module.embedding = module.embeddingAvailable() and require(USERDATA_TAG..".embedding") or {}

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

module.tokenizer.types    = ls.makeConstantsTable(module.tokenizer.types    or {})
module.language.languages = ls.makeConstantsTable(module.language.languages or {})
module.tagger.units       = ls.makeConstantsTable(module.tagger.units       or {})
module.tagger.options     = ls.makeConstantsTable(module.tagger.options     or {})

-- Return Module Object --------------------------------------------------

return module
