-- Automated check for edit-mode file move/rename behavior
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

local function cleanup_file(path)
    if vim.loop.fs_stat(path) then
        vim.fn.delete(path)
    end
end

local function create_file(path, content)
    local f = io.open(path, "w")
    if f then
        f:write(content or "test content\n")
        f:close()
    end
end

add_rtp_root()

local vbl = require('buffer-nexus')
vbl.setup({
    group_scope = "global",
    auto_create_groups = true,
    auto_add_new_buffers = true,
})

local groups = require('buffer-nexus.groups')
local edit_mode = require('buffer-nexus.edit_mode')

local function find_group(name)
    for _, group in ipairs(groups.get_all_groups() or {}) do
        if group.name == name then
            return group
        end
    end
    return nil
end

local function group_has_path(group, target)
    for _, buf_id in ipairs(group.buffers or {}) do
        if vim.api.nvim_buf_is_valid(buf_id) then
            local name = vim.api.nvim_buf_get_name(buf_id)
            if name == target then
                return true
            end
        end
    end
    return false
end

-- Create test files
local test_dir = vim.fn.fnamemodify(vim.fn.tempname(), ":h") .. "/bn_move_test"
vim.fn.mkdir(test_dir, "p")
local old_file = test_dir .. "/old_file.txt"
local new_file = test_dir .. "/new_file.txt"
local moved_file = test_dir .. "/subdir/moved_file.txt"

cleanup_file(old_file)
cleanup_file(new_file)
cleanup_file(moved_file)
vim.fn.mkdir(test_dir .. "/subdir", "p")

create_file(old_file, "original content")

-- Load file into buffer so it can be found by buffer_maps
local old_bufnr = vim.fn.bufnr(old_file, true)
vim.api.nvim_buf_set_lines(old_bufnr, 0, -1, false, { "original content" })
vim.api.nvim_buf_set_option(old_bufnr, "modified", false)

-- Test 1: Basic rename (old -> new)
local edit_buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(edit_buf, 0, -1, false, {
    "[Group] Test",
    old_file .. " -> " .. new_file,
})

edit_mode.apply(edit_buf)
vim.api.nvim_buf_delete(edit_buf, { force = true })

-- Verify: old file gone, new file exists, buffer updated
assert_ok(not vim.loop.fs_stat(old_file), "old file should be removed after rename")
assert_ok(vim.loop.fs_stat(new_file), "new file should exist after rename")

local new_bufnr = vim.fn.bufnr(new_file, false)
assert_ok(new_bufnr > 0, "buffer should exist for new file")

local buf_content = vim.api.nvim_buf_get_lines(new_bufnr, 0, -1, true)
assert_ok(buf_content[1] == "original content", "file content should be preserved")

-- Verify: buffer is in the group
local test_group = find_group("Test")
assert_ok(test_group ~= nil, "Test group should exist")
assert_ok(group_has_path(test_group, new_file), "moved file should be in Test group")

-- Test 2: Move to subdirectory
create_file(old_file, "move test content")
local subdir_buf = vim.fn.bufnr(old_file, true)
vim.api.nvim_buf_set_lines(subdir_buf, 0, -1, false, { "move test content" })
vim.api.nvim_buf_set_option(subdir_buf, "modified", false)

local edit_buf2 = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(edit_buf2, 0, -1, false, {
    "[Group] Test",
    old_file .. " -> " .. moved_file,
})

edit_mode.apply(edit_buf2)
vim.api.nvim_buf_delete(edit_buf2, { force = true })

assert_ok(not vim.loop.fs_stat(old_file), "old file should be removed after move")
assert_ok(vim.loop.fs_stat(moved_file), "moved file should exist")

local moved_bufnr = vim.fn.bufnr(moved_file, false)
assert_ok(moved_bufnr > 0, "buffer should exist for moved file")
assert_ok(moved_bufnr == subdir_buf, "same buffer should be used after move")

-- Test 3: Error - moving modified buffer should fail
create_file(old_file, "modified test")
local modified_buf = vim.fn.bufnr(old_file, true)
vim.api.nvim_buf_set_lines(modified_buf, 0, -1, false, { "modified content" })
assert_ok(vim.api.nvim_buf_get_option(modified_buf, "modified") == true, "buffer should be modified")

local edit_buf3 = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(edit_buf3, 0, -1, false, {
    "[Group] Test",
    old_file .. " -> " .. test_dir .. "/should_not_exist.txt",
})

-- Capture warnings by temporarily overriding vim.notify
local warnings = {}
local original_notify = vim.notify
vim.notify = function(msg, level)
    if level == vim.log.levels.WARN then
        table.insert(warnings, msg)
    end
end

edit_mode.apply(edit_buf3)
vim.notify = original_notify
vim.api.nvim_buf_delete(edit_buf3, { force = true })

assert_ok(#warnings > 0, "should have warning for modified buffer")
assert_ok(vim.loop.fs_stat(old_file), "old file should still exist (move rejected)")
assert_ok(not vim.loop.fs_stat(test_dir .. "/should_not_exist.txt"), "target should not be created")

-- Test 4: Error - moving non-existent file should fail
local edit_buf4 = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(edit_buf4, 0, -1, false, {
    "[Group] Test",
    test_dir .. "/nonexistent.txt -> " .. test_dir .. "/also_nonexistent.txt",
})

warnings = {}
vim.notify = function(msg, level)
    if level == vim.log.levels.WARN then
        table.insert(warnings, msg)
    end
end

edit_mode.apply(edit_buf4)
vim.notify = original_notify
vim.api.nvim_buf_delete(edit_buf4, { force = true })

assert_ok(#warnings > 0, "should have warning for non-existent file")

-- Cleanup
vim.fn.delete(test_dir, "rf")

print("OK: edit-mode move/rename")

-- Clear all modified flags before exit
for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_set_option(buf, "modified", false)
    end
end
vim.cmd("qa!")
