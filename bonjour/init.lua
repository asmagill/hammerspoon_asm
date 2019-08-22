--- === hs._asm.bonjour ===
---
--- Find and publish network services advertised by multicast DNS (Bonjour) with Hammerspoon.
---
--- This module will allow you to discover services advertised on your network through multicast DNS and publish services offered by your computer.

--- === hs._asm.bonjour.service ===
---
--- Represents the service records that are discovered or published by the hs._asm.bonjour module.
---
--- This module allows you to explore the details of discovered services including ip addresses and text records, and to publish your own multicast DNS advertisements for services on your computer. This can be useful to advertise network services provided by other Hammerspoon modules or other applications on your computer which do not publish their own advertisements already.
---
--- This module will *not* allow you to publish proxy records for other hosts on your local network.
--- Additional submodules which may address this limitation as well as provide additional functions available with Apple's dns-sd library are being considered but there is no estimated timeframe at present.

local USERDATA_TAG = "hs._asm.bonjour"
local module       = require(USERDATA_TAG .. ".internal")
module.service     = require(USERDATA_TAG .. ".service")

local browserMT = hs.getObjectMetatable(USERDATA_TAG)
local serviceMT = hs.getObjectMetatable(USERDATA_TAG .. ".service")

local basePath = package.searchpath(USERDATA_TAG, package.path)
if basePath then
    basePath = basePath:match("^(.+)/init.lua$")
    if require"hs.fs".attributes(basePath .. "/docs.json") then
        require"hs.doc".registerJSONFile(basePath .. "/docs.json")
    end
end

local collectionPrevention = {}
local task    = require("hs.task")
local host    = require("hs.host")
local fnutils = require("hs.fnutils")
local timer   = require("hs.timer")

-- local log = require("hs.logger").new(USERDATA_TAG, require"hs.settings".get(USERDATA_TAG .. ".logLevel") or "warning")

-- private variables and methods -----------------------------------------

-- currently, except for _services._dns-sd._udp., these should be limited to 2 parts, but
-- since one exception exists, let's be open to more in the future
local validateServiceFormat = function(service)
    -- first test: is it a string?
    local isValid = (type(service) == "string")

    -- does it end with _tcp or _udp (with an optional trailing period?)
    if isValid then
        isValid = (service:match("_[uU][dD][pP]%.?$") or service:match("_[tT][cC][pP]%.?$")) and true or false
    end

    -- does each component separated by a period start with an underscore?
    if isValid then
        for part in service:gmatch("([^.]*)%.") do
            isValid = (part:sub(1,1) == "_") and (#part > 1)
            if not isValid then break end
        end
    end

    -- finally, make sure there are at least two parts to the service type
    if isValid then
        isValid = service:match("%g%.%g") and true or false
    end

    return isValid
end

-- Public interface ------------------------------------------------------

browserMT._browserFindServices = browserMT.findServices
browserMT.findServices = function(self, ...)
    local args = table.pack(...)
    if args.n > 0 and type(args[1]) == "string" then
        if not validateServiceFormat(args[1]) then
            error("service type must be in the format of _service._protocol. where _protocol is _tcp or _udp", 2)
        end
    end
    return self:_browserFindServices(...)
end

--- hs._asm.bonjour.service.new(host, service, port, [domain]) -> serviceObject
--- Constructor
--- Returns a new serviceObject for advertising a service provided by your computer.
---
--- Parameters:
---  * `name`    - The name of the service being advertised. This does not have to be the hostname of the machine. If you specify an empty string, the computers hostname will be used, however.
---  * `service` - a string specifying the service being advertised. This string should be specified in the format of '_service._protocol.' where _protocol is one of '_tcp' or '_udp'. Examples of common service types can be found in `hs._asm.bonjour.serviceTypes`.
---  * `port`    - an integer specifying the tcp or udp port the service is provided at
---  * `domain`  - an optional string specifying the domain you wish to advertise this service in.
---
--- Returns:
---  * the newly created service object, or nil if there was an error
---
--- Notes:
---  * If the name specified is not unique on the network for the service type specified, then a number will be appended to the end of the name. This behavior cannot be overridden and can only be detected by checking [hs._asm.bonjour.service:name](#name) after [hs._asm.bonjour.service:publish](#publish) is invoked to see if the name has been changed from what you originally assigned.
---
---  * The service will not be advertised until [hs._asm.bonjour.service:publish](#publish) is invoked on the serviceObject returned.
---
---  * If you do not specify the `domain` paramter, your default domain, usually "local" will be used.
module.service._new = module.service.new
module.service.new = function(...)
    local args = table.pack(...)
    if args.n > 1 and type(args[2]) == "string" then
        if not validateServiceFormat(args[2]) then
            error("service type must be in the format of _service._protocol. where _protocol is _tcp or _udp", 2)
        end
    end
    return module.service._new(...)
end

--- hs._asm.bonjour.service.remote(name, service, [domain]) -> serviceObject
--- Constructor
--- Returns a new serviceObject for a remote machine (i.e. not the users computer) on your network offering the specified service.
---
--- Parameters:
---  * `name`    - a string specifying the name of the advertised service on the network to locate. Often, but not always, this will be the hostname of the machine providing the desired service.
---  * `service` - a string specifying the service type. This string should be specified in the format of '_service._protocol.' where _protocol is one of '_tcp' or '_udp'. Examples of common service types can be found in `hs._asm.bonjour.serviceTypes`.
---  * `domain`  - an optional string specifying the domain the service belongs to.
---
--- Returns:
---  * the newly created service object, or nil if there was an error
---
--- Notes:
---  * In general you should not need to use this constructor, as they will be created automatically for you in the callbacks to `hs._asm.bonjour:findServices`.
---  * This method can be used, however, when you already know that a specific service should exist on the network and you wish to resolve its current IP addresses or text records.
---
---  * Resolution of the service ip address, hostname, port, and current text records will not occur until [hs._asm.bonjour.service:publish](#publish) is invoked on the serviceObject returned.
---
---  * The macOS API specifies that an empty domain string (i.e. specifying the `domain` parameter as "" or leaving it off completely) should resolve in using the default domain for the computer; in my experience this results in an error when attempting to resolve the serviceObjects ip addresses if I don't specify "local" explicitely. In general this shouldn't be an issue if you limit your use of remote serviceObjects to those returned by `hs._asm.bonjour:findServices` as the domain of discovery will be included in the object for you automatically. If you do try to create these objects independantly yourself, be aware that attempting to use the "default domain" rather than specifying it explicitely will probably not work as expected.
module.service._remote = module.service.remote
module.service.remote = function(...)
    local args = table.pack(...)
    if args.n > 1 and type(args[2]) == "string" then
        if not validateServiceFormat(args[2]) then
            error("service type must be in the format of _service._protocol. where _protocol is _tcp or _udp", 2)
        end
    end
    return module.service._remote(...)
end

--- hs._asm.bonjour.networkServices(callback, [timeout]) -> none
--- Function
--- Returns a list of service types being advertised on your local network.
---
--- Parameters:
---  * `callback` - a callback function which should expect one
---  * `timeout`  - an optional number, default 5, specifying the maximum number of seconds after the most recently received service type Hammerspoon should wait trying to identify advertised service types before finishing its query and invoking the callback.
---
--- Returns:
---  * None
---
--- Notes:
---  * This function is a convienence wrapper to [hs._asm.bonjour:findServices](#findServices) which collects the results from multiple callbacks made to `findServices` and returns them all at once to the callback function provided as an argument to this function.
---
---  * Because this function collects the results of multiple callbacks before invoking its own callback, the `timeout` value specified indicates the maximum number of seconds to wait after the latest value received by `findServices` unless the macOS specifies that it believes there are no more service types to identify.
---    * This is a best guess made by the macOS which may not always be accurate if your local network is particularly slow or if there are machines on your network which are slow to respond.
---    * See [hs._asm.bonjour:findServices](#findServices) for more details if you need to create your own query which can persist for longer periods of time or require termination logic that ignores the macOS's best guess.
module.networkServices = function(callback, timeout)
    assert(type(callback) == "function" or (getmetatable(callback) or {})._call, "function expected for argument 1")
    if (timeout) then assert(type(timeout) == "number", "number expected for optional argument 2") end
    timeout = timeout or 5

    local uuid = host.uuid()
    local job = module.new()
    collectionPrevention[uuid] = { job = job, results = {} }
    job:findServices("_services._dns-sd._udp.", "local", function(b, msg, state, obj, more)
        local internals = collectionPrevention[uuid]
        if msg == "service" and state then
            table.insert(internals.results, obj:name() .. "." .. obj:type():match("^(.+)local%.$"))
            if internals.timer then
                internals.timer:stop()
                internals.timer = nil
            end
            if not more then
                internals.timer = timer.doAfter(timeout, function()
                    internals.job:stop()
                    internals.job = nil
                    internals.timer = nil
                    collectionPrevention[uuid] = nil
                    callback(internals.results)
                end)
            end
        end
    end)
end

--- hs._asm.bonjour.machineServices(target, callback) -> none
--- Function
--- Polls a host for the service types it is advertising via multicast DNS.
---
--- Parameters:
---  * `target`   - a string specifying the target host to query for advertised service types
---  * `callback` - a callback function which will be invoked when the service type query has completed. The callback should expect one argument which will either be an array of strings specifying the service types the target is advertising or a string specifying the error that occurred.
---
--- Returns:
---  * None
---
--- Notes:
---  * this function may not work for all clients implementing multicast DNS; it has been successfully tested with macOS and Linux targets running the Avahi Daemon service, but has generally returned an error when used with minimalist implementations found in common IOT devices and embedded electronics.
module.machineServices = function(target, callback)
    assert(type(target) == "string", "string expected for argument 1")
    assert(type(callback) == "function" or (getmetatable(callback) or {})._call, "function expected for argument 2")

    local uuid = host.uuid()
    local job = task.new("/usr/bin/dig", function(r, o, e)
        local results
        if r == 0 then
            results = {}
            for i, v in ipairs(fnutils.split(o, "[\r\n]+")) do
                table.insert(results, v:match("^(.+)local%.$"))
            end
        else
            results = (e == "" and o or e):match("^[^ ]+ (.+)$"):gsub("[\r\n]", "")
        end
        collectionPrevention[uuid] = nil
        callback(results)
    end, { "+short", "_services._dns-sd._udp.local", "ptr", "@" .. target, "-p", "5353" })
    collectionPrevention[uuid] = job:start()
end

--- hs._asm.bonjour.serviceTypes
--- Constant
--- A list of common service types which can used for discovery through this module.
---
--- Notes:
---  * This list was generated from the output of `avahi-browse -b` and `avahi-browse -bk` from the avahi-daemon/stable,now 0.7-4+b1 armhf package under Raspbian GNU/Linux 10.
---  * This list is by no means complete and is provided solely for the purposes of providing examples. Additional service types can be discovered quite easily using Google or other search engines.
---
---  * You can view the contents of this table in the Hammerspoon Console by entering `require("hs._asm.bonjour").serviceTypes` into the input field.
module.serviceTypes = ls.makeConstantsTable({
    ["_pulse-server._tcp."]      = "PulseAudio Sound Server",
    ["_postgresql._tcp."]        = "PostgreSQL Server",
    ["_adisk._tcp."]             = "Apple TimeMachine",
    ["_webdav._tcp."]            = "WebDAV File Share",
    ["_timbuktu._tcp."]          = "Timbuktu Remote Desktop Control",
    ["_acrobatSRV._tcp."]        = "Adobe Acrobat",
    ["_rfb._tcp."]               = "VNC Remote Access",
    ["_workstation._tcp."]       = "Workstation",
    ["_dpap._tcp."]              = "Digital Photo Sharing",
    ["_mumble._tcp."]            = "Mumble Server",
    ["_apt._tcp."]               = "APT Package Repository",
    ["_libvirt._tcp."]           = "Virtual Machine Manager",
    ["_ssh._tcp."]               = "SSH Remote Terminal",
    ["_svn._tcp."]               = "Subversion Revision Control",
    ["_telnet._tcp."]            = "Telnet Remote Terminal",
    ["_imap._tcp."]              = "IMAP Mail Access",
    ["_rtp._udp."]               = "RTP Realtime Streaming Server",
    ["_webdavs._tcp."]           = "Secure WebDAV File Share",
    ["_dacp._tcp."]              = "iTunes Remote Control",
    ["_airport._tcp."]           = "Apple AirPort",
    ["_printer._tcp."]           = "UNIX Printer",
    ["_sftp-ssh._tcp."]          = "SFTP File Transfer",
    ["_odisk._tcp."]             = "DVD or CD Sharing",
    ["_udisks-ssh._tcp."]        = "Remote Disk Management",
    ["_presence._tcp."]          = "iChat Presence",
    ["_pop3._tcp."]              = "POP3 Mail Access",
    ["_iax._udp."]               = "Asterisk Exchange",
    ["_rss._tcp."]               = "Web Syndication RSS",
    ["_xpra._tcp."]              = "Xpra Session Server",
    ["_adobe-vc._tcp."]          = "Adobe Version Cue",
    ["_shifter._tcp."]           = "Window Shifter",
    ["_pdl-datastream._tcp."]    = "PDL Printer",
    ["_home-sharing._tcp."]      = "Apple Home Sharing",
    ["_domain._udp."]            = "DNS Server",
    ["_smb._tcp."]               = "Microsoft Windows Network",
    ["_vlc-http._tcp."]          = "VLC Streaming",
    ["_omni-bookmark._tcp."]     = "OmniWeb Bookmark Sharing",
    ["_daap._tcp."]              = "iTunes Audio Access",
    ["_ksysguard._tcp."]         = "KDE System Guard",
    ["_pgpkey-hkp._tcp."]        = "GnuPG/PGP HKP Key Server",
    ["_distcc._tcp."]            = "Distributed Compiler",
    ["_bzr._tcp."]               = "Bazaar",
    ["_touch-able._tcp."]        = "iPod Touch Music Library",
    ["_ipps._tcp."]              = "Secure Internet Printer",
    ["_https._tcp."]             = "Secure Web Site",
    ["_http._tcp."]              = "Web Site",
    ["_tp-https._tcp."]          = "Thousand Parsec Server (Secure HTTP Tunnel)",
    ["_ntp._udp."]               = "NTP Time Server",
    ["_skype._tcp."]             = "Skype VoIP",
    ["_raop._tcp."]              = "AirTunes Remote Audio",
    ["_net-assistant._udp."]     = "Apple Net Assistant",
    ["_pulse-sink._tcp."]        = "PulseAudio Sound Sink",
    ["_nfs._tcp."]               = "Network File System",
    ["_h323._tcp."]              = "H.323 Telephony",
    ["_presence_olpc._tcp."]     = "OLPC Presence",
    ["_tps._tcp."]               = "Thousand Parsec Server (Secure)",
    ["_realplayfavs._tcp."]      = "RealPlayer Shared Favorites",
    ["_rtsp._tcp."]              = "RTSP Realtime Streaming Server",
    ["_pulse-source._tcp."]      = "PulseAudio Sound Source",
    ["_afpovertcp._tcp."]        = "Apple File Sharing",
    ["_remote-jukebox._tcp."]    = "Remote Jukebox",
    ["_ipp._tcp."]               = "Internet Printer",
    ["_tftp._udp."]              = "TFTP Trivial File Transfer",
    ["_mpd._tcp."]               = "Music Player Daemon",
    ["_lobby._tcp."]             = "Gobby Collaborative Editor Session",
    ["_tp-http._tcp."]           = "Thousand Parsec Server (HTTP Tunnel)",
    ["_sip._udp."]               = "SIP Telephony",
    ["_ldap._tcp."]              = "LDAP Directory Server",
    ["_MacOSXDupSuppress._tcp."] = "MacOS X Duplicate Machine Suppression",
    ["_tp._tcp."]                = "Thousand Parsec Server",
    ["_ftp._tcp."]               = "FTP File Transfer",
    ["_see._tcp."]               = "SubEthaEdit Collaborative Text Editor",
})

-- Return Module Object --------------------------------------------------

return module
