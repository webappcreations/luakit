local lousy = require "lousy"
local window = require "window"
local webview = require "webview"

local M = {}

M.stylesheet = [===[

body {
    background-color: #333; color: #aaa;
    font-family: terminus, monospace; font-size: 10px;
    margin: 0; padding: 0;
    cursor: default; -webkit-user-select: none;
}

#tablist {
    position: relative; display: -webkit-flexbox;
    left: 0; right: 0;
}

.tab {
    position: relative;
    -webkit-box-flex: 1; width: -webkit-flex(1 0 0);
    margin: 0; padding: 2px 5px;
    overflow: hidden; white-space: nowrap;
}

.tab > span {
    position: relative; display: inline-block; z-index: 10;
}

.tab > .num {
    color: #fff;
}

.progress {
    display: block; position: absolute; z-index: 0;
    top: 0; bottom: 0; left: 0;
    opacity: 0.1;
}

.progress > .bar {
    display: block; position: absolute; z-index: 0;
    top: 0; bottom: 0; left: 0; right: 32px;
    background-image: -webkit-linear-gradient(right,
        rgba(255,255,255,1) 0%,
        rgba(255,255,255,0.5) 250%);
}

.progress > .arrow {
    display: block; position: absolute; z-index: 0;
    top: 0; bottom: 0; right: 0; width: 32px;
    background-image: -webkit-linear-gradient(45deg,
        rgba(255,255,255,1) 16px,
        rgba(255,255,255,0) 16px);
}

.current {
    background-color: #000; color: #fff;
}

.current > .progress {
    opacity: 1;
}

.current > .progress > .arrow {
    background-image: -webkit-linear-gradient(45deg,
        rgba(50,150,200,1) 16px,
        rgba(50,150,200,0) 17px);
}

.current > .progress > .bar {
    background-image: -webkit-linear-gradient(right,
        rgba(50,150,200,1) 0%,
        rgba(50,150,200,0) 250%);
}

]===]

M.html = [==[
<!doctype html>
<html>
<head>
    <meta charset="utf-8">
    <style type="text/css">
        {%stylesheet}
    </style>
</head>
<body>
<div id="tablist"></div>
<div id="templates" style="display:none;">
    <div id="tab-skelly">
        <div class="tab">
            <!-- <img class="favicon" alt="" style="display:none;"
            onload="$(this).show();" onerror="$(this).hide();" /> -->
            <span class="num">0</span>
            <span class="title">(untitled)</span>
            <div class="progress">
                <div class="bar"></div><div class="arrow"></div>
            </div>
        </div>
    </div>
</div>
</body>
</html>
]==]

M.mainjs = [=[
'use strict';

    /* increase animation performance */
    jQuery.fx.interval = 1;

    var tabinfo, $tablist = $("#tablist"),
        tab_html = $("#tab-skelly").html();

    var tablist = document.getElementById("tablist");

    function remove_tab(id) {
        $("#"+id).remove();
        update_numbers();
    }

    function favicon_onload(that) {
        $(that).show().parent().addClass("has_favicon");
    }

    function favicon_onerror(that) {
        $(that).hide().parent().removeClass("has_favicon");
    }

    function update_title(id, title) {
        $("#"+id).find(".title").text(title);
    }

    function update_favicon(id, src) {
        $("#"+id).find(".favicon").prop("src", src);
    }

    function update_current(id) {
        $tablist.find(".current").removeClass("current");
        $("#"+id).addClass("current");
    }

    function update_progress(id, pct) {
        var $l = $("#"+id+" > .progress").stop(true),
            lpct = $l.prop("progress"),
            width = (pct + 10) + "%";

        if (pct < lpct) {
            $l.attr("style", "");
        } else if (pct === 100) {
            $l.css("width", "").animate({ right: "-32px" },
                function () { $l.fadeOut() });
        } else {
            $l.animate({ width: width });
        }
        $l.prop("progress", pct);
    }

    function update_numbers() {
        var $tabs = $tablist.children(), length = $tabs.length, i = 0;
        for (; i < length; i++)
            $tabs.eq(i).find(".num").text(i+1);
    }

    function update(new_order) {
        var i = 0, length = new_order.length, id;
        for (; i < length; i++) {
            id = new_order[i];
            if (!document.getElementById(id)) {
                $tablist.append($(tab_html).prop("id", id));
            }
        }
        update_numbers();
    }

    $tablist.on("mousedown", ".tab", function (e) {
        e.preventDefault();
        if (e.which === 1) {
            switch_tab($(this).attr("id"));
        } else if (e.which === 2) {
            close_tab($(this).attr("id"));
        }
    });

    //$(document.body).on("contextmenu", function (e) {
    //    e.preventDefault();
    //})
]=]

local map_view_id = setmetatable({}, { __mode = "k" })
local map_id_view = setmetatable({}, { __mode = "v" })

function viewid(view)
    local id = map_view_id[view]
    if not id then
        id = "view-" .. string.match(tostring(view), "%w+$")
        map_view_id[view] = id
        map_id_view[id] = view
    end
    return id
end

M.export_funcs = {
    switch_tab = function (w, id)
        local view = assert(map_id_view[id])
        local tabs = w.tabs
        tabs:switch(tabs:indexof(view))
    end,

    close_tab = function (w, id)
        local view = assert(map_id_view[id])
        w:close_tab(view)
    end,
}

function window.methods.update_tab_title(w, view)
    local title = view.title or view.uri or "(untitled)"
    local update = string.format("update_title(%q, %q);", viewid(view), title)
    w.tablist_eval_func(update)
end

function window.methods.update_tab_favicon(w, view)
    local update = string.format("update_favicon(%q, %q);", viewid(view),
        view.icon_uri)
    w.tablist_eval_func(update)
end

function window.methods.update_tab_progress(w, view)
    local update = string.format("update_progress(%q, %d);", viewid(view),
        view.progress * 100)
    w.tablist_eval_func(update)
end

function webview.init.html_tablist_update(view, w)
    view:on("property::title", function (view)
        w:update_tab_title(view)
    end)
    view:on("property::icon_uri", function (view)
        w:update_tab_favicon(view)
    end)
    view:on("property::progress", function (view)
        w:update_tab_progress(view)
    end)
end

function window.init.html_tablist_update(w)
    w.tabs:on("page-added", function ()
        local ids = {}
        for i, view in ipairs(w.tabs.children) do
            ids[i] = viewid(view)
        end
        w.tablist_eval_func("update(['" .. table.concat(ids, "','") .. "']);")
    end)
    w.tabs:on("page-removed", function (_, view)
        w.tablist_eval_func(
            string.format("remove_tab(%q);", viewid(view)))
    end)

    w.tabs:on("switch-page", function (_, view)
        w.tablist_eval_func(
            string.format("update_current(%q);", viewid(view)))
    end)
end

function M.new(w)
    assert(w, "missing window argument")

    local view = widget{type="webview"}
    view.show_scrollbars = false

    local html = string.gsub(M.html, "{%%(%w+)}", {
        stylesheet = M.stylesheet
    })

    view:on("expose", function (view)
        local h = view:eval_js("document.body.getClientRects()[0].height")
        view:set_size(-1, h)
    end)

    -- Prevent navigating away
    view:on("navigation-request", function () return false end)

    local queue = {}
    w.tablist_eval_func = function (code)
        table.insert(queue, code)
    end

    function on_loaded(view, status)
        if status ~= "finished" then return end

        -- Hack to run-once
        view:remove_signal("load-status", on_loaded)

        for name, func in pairs(M.export_funcs) do
            view:register_function(name, function (...) return func(w, ...) end)
        end

        -- Load jQuery JavaScript library
        local jquery = assert(lousy.load {
            luakit.dev_paths and "./lib/jquery.min.js",
            xdg.config_dir .. "/jquery.min.js",
            luakit.install_path .. "/lib/jquery.min.js"
        }, "unable to find jquery.min.js")

        local noret = { no_return = true }

        local _, err = view:eval_js(jquery, noret)
        assert(not err, err)

        local _, err = view:eval_js(M.mainjs, noret)
        assert(not err, err)

        local queued = table.concat(queue, "\n")
        queue = nil

        local view = view
        w.tablist_eval_func = function (code)
            local _, err = view:eval_js(code, noret)
            assert(not err, err)
        end

        if queued ~= "" then
            local _, err = view:eval_js(queued, { no_return = true })
            assert(not err, err)
        end
    end

    view:on("load-status", on_loaded)

    view:load_string(html, "ui://tablist")
    return view
end

window.on("new", function (w)
    w.tabs.show_tabs = false
    w.tablist = M.new(w)

    webview.init.enable_web_inspector(w.tablist, w)

    w.layout:pack(w.tablist, { expand = false, fill = false })
    w.layout:reorder(w.tablist, 0)

    w:on("destroy", function ()
        w.tablist:destroy()
    end)
end)

return setmetatable(M, { __call = function (M, ...) return M.new(...) end })
