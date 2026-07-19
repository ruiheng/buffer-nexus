-- Automated check for :edit of a missing file refreshing the sidebar before edits
local function assert_ok(condition, message)
    if not condition then
        error(message, 2)
    end
end

local function add_rtp_root()
    local cwd = vim.fn.getcwd()
    local rtp_root = vim.fn.fnamemodify(cwd, ":h:h")
    vim.opt.rtp:append(rtp_root)
end

local function ensure_missing(path)
    if vim.loop.fs_stat(path) then
        vim.fn.delete(path)
    end
end

add_rtp_root()
local ok, err = pcall(function()

local vbl = require('buffer-nexus')
vbl.setup({
    auto_create_groups = true,
    auto_add_new_buffers = true,
    group_scope = "global",
    floating = false,
})

local groups = require('buffer-nexus.groups')

vbl.toggle()

local missing_path = vim.fn.tempname() .. "_bn_new_file"
ensure_missing(missing_path)
vim.cmd("edit " .. vim.fn.fnameescape(missing_path))

local missing_buf = vim.api.nvim_get_current_buf()
local active_group = groups.get_active_group()
assert_ok(active_group ~= nil, "active group should exist")
assert_ok(vim.tbl_contains(active_group.buffers, missing_buf), "new file buffer should be in active group before edits")

print("OK: new file edit refresh")
end)
if ok then
    -- Use qa! to force quit without saving, avoiding hangs from window cleanup
    vim.cmd("qa!")
else
    vim.cmd("cq!")
end
