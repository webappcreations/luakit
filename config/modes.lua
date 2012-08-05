-------------------------------
-- luakit mode configuration --
-------------------------------

local M = {}

local lousy = require "lousy"
local join = lousy.util.table.join

-- Private table of mode data
local data, order = {}, 0

-- Add new mode table (optionally merges with original mode)
function M.new(name, desc, mode, replace)
    -- Detect optional description
    if type(desc) == "table" then
        desc, mode, replace = nil, desc, mode
    end

    -- Get calling source filename (for introspector)
    local source = string.match(debug.traceback("", 2), "\t([^:]+)")

    -- Save order in which modes were added
    order = order + 1

    data[name] = join({ order = order, source = source },
        (not replace and data[name]) or {}, mode or {},
        { name = name, desc = desc })
end

function M.get(name) return data[name] end

function M.get_all()
    return lousy.util.table.clone(data)
end

function window.methods.set_mode(w, name, ...)
    local new_mode = data[name or "normal"]
    if not new_mode then error("invalid mode: " .. name) end

    local current_mode = rawget(w, "mode")
    if current_mode then
        if w:emit_signal("mode::leave", current_mode, new_mode) == false then
            return
        end

        local leave = current_mode.leave
        if leave and leave(w) == false then return end
    end

    -- Set new window mode
    rawset(w, "mode", new_mode)
    if new_mode.enter then new_mode.enter(w, ...) end
    w:emit_signal("mode::enter", new_mode, ...)
end

-- Attach window & input bar signals for mode hooks
window.init_funcs.mode_hooks_setup = function (w)
    local input = w.ibar.input

    -- Calls the changed hook on input widget changed.
    input:add_signal("changed", function (input)
        local changed = w.mode.changed
        if changed then changed(w, input.text) end
    end)

    input:add_signal("property::position", function (input)
        local move_cursor = w.mode.move_cursor
        if move_cursor then move_cursor(w, input.position) end
    end)

    -- Calls the `activate` hook on input widget activate.
    input:add_signal("activate", function (input)
        local mode = w.mode
        if not mode.activate then return end

        local text, hist = input.text, mode.history
        if mode.activate(w, text) == false then return end

        -- TODO make this window method to add cmd history
        -- Check if last history item is identical
        if hist and hist.items and hist.items[hist.len or -1] ~= text then
            table.insert(hist.items, text)
        end
    end)
end

-- Setup normal mode
M.new("normal", [[When luakit first starts you will find yourself in this
    mode.]], {
    enter = function (w)
        w:set_prompt()
        w:set_input()
    end,
    enable_buffer = true,
})

M.new("all", [[Special meta-mode in which the bindings for this mode are
    present in all modes.]])

-- Setup insert mode
M.new("insert", [[When clicking on form fields luakit will enter the insert
    mode which allows you to enter text in form fields without accidentally
    triggering normal mode bindings.]], {
    enter = function (w)
        w:set_prompt("-- INSERT --")
        w:set_input()
    end,
    -- Send key events to webview
    passthrough = true,
})

M.new("passthrough", [[Luakit will pass every key event to the WebView
    until the user presses Escape.]], {
    enter = function (w)
        w:set_prompt("-- PASS THROUGH --")
        w:set_input()
    end,
    -- Send key events to webview
    passthrough = true,
    -- Don't exit mode when clicking outside of form fields
    reset_on_focus = false,
    -- Don't exit mode on navigation
    reset_on_navigation = false,
})

-- Setup command mode
M.new("command", [[Enter commands.]], {
    enter = function (w)
        w:set_prompt()
        w:set_input(":")
    end,
    changed = function (w, text)
        -- Auto-exit command mode if user backspaces ":" in the input bar.
        if not string.match(text, "^:") then w:set_mode() end
    end,
    activate = function (w, text)
        w:set_mode()
        local cmd = string.sub(text, 2)
        -- Ignore blank commands
        if string.match(cmd, "^%s*$") then return end
        local success, match = pcall(w.match_cmd, w, cmd)
        if not success then
            w:error("In command call: " .. match)
        elseif not match then
            w:error(string.format("Not a browser command: %q", cmd))
        end
    end,
    history = {maxlen = 50},
})

M.new("lua", [[Execute arbitrary Lua commands within the luakit
    environment.]], {
    enter = function (w)
        w:set_prompt(">")
        w:set_input("")
    end,
    activate = function (w, text)
        w:set_input("")
        local ret = assert(loadstring("return function(w) return "..text.." end"))()(w)
        if ret then print(ret) end
    end,
    history = {maxlen = 50},
})

return M
