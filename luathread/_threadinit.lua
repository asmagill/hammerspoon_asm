-- This is the required initialization script for a lua thread instance.  This will be
-- installed into the proper place by the Makefile or when you expand the pre-compiled
-- archive.
--
-- If you wish to add additional initialization code of your own, you can create a file
-- in your Hammerspoon configuration directory (usually ~/.hammerspoon) named
-- _init.*name*.lua (if you want to load it only when you create a thread with a
-- particular name) or _init.lua, if you want to load it for any thread that does not
-- match a name-specific file.  If you create such a file, it will be executed *after*
-- this file completes.

local instanceName, assignments = ...

if _instance then

    debug.sethook(function(t,l)
        if (_instance:isCancelled()) then
            error("** thread cancelled")
        end
    end, "", 1000)

    _sharedTable = {}
    setmetatable(_sharedTable, {
        __index    = function(t, k) return _instance:get(k) end,
        __newindex = function(t, k, v) _instance:set(k, v) end,
        __pairs    = function(t)
            local keys, values = _instance:keys(), {}
            for k, v in ipairs(keys) do values[v] = _instance:get(v) end
            return function(t, i)
                i = table.remove(keys, 1)
                if i then
                    return i, values[i]
                else
                    return nil
                end
            end, _sharedTable, nil
        end,
        __len      = function(t)
            local len, pos = 0, 1
            while _instance:get(pos) do
                len = pos
                pos = pos + 1
            end
            return len
        end,
        __metatable = "shared data:".._instance:name()
    })

    package.path  = assignments.path
    package.cpath = assignments.cpath

    hs= {
        rawprint             = print, -- save internal function, in case needed
        configdir            = assignments.configdir,
        processInfo          = assignments.processInfo,
        docstrings_json_file = assignments.docstrings_json_file,
    }

    print      = function(...) _instance:print(...) end
    hs.printf  = function(fmt,...) return print(string.format(fmt,...)) end
    hs.reload  = function(...) _instance:reload(...) end
    hs._exit   = function(...) _instance:cancel(...) end
    os.exit    = hs._exit


    hs.execute = function(command, user_env)
        local f
        if user_env then
          f = io.popen(os.getenv("SHELL")..[[ -l -i -c "]]..command..[["]], 'r')
        else
          f = io.popen(command, 'r')
        end
        local s = f:read('*a')
        local status, exit_type, rc = f:close()
        return s, status, exit_type, rc
    end

    local logger = require("hs.logger").new("LSinThread", "debug")
    hs.luaSkinLog       = logger

    hs.handleLogMessage = function(level, message)
--         local levelLabels = { "ERROR", "WARNING", "INFO", "DEBUG", "VERBOSE" }
-- we don't want to have to require anything which isn't safe as-is from Hammerspoon in this file
-- to minimize problems if they don't install the entire set of re-compiled supported modules
--       -- may change in the future if this fills crashlog with too much useless stuff
--         if level ~= 5 then
--             crashLog(string.format("(%s) %s", (levelLabels[level] or tostring(level)), message))
--         end

        if level == 5 then     logger.v(message) -- LS_LOG_VERBOSE
        elseif level == 4 then logger.d(message) -- LS_LOG_DEBUG
        elseif level == 3 then logger.i(message) -- LS_LOG_INFO
        elseif level == 2 then logger.w(message) -- LS_LOG_WARN
        elseif level == 1 then logger.e(message) -- LS_LOG_ERROR
  --           hs.showError(message)
        else
            print("*** UNKNOWN LOG LEVEL: "..tostring(level).."\n\t"..message)
        end
    end

    if (package.searchpath("hs._luathreadcoreadditions", package.path)) then
        require("hs._luathreadcoreadditions")
    end

    local runstring = function(s)
        --print("runstring")
        local fn, err = load("return " .. s)
        if not fn then fn, err = load(s) end
        if not fn then return tostring(err) end

        local str = ""
        local startTime = _instance:timestamp()
        local results = table.pack(xpcall(fn,debug.traceback))
        local endTime   = _instance:timestamp()

        local sharedResults = { n = results.n - 1 }
        for i = 2,results.n do
            if i > 2 then str = str .. "\t" end
            str = str .. tostring(results[i])
            sharedResults[i - 1] = results[i]
        end
        _sharedTable._results = { start = startTime, stop = endTime, results = sharedResults }
        return str
    end

    print("-- ".._VERSION..", Hammerspoon instance "..instanceName)

    local custominit = assignments.configdir.."/_init."..instanceName..".lua"
    if not os.execute("[ -f "..custominit.." ]") then
        custominit = assignments.configdir.."/_init.lua"
        if not os.execute("[ -f "..custominit.." ]") then
            custominit = nil
        end
    end
    if custominit then
        local fn, err
        print("-- Loading " .. custominit)
        fn, err = loadfile(custominit)
        if fn then
            fn, err = xpcall(fn, debug.traceback)
        end
        if not fn then
            print("\n"..err.."\n")
        end
    end
    print "-- Done."
    _instance:flush()
    return runstring
else
    error("_instance not defined, or not in child thread")
end