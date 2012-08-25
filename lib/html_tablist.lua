local M = {}

M.stylesheet = [===[
body {
    background-color: white;
    color: black;
    font-size: 62.5%; /* 1em == 10px @ 96dpi */
    margin: 0;
    padding: 0;

    /* make nothing selectable */
    -webkit-user-select: none;
    cursor: default;
}

#wrapper {
    display: block;
    position: absolute;
    left: 0;
    right: 0;
    z-index: 0;
    height: 2.1em;

    padding: 0.6em 1em 0.4em 1em;
    background: -webkit-linear-gradient(top, #ccf 0%, #aaf 100%);

    /* hide tab overflow */
    overflow: hidden;
    white-space: nowrap;
}

.tab {
    font-size: inherit;
    display: inline-block;
    position: relative;

    z-index: 5; /* place at back */

    padding: 0.5em 1em 0.4em 1em;
    margin-right: 0.5em;

    width: 20em;

    /* inactive colours */
    color: #444;
    background-color: #f0f0f0;

    border-radius: 0.5em 0.5em 0 0;
    box-shadow: 0 0 0.3em #000;

    /* hide text overflow */
    overflow: hidden;
    white-space: nowrap;
    text-overflow: ellipsis;
}

.tab:hover {
    background-color: #fff;
}

.tab .title {
    font-size: 1.1em;
}

.tab.selected {
    z-index: 100;
    border: none;
    color: #222;
    background-color: #fff;
    box-shadow: 0 0 0.4em #000;
}

#shadow {
    position: fixed;
    pointer-events: none;
    bottom: 0.4em;
    left: -3em;
    right: -3em;
    top: -3em;
    box-shadow: inset 0 0.5em 1.5em #000;
    z-index: 10;
}

#horiz {
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    display: block;
    height: 0.5em;
    background-color: #000;
    background: -webkit-linear-gradient(top, #fff 0%, #f0f0f0 70%, #aaa 100%);
    z-index: 20;
}

#templates {
    display: none;
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
<div id="wrapper">
    <div id="tablist"></div>
    <div id="shadow"></div>
</div>
<div id="horiz"></div>
</body>

<div id="templates">
    <div id="tab-skelly">
        <div class="tab"><span class="title"></span></div>
    </div>
</div>
]==]

M.mainjs = [=[
'use strict';

/* increase animation performance */
jQuery.fx.interval = 1;

var tabinfo, $tablist = $("#tablist"),
    tab_html = $("#tab-skelly").html();

var order = [], info = {};

var deleting = {};

function deselect() {
    var e = document.getElementsByClassName("selected")[0];
    if (e) $(e).removeClass("selected");
}

function remove_tab(id) {
    deleting[id] = true;
    var $t = $("#"+id);
    $t.animate({ width: 0, opacity: 0 }, "fast", function () {
        $t.remove();
        delete deleting[id];
    });
}

function update() {
    var tabinfo = tabinfo_all();

    var new_order = tabinfo.order, new_info = tabinfo.info,
        len = new_order.length, current = tabinfo.current;

    deselect();

    // Detect tab deletions
    for (var i = 0; i < order.length; i++) {
        var id = order[i];
        if (!new_info[id] && !deleting[id]) {
            remove_tab(id);
        }
    }

    for (var i = 0; i < len; i++) {
        var id = new_order[i], t = new_info[id], e = document.getElementById(id), $tab;

        if (e)
            $tab = $(e);
        else {
            $tab = $(tab_html).attr("id", id);
            $tab.css({ marginLeft: "-10em", opacity: 0 })
            $tab.animate({ marginLeft: 0, opacity: 1 }, "fast");
            $tablist.append($tab);
        }

        if (!t.title)
            t.title = t.uri;

        // Only update title if new tab or different
        var old = info[id];
        if (!old || (t.title !== old.title))
            $tab.find(".title").text(t.title || t.uri);

        if (i + 1 === current)
            $tab.addClass("selected");
    }

    order = new_order;
    info = new_info;
}

$tablist.on("mouseup", ".tab", function (ev) {
    if (ev.which === 1) {
        deselect();
        var $t = $(this);
        $t.addClass("selected");
        switch_tab(info[$(this).attr("id")].index);
    } else if (ev.which === 2) {
        var $t = $(this);
        close_tab(info[$(this).attr("id")].index);
    }
});

]=]

local function view_hash(view)
    return "tab-" .. string.match(tostring(view), "(%w+)$")
end

M.export_funcs = {
    tabinfo_single = function (w, index)
        local view = assert(w.tabs.children[index], "invalid index")
        return {
            uri = view.uri, title = view.title,
            index = index, loading = view:loading(),
        }
    end,

    tabinfo_all = function (w)
        local info, order = {}, {}
        for i, view in ipairs(w.tabs.children) do
            local id = view_hash(view)
            info[id] = {
                uri = view.uri, title = view.title, index = i,
                loading = view:loading(),
            }
            order[i] = id
        end

        return { order = order, info = info, current = w.tabs:current() }
    end,

    switch_tab = function (w, index)
        assert(type(index) == "number", "invalid index")
        w.tabs:switch(index)
    end,

    close_tab = function (w, index)
        assert(type(index) == "number", "invalid index")
        w:close_tab(w.tabs[index])
    end,
}

function M.new(w)
    assert(w, "missing window argument")

    -- Init webview widget
    local view = widget{type="webview"}
    view.show_scrollbars = false

    local html = string.gsub(M.html, "{%%(%w+)}", {
        stylesheet = M.stylesheet
    })

    function on_first_visual(view, status)
        if status ~= "finished" then return end

        -- Hack to run-once
        view:remove_signal("load-status", on_first_visual)

        for name, func in pairs(M.export_funcs) do
            view:register_function(name, function (...) return func(w, ...) end)
        end

        -- Load jQuery JavaScript library
        local jquery = lousy.load("lib/jquery.min.js")
        local _, err = view:eval_js(jquery, { no_return = true })
        assert(not err, err)

        local _, err = view:eval_js(M.mainjs, { no_return = true })
        assert(not err, err)

        view:eval_js("update()", { no_return = true })
    end

    view:add_signal("load-status", on_first_visual)

    -- Replace tablist update
    w.update_tablist = function (w)
        local _, err = view:eval_js([=[
            if (typeof update !== "undefined") update();
        ]=], { no_return = true })
        assert(not err, err)
    end
    view:load_string(html, "ui://tablist")

    return view
end

return setmetatable(M, { __call = function (M, ...) return M.new(...) end })
