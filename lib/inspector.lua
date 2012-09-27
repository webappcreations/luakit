-----------------------------------------------------------
-- Enable WebKit WebInspector                            --
-- © 2011-2012 Mason Larobina <mason.larobina@gmail.com> --
-----------------------------------------------------------

local window = require "window"
local webview = require "webview"

local iwindows = setmetatable({}, { __mode = "k" })

local function switch_inspector(w, view)
    local bottom = w.paned.bottom
    if bottom then
        w.paned:remove(bottom)
    end
    local iview = (view or w.view).inspector
    if iview and not iwindows[iview] then
        w.paned:pack2(iview)
    end
end

local function close_window(iview)
    local win = iwindows[iview]
    if win then
        iwindows[iview] = nil
        win:remove(iview)
        win:destroy()
    end
end

window.init.web_inspector_switch = function (w)
    w.tabs:on("switch-page", function (_, view)
        switch_inspector(w, view)
    end)
    w:on("close-tab", function (_, view)
        view:close_inspector()
    end)
end

webview.init.enable_web_inspector = function (view, w)
    view.enable_developer_extras = true

    view:on("create-inspector-web-view", function ()
        return widget{type="webview"}
    end)

    view:on("show-inspector", function (view, iview)
        switch_inspector(w, view)
        iview:eval_js("WebInspector.attached = true;", { no_return = true })
    end)

    view:on("close-inspector", function (_, iview)
        close_window(iview)
        iview:destroy()
    end)

    view:on("attach-inspector", function (_, iview)
        close_window(iview)
        switch_inspector(w)
    end)

    view:on("detach-inspector", function (_, iview)
        local win = widget{type="window"}
        iwindows[iview] = win
        w.paned:remove(iview)
        win.child = iview
        win:show()
    end)
end
