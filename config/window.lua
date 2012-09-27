-------------------------------------------------------------
-- Luakit Window Widget                                    --
-- 2010-2012 (C) Mason Larobina <mason.larobina@gmail.com> --
-------------------------------------------------------------

local lousy = require "lousy"

local M = { methods = {}, init = {}, windows = {} }
lousy.signal.setup(M, true)

-- window.init {{{
local init = M.init

function init.notebook_signals(w)
    w.tabs:on("switch-page", function (_, view, index)
        w.view = view
        w:update_window_title()
    end)
end

function init.key_press_match(w)
    w.window:on("key-press", function (_, mods, key)
        print(table.concat(mods, "|"), key)
    end)
end

function init.last_window_check(w)
    w.window:on("destroy", function ()
        if #(M.windows) == 0 then luakit.quit() end
        if w.close_win then w:close_win() end
    end)
end

M.on("new", function (...)
    for _, func in pairs(init) do func(...) end
end)

-- }}}

-- window.methods {{{
local methods = M.methods

function methods.close_win(w, force)
    if not force and #(M.windows) == 1 then
        local err = luakit.emit_signal("can-close", w)
        if err then print(err) return false end
    end

    w:emit_signal("close-window")

    for _, view in ipairs(w.tabs.children) do
        w:close_tab(view, false)
    end

    M.windows[w.window] = nil

    for _, wi in ipairs { w.tabs, w.layout, w.paned, w.ebox, w.window } do
        wi:destroy()
    end

    setmetatable(w, {})
    for k in pairs(w) do rawset(w, k, nil) end

    if #(M.windows) == 0 then
        luakit.quit()
    end
end

function methods.update_window_title(w)
    local title, uri = w.view.title, w.view.uri
    w.window.title = (title or "luakit") .. ((uri and " - " .. uri) or "")
end
-- }}}

-- window.new {{{
function M.new(uris)
    local w = {
        window = widget{type="window"},
        ebox   = widget{type="eventbox"},
        layout = widget{type="vbox"},
        paned  = widget{type="vpaned"},
        tabs   = widget{type="notebook"},
    }

    w.window.child = w.ebox
    w.ebox.bg = "#fff"
    w.ebox.child = w.paned
    w.paned:pack1(w.layout)
    w.layout:pack(w.tabs, { expand = true, fill = true })

    setmetatable(w, { __index = methods })
    M.windows[w.window] = w

    for _, wi in ipairs { w.window, w.ebox, w.layout, w.tabs } do
        wi:show()
    end

    lousy.signal.setup(w)
    M.emit_signal("new", w)

    if uris then
        for _, uri in ipairs(uris) do
            w:new_tab(uri, { switch = false })
        end
    end

    if w.tabs:count() == 0 then
        w:new_tab()
    end

    return w
end
-- }}}

return setmetatable(M, {
    __call = function (M, ...) return M.new(...) end
})

-- vim: et:sw=4:ts=8:sts=4:tw=80
