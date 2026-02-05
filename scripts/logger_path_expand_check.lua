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

add_rtp_root()

local ok, err = pcall(function()
    local logger = require("buffer-nexus.logger")

    local home = vim.fn.expand("~")
    assert_ok(home and home ~= "" and home ~= "~", "failed to resolve home directory")

    local base = "bn-logger-test-" .. vim.fn.fnamemodify(vim.fn.tempname(), ":t") .. ".log"
    local repo = vim.fn.getcwd()
    assert_ok(type(repo) == "string" and repo ~= "", "failed to resolve cwd")
    assert_ok(repo:sub(1, #home + 1) == home .. "/", "repo path is not under home; cannot build ~/ path")

    local rel_repo = repo:sub(#home + 2) -- strip "home/"
    local requested = "~/" .. rel_repo .. "/" .. base
    local expected = repo .. "/" .. base

    logger.enable(requested, "DEBUG")

    local status = logger.get_status()
    assert_ok(status.enabled == true, "logger not enabled")
    assert_ok(status.log_file == expected, "log file path not expanded: " .. tostring(status.log_file))
    assert_ok(vim.fn.filereadable(expected) == 1, "log file not created on disk: " .. expected)

    logger.disable()
    pcall(os.remove, expected)

    print("OK: logger expands ~ and writes to disk")
end)

if ok then
    vim.cmd("qa!")
else
    print("logger_path_expand_check failed: " .. tostring(err))
    vim.cmd("cq!")
end
