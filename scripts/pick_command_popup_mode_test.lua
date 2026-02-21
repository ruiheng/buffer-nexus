local function assert_ok(condition, message)
    if not condition then
        error(message or "assertion failed")
    end
end

local function add_rtp_root()
    local cwd = vim.fn.getcwd()
    local rtp_root = vim.fn.fnamemodify(cwd, ":h:h")
    vim.opt.rtp:prepend(rtp_root)
end

add_rtp_root()
local ok, err = pcall(function()
    vim.o.shadafile = vim.fn.tempname()
    vim.o.swapfile = false

    local vbl = require('buffer-nexus')
    local groups = require('buffer-nexus.groups')
    local state = require('buffer-nexus.state')
    local bufferline_integration = require('buffer-nexus.bufferline-integration')

    local tmpdir = vim.fn.tempname()
    vim.fn.mkdir(tmpdir, "p")

    vbl.setup({ position = "left", floating = false, pick_chars = "abc", auto_open = false })
    groups.setup({ auto_add_new_buffers = false })
    bufferline_integration.is_available = function()
        return false
    end

    for i = 1, 2 do
        local path = string.format("%s/%03d.txt", tmpdir, i)
        vim.fn.writefile({ "x" }, path)
        vim.cmd("edit " .. vim.fn.fnameescape(path))
        local buf_id = vim.api.nvim_get_current_buf()
        groups.add_buffer_to_group(buf_id, "default")
    end

    vim.wait(150)
    if state.is_sidebar_open() then
        vbl.close_sidebar()
    end
    assert_ok(not state.is_sidebar_open(), "sidebar should remain closed before pick commands")

    local before_pick_buf = vim.api.nvim_get_current_buf()
    local active_group = groups.get_active_group()
    local pick_index = 1
    for i, buf_id in ipairs(active_group.buffers or {}) do
        if buf_id ~= before_pick_buf then
            pick_index = i
            break
        end
    end

    local ok_pick, pick_err = pcall(vim.cmd, "BNPick")
    assert_ok(ok_pick, "BNPick command should succeed: " .. tostring(pick_err))
    assert_ok(not state.is_sidebar_open(), "BNPick should not open sidebar when sidebar is closed")

    local pick_menu_buf = vim.api.nvim_get_current_buf()
    local pick_menu_ft = vim.api.nvim_buf_get_option(pick_menu_buf, "filetype")
    assert_ok(pick_menu_ft == "vertical-bufferline-menu", "BNPick should open popup menu")

    vbl.menu_select_by_index(pick_index)
    vim.wait(80)

    local after_pick_buf = vim.api.nvim_get_current_buf()
    assert_ok(after_pick_buf ~= pick_menu_buf, "menu should close after BNPick selection")
    assert_ok(after_pick_buf ~= before_pick_buf, "BNPick should switch to selected buffer")
    assert_ok(not state.is_sidebar_open(), "sidebar should remain closed after BNPick selection")

    active_group = groups.get_active_group()
    local before_close_count = #(active_group.buffers or {})
    local current_buf = vim.api.nvim_get_current_buf()
    local close_index = 1
    for i, buf_id in ipairs(active_group.buffers or {}) do
        if buf_id ~= current_buf then
            close_index = i
            break
        end
    end
    local close_target = active_group.buffers[close_index]

    local ok_close, close_err = pcall(vim.cmd, "BNPickClose")
    assert_ok(ok_close, "BNPickClose command should succeed: " .. tostring(close_err))
    assert_ok(not state.is_sidebar_open(), "BNPickClose should not open sidebar when sidebar is closed")

    local close_menu_buf = vim.api.nvim_get_current_buf()
    local close_menu_ft = vim.api.nvim_buf_get_option(close_menu_buf, "filetype")
    assert_ok(close_menu_ft == "vertical-bufferline-menu", "BNPickClose should open popup menu")

    vbl.menu_select_by_index(close_index)
    vim.wait(120)

    active_group = groups.get_active_group()
    local after_close_count = #(active_group.buffers or {})
    assert_ok(after_close_count == before_close_count - 1, "BNPickClose should remove selected buffer from active group")
    assert_ok(not groups.find_buffer_group(close_target), "closed buffer should be removed from group membership")
    assert_ok(not state.is_sidebar_open(), "sidebar should remain closed after BNPickClose selection")

    print("pick command popup mode test: ok")
end)
if ok then
    vim.cmd("qa!")
else
    print(err)
    vim.cmd("cq!")
end
