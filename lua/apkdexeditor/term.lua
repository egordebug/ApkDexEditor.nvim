local M = {}
local term_state = { floating = { buf = -1, win = -1 } }

local function update_terminal_title(mode)
    if term_state.floating.win and vim.api.nvim_win_is_valid(term_state.floating.win) then
        local title = mode == "visual" and " [  ] " or " [   ] "
        vim.api.nvim_win_set_config(term_state.floating.win, {
            title = title,
            title_pos = "center"
        })
    end
end

local function create_floating_window(opts)
    opts = opts or {}
    local width = math.floor(vim.o.columns * 0.95)
    local height = math.floor(vim.o.lines * 0.8)
    local col = math.floor((vim.o.columns - width) / 2)
    local row = math.floor((vim.o.lines - height) / 2)

    local buf = (opts.buf and vim.api.nvim_buf_is_valid(opts.buf)) and opts.buf or vim.api.nvim_create_buf(false, true)
    
    local win_config = {
        relative = "editor",
        width = width,
        height = height,
        col = col,
        row = row,
        style = "minimal",
        border = "rounded",
        title = " [   ] ",
        title_pos = "center",
    }
    
    local win = vim.api.nvim_open_win(buf, true, win_config)
    return { buf = buf, win = win }
end

function M.toggle_terminal()
    if not vim.api.nvim_win_is_valid(term_state.floating.win) then
        term_state.floating = create_floating_window({ buf = term_state.floating.buf })
        local buf = term_state.floating.buf

        if vim.bo[buf].buftype ~= "terminal" then
            local shell = 'sh'
            for _, s in ipairs({'zsh', 'bash', 'sh'}) do
                if vim.fn.executable(s) == 1 then shell = s; break end
            end
            vim.fn.termopen(shell)
            vim.api.nvim_create_autocmd("ModeChanged", {
                buffer = buf,
                callback = function()
                    local mode = vim.api.nvim_get_mode().mode
                    if mode == 'n' then
                        update_terminal_title("term")
                        vim.schedule(function()
                            if vim.api.nvim_get_mode().mode == 'n' then
                                vim.cmd("startinsert")
                            end
                        end)
                    elseif mode:match("[vV]") then
                        update_terminal_title("visual")
                    end
                end,
            })
            vim.keymap.set('t', '<Esc>', [[<C-\><C-n>v]], { buffer = buf })
            vim.keymap.set('v', '<Esc>', [[<C-\><C-n>i]], { buffer = buf })
            vim.keymap.set('v', 'y', [[y<C-\><C-n>i]], { buffer = buf })
            local current_dir = vim.fn.expand("%:p:h")
            vim.api.nvim_win_set_config(win, {
                title = string.format(" [   %s ] ", shell),
            })
            if _G.ADE_State and _G.ADE_State.ApkSession.root ~= "" then 
                current_dir = _G.ADE_State.ApkSession.root 
            end
            if current_dir:match("^~") then
                local home = os.getenv("HOME")
                current_dir = current_dir:gsub("^~", home)
            end

            if current_dir ~= "" and vim.fn.isdirectory(current_dir) == 1 then
                 vim.defer_fn(function()
                     if vim.api.nvim_buf_is_valid(buf) then
                        vim.api.nvim_chan_send(vim.b[buf].terminal_job_id, "cd " .. vim.fn.shellescape(current_dir) .. " && clear\n")
                     end
                 end, 100)
            end
        end
        vim.cmd("startinsert")
        update_terminal_title("term")
    else
        vim.api.nvim_win_hide(term_state.floating.win)
        vim.cmd("stopinsert")
    end
end

return M
