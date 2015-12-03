--- === hs.speech ===
---
--- This module provides access to the Speech Synthesizer component of OS X.
---
--- The speech synthesizer functions and methods provide access to OS X's Text-To-Speech capabilities and facilitates generating speech output both to the currently active audio device and to an AIFF file.
---
--- A discussion concerning the embedding of commands into the text to be spoken can be found at https://developer.apple.com/library/mac/documentation/UserExperience/Conceptual/SpeechSynthesisProgrammingGuide/FineTuning/FineTuning.html#//apple_ref/doc/uid/TP40004365-CH5-SW6.  It is somewhat dated and specific to the older MacinTalk style voices, but still contains some information relevant to the more modern higer quality voices as well in its discussion about embedded commands.
---
--- Disclaimer:  This module attempts to be a faithful representation of the capabilities and features of the NSSpeechSynthesizer object class in OS X.  However, there appear to be some inconsistencies in the documentation for this class and a few features that appear to have been broken at least as far back as OS X 10.5 according to some reports I have been able to find.  Most of the module is stable and works quite well for generating synthesized speech.  It is certainly more powerful than the Terminal's `say` command in that Hammerspoon can receive call back notifications as each word is spoken to provide visual feedback, for example, and this module can generate sound files containing synthesized speech in a non-blocking manner.  However, some of the documented properties and functions do not seem to work as described.  I have noted these in this documentation by labeling these sections with *Special Note*.  If you have suggestions or have found fixes or clarifications for these sections, please do not hesitate to post an issue at the Hammerspoon github site and the appropriate fixes will be included.

--- === hs.speech.listener ===
---
--- This module provides access to the Speech Recognizer component of OS X.
---
--- The speech recognizer functions and methods provide a way to add commands which may be issued to Hammerspoon through spoken words and phrases to trigger a callback.

local module = require("hs.speech.internal")
local log    = require("hs.logger").new("hs.speech","warning")
module.log = log
module._registerLogForC(log)
module._registerLogForC = nil

module.listener = require("hs.speech.listener")
module.listener._registerLogForC(log)
module.listener._registerLogForC = nil

-- private variables and methods -----------------------------------------

local _kMetaTable = {}
_kMetaTable._k = {}
_kMetaTable.__index = function(obj, key)
        if _kMetaTable._k[obj] then
            if _kMetaTable._k[obj][key] then
                return _kMetaTable._k[obj][key]
            else
                for k,v in pairs(_kMetaTable._k[obj]) do
                    if v == key then return k end
                end
            end
        end
        return nil
    end
_kMetaTable.__newindex = function(obj, key, value)
        error("attempt to modify a table of constants",2)
        return nil
    end
_kMetaTable.__pairs = function(obj) return pairs(_kMetaTable._k[obj]) end
_kMetaTable.__tostring = function(obj)
        local result = ""
        if _kMetaTable._k[obj] then
            local width = 0
            for k,v in pairs(_kMetaTable._k[obj]) do width = width < #k and #k or width end
            for k,v in require("hs.fnutils").sortByKeys(_kMetaTable._k[obj]) do
                result = result..string.format("%-"..tostring(width).."s %s\n", k, tostring(v))
            end
        else
            result = "constants table missing"
        end
        return result
    end
_kMetaTable.__metatable = _kMetaTable -- go ahead and look, but don't unset this

local _makeConstantsTable = function(theTable)
    local results = setmetatable({}, _kMetaTable)
    _kMetaTable._k[results] = theTable
    return results
end

-- Public interface ------------------------------------------------------

if module.properties        then module.properties        = _makeConstantsTable(module.properties)         end
if module.speakingModes     then module.speakingModes     = _makeConstantsTable(module.speakingModes)      end
if module.characterModes    then module.characterModes    = _makeConstantsTable(module.characterModes)     end
if module.commandDelimiters then module.commandDelimiters =  _makeConstantsTable(module.commandDelimiters) end

-- Return speech Object --------------------------------------------------

return module
