require "package"

local lousy = require "lousy"
local modes = require "modes"

local table_join = lousy.util.table.join
local dedent = lousy.util.string.dedent
local markdown = require "markdown"

-- Module table
local M = {}

-- Cache collated data
local by_mode = {}
local by_bind = {}
local by_module = {}

-- Cross references
local mode_binds = {}

local module_binds = {}
local module_modes = {}

-- External file load cache
local source_cache = {}

-- Return string representation of the bind activator
local function bind_tostring(b)
    local t, m = b.type, b.mods
    local mods = m and #m > 0 and table.concat(m, "-") .. "-"

    if t == "key" then
        if mods or string.wlen(b.key) > 1 then
            return "<".. (mods and mods or "") .. b.key .. ">"
        end
        return b.key

    elseif t == "buffer" then
        local pat = b.pattern
        if string.match(pat, "^^.+$$") then
            return string.sub(pat, 2, -2)
        end
        return pat

    elseif t == "button" then
        return "<" .. (mods and mods or "") .. "Mouse" .. b.button .. ">"

    elseif t == "any" then
        return "any"

    elseif t == "command" then
        local cmds = {}
        for i, cmd in ipairs(b.cmds) do
            cmds[i] = ":"..cmd
        end
        return table.concat(cmds, ", ")
    end
end

-- Get the source definition of the given function
local function function_tostring(func, info)
    local src = info.short_src
    local lines = source_cache[src]
    if not lines then
        local file = lousy.load(src)
        lines = {}
        local i = 1
        string.gsub(file, "([^\n]*)\n?", function (line)
            lines[i] = line
            i = i + 1
        end)
        source_cache[src] = lines
    end

    return dedent(table.concat(lines, "\n", info.linedefined,
        info.lastlinedefined), true)
end

local function examine_bind(b)
    if by_bind[b] then return by_bind[b] end -- memoization

    local info = debug.getinfo(b.func, "S")

    local ret = {
        type = b.type,
        repr = bind_tostring(b),
        desc = b.desc and markdown(dedent(b.desc)) or nil,
        source = info.short_src,
        line = info.linedefined,
        func = function_tostring(b.func, info),
    }

    by_bind[b] = ret
    return ret
end

local function examine_mode(name, mode)
    if by_mode[name] then return by_mode[name] end -- memoization

    local binds
    if mode.binds then
        binds = {}
        for i, b in ipairs(mode.binds) do
            binds[i] = examine_bind(b)
        end
    end

    local ret = {
        name = name,
        binds = binds,
        source = mode.source,
        desc = mode.desc and markdown(dedent(mode.desc)) or nil,
        order = mode.order,
    }

    by_mode[name] = ret
    return ret
end

local function collate()
    for name, mode in pairs(modes.get_all()) do
        by_mode[name] = examine_mode(name, mode)
    end
end

local html = [==[
<!doctype html>
<html>
<head>
    <meta charset="utf-8">
    <title>Luakit Introspector</title>
    <style type="text/css">
        body {
            background-color: white;
            color: black;
            display: block;
            font-size: 62.5%;
            font-family: sans-serif;
            width: 700px;
            margin: 1em auto;
        }

        header {
            padding: 0.5em 0 0.5em 0;
            margin: 2em 0 0.5em 0;
            border-bottom: 1px solid #888;
        }

        h1 {
            font-size: 2em;
            font-weight: bold;
            line-height: 1.4em;
            margin: 0;
            padding: 0;
        }

        h3.mode-name {
            color: black;
            font-size: 1.6em;
            margin-bottom: 1.0em;
            line-height: 1.4em;
            border-bottom: 1px solid #888;
            font-family: monospace, sans-serif;
        }

        h1, h2, h3, h4 {
            -webkit-user-select: none;
        }

        ol, li {
            margin: 0;
            padding: 0;
            list-style: none;
        }

        pre {
            margin: 0;
            padding: 0;
        }


        .mode {
            width: 100%;
            float: left;
            font-size: 1.2em;
            margin-bottom: 1em;
        }

        .mode .binds {
            clear: both;
            display: block;
        }

        .bind {
            float: left;
            width: 690px;
            padding: 5px;
        }

        .bind:hover {
            background-color: #f8f8f8;
            -webkit-border-radius: 0.5em;
        }

        .bind .refs {
            float: right;
            font-family: monospace, sans-serif;
            text-decoration: none;
        }

        .bind .refs a {
            color: #11c;
            text-decoration: none;
        }

        .bind .refs a:hover {
            color: #11c;
            text-decoration: underline;
        }

        .bind .func {
            display: none;
        }

        .bind .repr {
            font-family: monospace, sans-serif;
            float: left;
            color: #2E4483;
            font-weight: bold;
        }

        .bind .box {
            float: right;
            width: 550px;
        }

        .bind .desc p:first-child {
            margin-top: 0;
        }

        .bind .desc p:last-child {
            margin-bottom: 0;
        }

        .bind code {
            color: #2525ff;
            display: inline-block;
            font-size: 1.1em;
        }

        .bind pre {
            margin: 1em;
            padding: 0.5em;
            background-color: #EFC;
            border-top: 1px solid #AC9;
            border-bottom: 1px solid #AC9;
        }

        .bind pre code {
            color: #000;
        }

        .mode h4 {
            margin: 1em 0;
            padding: 0;
        }

        .bind .clear {
            display: block;
            width: 100%;
            height: 0;
            margin: 0;
            padding: 0;
            border: none;
        }

        .bind_type_any .repr {
            color: #888;
            float: left;
        }

        #templates {
            display: none;
        }
    </style>
</head>
<body>
    <header>
        <h1>Luakit Help</h1>
    </header>

    <div id="templates">
        <div id="mode-section-skelly">
            <section class="mode">
                <h3 class="mode-name"></h3>
                <p class="mode-desc"></p>
                <ol class="binds"></ol>
            </section>
        </div>
        <div id="mode-bind-skelly">
            <ol class="bind">
                <div class="refs">
                    <a href class="file"></a>
                    <a href class="line"></a>
                </div>
                <hr class="clear" />
                <div class="repr"></div>
                <div class="box desc"></div>
                <div class="box func">
                    <h4>Function source:</h4>
                    <pre><code></code></pre>
                </div>
            </ol>
        </div>
    </div>
</body>
]==]

main_js = [=[
$(document).ready(function () {

    var $body = $(document.body),
        mode_section_html = $("#mode-section-skelly").html(),
        mode_bind_html = $("#mode-bind-skelly").html();

    // Remove all templates
    $("#templates").remove();

    function make_bind_html(b) {
        var $bind = $(mode_bind_html);
        $bind.addClass("bind_type_" + b.type);
        $bind.find(".repr").text(b.repr);
        $bind.find(".func code").text(b.func);
        $bind.find(".refs .file").text(b.source);
        $bind.find(".refs .line").text("#" + b.line)
            .attr("file", b.source).attr("line", b.line);

        if (b.desc)
            $bind.find(".desc").html(b.desc);
        else
            $bind.find(".clear").hide();

        return $bind;
    }

    function make_mode_html(m) {
        var $mode = $(mode_section_html);
        $mode.attr("id", "mode-" + m.name);
        $mode.find("h3.mode-name").text(m.name + " mode");
        $mode.find("p.mode-desc").html(m.desc);

        var binds = m.binds;
        if (binds && binds.length) {
            var $binds = $mode.find(".binds");
            for (var j = 0; j < binds.length; j++)
                $binds.append(make_bind_html(binds[j]));
        }

        return $mode;
    }

    // Get all modes & sub-data
    var names = help_mode_names();
    for (var i = 0; i < names.length; i++) {
        var mode = help_get_mode(names[i]);
        $body.append(make_mode_html(mode));
    }

    $body.on("click", ".bind .linedefined", function (event) {
        event.preventDefault();
        var $e = $(this);
        open_editor($e.attr("file"), $e.attr("line"));
        return false;
    })

    $body.on("click", ".bind .desc a", function (event) {
        event.stopPropagation(); // prevent source toggling
    })

    $body.on("click", ".bind", function (e) {
        var $src = $(this).find(".func");
        if ($src.is(":visible"))
            $src.slideUp();
        else
            $src.slideDown();
    })
});
]=]

export_funcs = {
    help_mode_names = function ()
        -- Sort modes by their order property (which is creation order)
        local modes = lousy.util.table.values(by_mode)
        table.sort(modes, function (a, b) return a.order < b.order end)
        local names = {}
        for i, m in ipairs(modes) do names[i] = m.name end
        return names
    end,

    help_get_mode = function (name)
        return assert(by_mode[name], "invalid mode name")
    end,

    open_editor = function (file, line)
        local cmd = string.format("%s -e %s %q +%d", globals.term or "xterm",
            globals.editor or "vim", file, line)
        capi.luakit.spawn(cmd)
    end,
}

chrome.add("help", function (view, meta)
    view:load_string(html, meta.uri)

    function on_first_visual(_, status)
        -- Wait for new page to be created
        if status ~= "first-visual" then return end

        -- Hack to run-once
        view:remove_signal("load-status", on_first_visual)

        -- Double check that we are where we should be
        if view.uri ~= meta.uri then return end

        -- Export luakit JS<->Lua API functions
        for name, func in pairs(export_funcs) do
            view:register_function(name, func)
        end

        -- Load jQuery JavaScript library
        local jquery = lousy.load("lib/jquery.min.js")
        local _, err = view:eval_js(jquery, { no_return = true })
        assert(not err, err)

        collate()

        -- Load main luakit://download/ JavaScript
        local _, err = view:eval_js(main_js, { no_return = true })
        assert(not err, err)
    end

    view:add_signal("load-status", on_first_visual)
end)

local cmd = lousy.bind.cmd
add_cmds({
    cmd("help", "Open [luakit://help/](luakit://help/) in a new tab.",
        function (w) w:new_tab("luakit://help/") end),
})

-- Prevent history items from turning up in history
history.add_signal("add", function (uri)
    if string.match(uri, "^luakit://help/") then return false end
end)

return M
