--------------------------------------------------------
-- Mimic the luakit signal api functions for tables   --
-- @author Fabian Streitel <karottenreibe@gmail.com>  --
-- @author Mason Larobina  <mason.larobina@gmail.com> --
-- @copyright 2010 Fabian Streitel, Mason Larobina    --
--------------------------------------------------------

-- Grab environment we need
local assert = assert
local io = io
local ipairs = ipairs
local setmetatable = setmetatable
local string = string
local table = table
local tostring = tostring
local type = type
local unpack = unpack
local verbose = luakit.verbose

local rawget, rawset = rawget, rawset
local match = string.match

local M = {}

-- Private signal data for objects
local data = setmetatable({}, { __mode = "k" })

local debug_printf = function (format, ...)
    io.stderr:write(string.format("D: lousy.signal: " .. format, ...))
end

local function add_signal(object, signame, func)
    local d = rawget(data, object)
    if not d then error("object not setup for signals") end
    local signals = rawget(d, "signals")

    -- Check signal name
    if type(signame) ~= "string" or not match(signame, "^[%w_%-:]+$") then
        print(object, signame, func)
        error("invalid signame")
    end

    if type(func) ~= "function" then error("invalid sigfunc") end

    if verbose then
        debug_printf("add_signal: %q on %s", signame, tostring(object))
    end

    local sigfuncs = rawget(signals, signame)
    if sigfuncs then
        table.insert(sigfuncs, func)
    else
        rawset(signals, signame, { func, })
    end
end

local function emit_signal(object, signame, ...)
    local d = rawget(data, object)
    if not d then error("object not setup for signals") end

    local sigfuncs = rawget(rawget(d, "signals"), signame)
    if not sigfuncs then return end

    if verbose then
        debug_printf("emit_signal: %q on %s", signame, tostring(object))
    end

    local module = rawget(d, "module")
    for _, sigfunc in ipairs(sigfuncs) do
        local ret
        if module then
            ret = { sigfunc(...) }
        else
            ret = { sigfunc(object, ...) }
        end
        if rawget(ret, 1) ~= nil then
            return unpack(ret)
        end
    end
end

-- Remove a signame & function pair.
local function remove_signal(object, signame, func)
    local d = rawget(data, object)
    if not d then error("object not setup for signals") end

    local signals = rawget(d, "signals")
    local sigfuncs = rawget(signals, signame)
    if not sigfuncs then return end

    if verbose then
        debug_printf("remove_signal: %q on %s", signame, tostring(object))
    end

    for i, sigfunc in ipairs(sigfuncs) do
        if sigfunc == func then
            table.remove(sigfuncs, i)
            -- Remove empty sigfuncs table
            if #sigfuncs == 0 then
                rawset(signals, signame, nil)
            end
            return func
        end
    end
end

-- Remove all signal handlers with the given signame.
local function remove_signals(object, signame)
    local d = rawget(data, object)
    if not d then error("object not setup for signals") end

    if verbose then
        debug_printf("remove_signals: %q on %s", signame, tostring(object))
    end

    rawset(rawget(d, "signals"), signame, nil)
end

local methods = {
    add_signal = add_signal,
    emit_signal = emit_signal,
    remove_signal = remove_signal,
    remove_signals = remove_signals,
}

function M.setup(object, module)
    if type(object) ~= "table" then
        error("object not suitable for signal setup")
    end

    if rawget(data, object) then
        error("object already setup for signals")
    end

    rawset(data, object, { signals = {}, module = module })

    for name, func in pairs(methods) do
        if rawget(object, name) ~= nil then
            error("object method name conflict for: " .. name)
        end

        if module then
            rawset(object, name, function (...) return func(object, ...) end)
        else
            rawset(object, name, func)
        end
    end
end

return M

-- vim: et:sw=4:ts=8:sts=4:tw=80
