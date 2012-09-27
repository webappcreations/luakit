local window = require "window"
require "webview"

require "html_tablist"
require "inspector"

local w = window()

w:new_tab("http://luakit.org")
w:new_tab("http://luakit.org")
w:new_tab("http://luakit.org")
