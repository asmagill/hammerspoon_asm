-- wrapper to redirect to updated toolbar module

local USERDATA_TAG = "hs.webview.toolbar"

if not require"hs.settings".get("useEnclosureWrappedWebview") and not require"hs.settings".get("useEnclosureWrappedWebviewToolbar") then
    local oldPath, oldCPath = package.path, package.cpath
    local appPath = hs.processInfo.resourcePath
    package.path  = appPath .. "/extensions/?.lua;" .. appPath .. "/extensions/?/init.lua;" .. package.path
    package.cpath = appPath .. "/extensions/?.so;" .. package.cpath
    local module = require(USERDATA_TAG)
    package.path, package.cpath = oldPath, oldCPath
    return module
end

local module = require("hs._asm.enclosure.toolbar")
debug.getregistry()[USERDATA_TAG] = debug.getregistry()["hs._asm.enclosure.toolbar"]
return module
