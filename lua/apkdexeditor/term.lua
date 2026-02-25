local M = {}
local term_state = { floating = { buf = -1, win = -1 } }

local function create_floating_window(opts)
    opts = opts or {}
    local width = math.floor(vim.o.columns * 0.9)
    local height = math.floor(vim.o.lines * 0.8)
    local col = math.floor((vim.o.columns - width) / 2)
    local row = math.floor((vim.o.lines - height) / 2)

    local buf = (opts.buf and vim.api.nvim_buf_is_valid(opts.buf)) and opts.buf or vim.api.nvim_create_buf(false, true)
    local win_config = {
        relative = "editor", width = width, height = height,
        col = col, row = row, style = "minimal", border = "rounded",
    }
    return { buf = buf, win = vim.api.nvim_open_win(buf, true, win_config) }
end

function M.toggle_terminal()
    if not vim.api.nvim_win_is_valid(term_state.floating.win) then
        term_state.floating = create_floating_window({ buf = term_state.floating.buf })

        if vim.bo[term_state.floating.buf].buftype ~= "terminal" then
            local shell = 'sh'
            for _, s in ipairs({'zsh', 'bash', 'sh'}) do
                if vim.fn.executable(s) == 1 then shell = s; break end
            end
            vim.fn.termopen(shell)

            local current_dir = vim.fn.expand("%:p:h")
            if _G.ADE_State.ApkSession.root ~= "" then 
                current_dir = _G.ADE_State.ApkSession.root 
            elseif _G.ADE_State.SmaliSession.root ~= "" then
                current_dir = _G.ADE_State.SmaliSession.root
            end

            if current_dir:match("^term://") then
                current_dir = current_dir:gsub("^term://.-//", "")
            end
            if current_dir:match("^~") then
                local home = os.getenv("HOME")
                if not home or home == "" then
                    local user = vim.fn.system("whoami"):gsub("\n", "")
                    home = user == "root" and "/root" or "/home/" .. user
                end
                current_dir = current_dir:gsub("^~", home)
            end

            if current_dir ~= "" and vim.fn.isdirectory(current_dir) == 1 then
                 vim.defer_fn(function()
                     vim.api.nvim_chan_send(vim.b.terminal_job_id, "cd " .. vim.fn.shellescape(current_dir) .. " && clear\n")
                 end, 50)
            end
        end
        vim.cmd("startinsert")
    else
        vim.api.nvim_win_hide(term_state.floating.win)
    end
end

return M
