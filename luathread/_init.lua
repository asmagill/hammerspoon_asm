local instanceName, configdir, path, cpath = ...

if _instance then

    print = function(...)
        local vals = table.pack(...)
        for k = 1, vals.n do
            vals[k] = tostring(vals[k])
        end
        local str = table.concat(vals, "\t") .. "\n"
        _instance:print(str)
    end

    os.exit = function(...)
      _instance:cancel()
    end

    local runstring = function(s)
        --print("runstring")
        local fn, err = load("return " .. s)
        if not fn then fn, err = load(s) end
        if not fn then return tostring(err) end

        local str = ""
        local results = table.pack(xpcall(fn,debug.traceback))
        for i = 2,results.n do
            if i > 2 then str = str .. "\t" end
            str = str .. tostring(results[i])
        end
        return str
    end

    debug.sethook(function(t,l)
        if (_instance:isCancelled()) then
            error("** thread cancelled")
        end
    end, "", 1000)

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
    hs.fs         = require("hs.fs.internal")
    -- remove the elements that require LuaSkin
    hs.fs.fileUTI    = nil
    hs.fs.tagsAdd    = nil
    hs.fs.tagsGet    = nil
    hs.fs.tagsRemove = nil
    hs.fs.tagsSet    = nil

    print("-- ".._VERSION..", "..instanceName)

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

    return runstring
else
    error("_instance not defined, or not in child thread")
end