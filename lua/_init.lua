local instanceName = ...

if _instance then
    print = function(...)
        local vals = table.pack(...)
        for k = 1, vals.n do
            vals[k] = tostring(vals[k])
        end
        local str = table.concat(vals, "\t") .. "\n"
        _instance:print(str)
    end

    printf = function(fmt,...) return print(string.format(fmt,...)) end

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

    print(_VERSION.." thread instance: "..instanceName)

    return runstring
else
    error("_instance not defined, or not in child thread")
end