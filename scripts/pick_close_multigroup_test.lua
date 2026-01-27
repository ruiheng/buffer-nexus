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

vbl.setup({ position = "left", floating = false, pick_chars = "abc" })
groups.setup({ auto_add_new_buffers = false })
bufferline_integration.is_available = function()
    return false
end

local path = string.format("%s/%03d.txt", tmpdir, 1)
vim.fn.writefile({ "x" }, path)
vim.cmd("edit " .. vim.fn.fnameescape(path))
local buf_id = vim.api.nvim_get_current_buf()

local group1 = groups.create_group("one")
local group2 = groups.create_group("two")

assert_ok(groups.add_buffer_to_group(buf_id, group1), "expected buffer in group1")
assert_ok(groups.add_buffer_to_group(buf_id, group2), "expected buffer in group2")

groups.set_active_group(group2)

vbl.toggle()
vbl.refresh("pick_close_multigroup_test")
vim.wait(50)

local line_to_buffer = state.get_line_to_buffer_id()
local line_group_context = state.get_line_group_context()
local line_num = nil
for line, id in pairs(line_to_buffer or {}) do
    if id == buf_id and line_group_context and line_group_context[line] == group2 then
        line_num = line
        break
    end
end
assert_ok(line_num ~= nil, "expected buffer line in group2")

state.set_extended_picking_pick_chars({ [line_num] = "a" }, { a = line_num }, {})
state.set_extended_picking_active(true)
state.set_extended_picking_mode("close")
local ok_close = vbl._handle_extended_picking_key_for_test("a")
assert_ok(ok_close, "expected pick close to succeed")

local remaining_groups = groups.find_buffer_groups(buf_id)
assert_ok(#remaining_groups == 1, "expected buffer to remain in one group")
assert_ok(remaining_groups[1].id == group1, "expected buffer to remain in group1")

vbl.close_sidebar()

print("pick close multigroup test: ok")
end)
if ok then
    vim.cmd("qa!")
else
    print(err)
    vim.cmd("cq!")
end
