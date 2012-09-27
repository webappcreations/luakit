-------------------------------------------------------------
-- (C) 2010-2012 Mason Larobina <mason.larobina@gmail.com> --
-------------------------------------------------------------

local M = {}

-- lousy.signal {{{

M.signal = {}
local sigdata = setmetatable({}, { __mode = "k" })

local function add_signal(self, signame, sigfunc)
    local signals = assert(sigdata[self], "invalid self").signals
    assert(type(signame) == "string", "invalid signame")
    assert(type(sigfunc) == "function", "invalid sigfunc")

    local sigfuncs = signals[signame]
    if not sigfuncs then
        signals[signame] = { sigfunc, }
    else
        table.insert(sigfuncs, sigfunc)
    end
end

local function emit_signal(self, signame, ...)
    local d = assert(sigdata[self], "invalid self")
    local sigfuncs = d.signals[signame]
    if not sigfuncs then return end

    for _, sigfunc in ipairs(sigfuncs) do
        local ret
        if d.is_module then
            ret = { sigfunc(...) }
        else
            ret = { sigfunc(self, ...) }
        end
        if ret[1] ~= nil then
            return unpack(ret)
        end
    end
end

local function remove_signal(self, signame, sigfunc)
    local signals = assert(sigdata[self], "invalid self").signals
    local sigfuncs = signals[signame]
    if not sigfuncs then return end

    for i, func in ipairs(sigfuncs) do
        if sigfunc == func then
            table.remove(sigfuncs, i)
            if not sigfuncs[1] then
                signals[signame] = nil
            end
        end
    end
end

local sigmethods = {
    on = add_signal,
    add_signal = add_signal,
    emit_signal = emit_signal,
    remove_signal = remove_signal,
}

function M.signal.setup(object, is_module)
    assert(type(object) == "table", "invalid object")
    sigdata[object] = { signals = {}, is_module = not not is_module }

    for name, func in pairs(sigmethods) do
        if is_module then
            object[name] = function (...) return func(object, ...) end
        else
            object[name] = func
        end
    end
end

-- lousy.signal }}}

-- lousy.load {{{
function M.load(paths)
    for _, path in ipairs(paths) do
        if path then
            local f = io.open(path)
            if f then
                local dat = f:read("*a")
                f:close()
                return dat
            end
        end
    end
end
-- }}}

return M
