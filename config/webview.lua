-------------------------------------------------------------
-- Luakit Webview Widget                                   --
-- 2010-2012 (C) Mason Larobina <mason.larobina@gmail.com> --
-------------------------------------------------------------

local lousy = require "lousy"
local window = require "window"

local M = { init = {} }
lousy.signal.setup(M, true)

-- webview.init {{{
local init = M.init

function init.update_window_title(view, w)
    view:on("property::title", function (view)
        if w.view == view then
            w:update_window_title()
        end
    end)
end

M.on("new", function (...)
    for _, func in pairs(M.init) do func(...) end
end)
-- }}}

-- window.methods {{{
local methods = window.methods

function methods.new_tab(w, uri, opts)
    local view

    if w.tabs:count() == 1 then
        view = w.tabs[1]
        if view.uri ~= "about:blank" or view:loading() then
            view = nil
        end
    end

    if not view then
        view = M.new(w)
        w.tabs:insert(view)
    end

    if type(uri) == "table" then
        view.history = uri
    else
        view.uri = uri or "about:blank"
    end

    return view
end

function methods.close_tab(w, view, blank_last)
    view = view or w.view
    if blank_last ~= false and w.tabs:count() == 1 then
        if not view:loading() and view.uri == "about:blank" then
            return
        end
        w:new_tab("about:blank")
    end
    w:emit_signal("close-tab", view)
    view:destroy()
end

function methods.scroll(w, opts)
    assert(type(opts) == "table", "invalid scroll argument")
    local view = opts.view or w.view
    local s, rawget = view.scroll, rawget
    for _, axis in ipairs{ "x", "y" } do
        -- Relative px movement
        if rawget(opts, axis .. "rel") then
            s[axis] = s[axis] + opts[axis .. "rel"]

        -- Relative page movement
        elseif rawget(opts, axis .. "pagerel") then
            s[axis] = (s[axis] + math.ceil(s[axis .. "page_size"]
                * opts[axis .. "pagerel"]))

        -- Absolute px movement
        elseif rawget(opts, axis) then
            local n = opts[axis]
            if n == -1 then
                s[axis] = s[axis .. "max"]
            else
                s[axis] = n
            end

        -- Absolute page movement
        elseif rawget(opts, axis .. "page") then
            s[axis] = math.ceil(s[axis .. "page_size"] * opts[axis .. "page"])

        -- Absolute percent movement
        elseif rawget(opts, axis .. "pct") then
            s[axis] = math.ceil(s[axis .. "max"] * (opts[axis .. "pct"] / 100))
        end
    end
end
-- }}}

-- webview.new {{{
function M.new(w)
    local view = widget{type="webview"}
    view.show_scrollbars = false
    view.enforce_96_dpi = false
    M.emit_signal("new", view, w)
    return view
end
-- }}}

return setmetatable(M, {
    __call = function (M, ...) return M.new(...) end
})

-- vim: et:sw=4:ts=8:sts=4:tw=80
