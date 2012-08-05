----------------------------------------------------------------
-- Vimperator style quickmarking                              --
-- @author Piotr Husiatyński &lt;phusiatynski@gmail.com&gt;   --
-- @author Mason Larobina    &lt;mason.larobina@gmail.com&gt; --
----------------------------------------------------------------

local M = {}

-- Get luakit environment
local lousy = require "lousy"
local modes = require "modes"

M.file = luakit.data_dir .. "/quickmarks"

function M.load()
    local qmarks = {}
    if os.exists(M.file) then
        for line in io.lines(M.file) do
            local mark, uri = string.match(line, "^(%w)%s+(.+)$")
            if mark then qmarks[mark] = uri end
        end
    end
    return qmarks
end

function M.save(qmarks)
    local fh = io.open(M.file, "w")
    for mark, uri in pairs(qmarks) do
        fh:write(string.format("%s %s\n", mark, uri))
    end
    fh:close()
end

function M.get(mark)
    return M.load()[mark]
end

function M.set(mark, uri)
    assert(string.match(mark, "^(%w)$"), "invalid mark")
    if type(uri) == "table" then uri = table.concat(uri, ", ") end
    assert(type(uri) == "string" and string.match(uri, "%S"), "invalid uri")
    local qmarks = M.load()
    qmarks[mark] = uri
    M.save(qmarks)
end

function M.del(pat)
    local qmarks = M.load()
    for mark, _ in pairs(qmarks) do
        if string.match(mark, pat) then qmarks[mark] = nil end
    end
    M.save(qmarks)
end

-- Add quickmarking binds to normal mode
local buf = lousy.bind.buf
add_binds("normal", {
    buf("^g[onw][a-zA-Z0-9]$",
        [[Jump to quickmark in current tab with `go{a-zA-Z0-9}`,
        `gn{a-zA-Z0-9}` to open in new tab and or `gw{a-zA-Z0-9}` to open a
        quickmark in a new window.]],
        function (w, b, m)
            local mode, mark = string.match(b, "^g(.)(.)$")
            local uri = M.get(mark)

            if string.match(uri, "^javascript:") then
                local _, err = w.view:eval_js(string.sub(uri, 12),
                    { no_return = true })
                if err then error(err) end
                return
            end

            -- Search open transform uris
            local uris = lousy.util.string.split(uri, ",%s+")
            for i, uri in ipairs(uris) do uris[i] = w:search_open(uri) end

            for n = 1, m.count do
                if mode == "w" then
                    window.new(uris)
                else
                    for i, uri in ipairs(uris) do
                        if mode == "o" and n == 1 and i == 1 then
                            w:navigate(uri)
                        else
                            w:new_tab(uri, i == 1)
                        end
                    end
                end
            end
        end, {count=1}),

    buf("^M[a-zA-Z0-9]$",
        [[Add quickmark for current URL.]],
        function (w, b)
            local mark, uri = string.match(b, "^M(.)$"), w.view.uri
            M.set(mark, { uri })
            w:notify(string.format("Quickmarked %q: %s", mark, uri))
        end),
})

-- Add quickmarking commands
local cmd = lousy.bind.cmd
add_cmds({
    -- Quickmark add (`:qmark f http://forum1.com, forum2.com, imdb some artist`)
    cmd("qma[rk]", "Add a quickmark.", function (w, a)
        local mark, uri = string.match(a, "^(%w)%s+(.+)$")
        assert(mark, "invalid mark")
        uri = string.gsub(uri, ",%+", ", ")
        M.set(mark, uri)
        w:notify(string.format("Quickmarked %q: %s", mark, uri))
    end),

    -- Quickmark edit (`:qmarkedit f` -> `:qmark f furi1, furi2, ..`)
    cmd({"qmarkedit", "qme"}, "Edit a quickmark.", function (w, mark)
        assert(string.match(mark, "^%w$"), "invalid mark")
        local uri = table.concat(M.get(mark), ", ")
        w:enter_cmd(string.format(":qmark %s %s", mark, uri))
    end),

    -- Quickmark del (`:delqmarks b-p Aa z 4-9`)
    cmd("delqm[arks]", "Delete a quickmark.", function (w, ranges)
        -- Find and del all range specifiers
        local pat = {}
        ranges = string.gsub(ranges, "(%w%-%w)", function (range)
            table.insert(pat, range)
            return ""
        end)
        string.gsub(marks, "(%w)", function (mark)
            table.insert(pat, mark)
        end)

        M.del("[" .. table.concat(pat, "") .. "]")
    end),

    -- View all quickmarks in an interactive menu
    cmd("qmarks", "List all quickmarks.", function (w)
        w:set_mode("quickmark-menu")
    end),

    -- Delete all quickmarks
    cmd({"delqmarks!", "delqm!"}, "Delete all quickmarks.", function (w)
        M.save({})
    end),
})

-- Add mode to display all quickmarks in an interactive menu
modes.new("quickmark-menu", {
    enter = function (w)
        local rows = {{ "Quickmarks", " URI(s)", title = true }}
        local qmarks = M.load()
        local e = lousy.util.escape
        for i, mark in ipairs(lousy.util.table.keys(qmarks)) do
            rows[i+1] = { "  " .. mark, e(" " .. qmarks[mark]), qmark = qmark }
        end
        w.menu:build(rows)
        w:notify("Use j/k to move, d delete, e edit, t tabopen, w winopen.",
            false)
    end,

    leave = function (w)
        w.menu:hide()
    end,
})

local key = lousy.bind.key
add_binds("quickmark-menu", lousy.util.table.join({
    key({}, "d", "Delete quickmark.", function (w)
        local row = w.menu:get()
        if row and row.qmark then
            M.del(row.qmark)
            w.menu:del()
        end
    end),

    key({}, "e", "Edit quickmark.", function (w)
        local row = w.menu:get()
        if row and row.qmark then
            w:enter_cmd(string.format(":qmark %s %s",
                row.qmark, table.concat(M.get(row.qmark) or {}, ", ")))
        end
    end),

    key({}, "Return", "Open quickmark.", function (w)
        local row = w.menu:get()
        if row and row.qmark then
            for i, uri in ipairs(M.get(row.qmark) or {}) do
                uri = w:search_open(uri)
                if i == 1 then w:navigate(uri) else w:new_tab(uri, false) end
            end
        end
    end),

    key({}, "t", "Open quickmark in new tab.", function (w)
        local row = w.menu:get()
        if row and row.qmark then
            for _, uri in ipairs(M.get(row.qmark) or {}) do
                w:new_tab(w:search_open(uri), false)
            end
        end
    end),

    -- Open quickmark in new window
    key({}, "w", "Open quickmark in new window.", function (w)
        local row = w.menu:get()
        w:set_mode()
        if row and row.qmark then
            window.new(M.get(row.qmark) or {})
        end
    end),

    key({}, "q", "Close menu.", function (w) w:set_mode() end),

}, menu_binds))

return M

-- vim: et:sw=4:ts=8:sts=4:tw=80
