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

local instanceName, configdir, path, cpath = ...

if _instance then

    print = function(...) _instance:print(...) end

    os.exit = function(...) _instance:cancel(...) end

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

    package.path  = path
    package.cpath = cpath

    hs            = {}
    hs.printf     = function(fmt,...) return print(string.format(fmt,...)) end
    hs.configdir  = configdir
    hs._exit      = os.exit
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

    hs.inspect    = require("hs.inspect")

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

    local custominit = configdir.."/_init."..instanceName..".lua"
    if not os.execute("[ -f "..custominit.." ]") then
        custominit = configdir.."/_init.lua"
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