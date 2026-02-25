local M = {}
local term = require('apk-editor.term')

function M.setup()
    vim.keymap.set({ "n", "t" }, "<C-t>", term.toggle_terminal, { desc = "Toggle Terminal" })
    vim.keymap.set('t', '<Esc>', [[<C-\><C-n>]], { desc = 'Exit terminal mode' })

    vim.api.nvim_create_user_command('AdbInstall', function(opts)
        local file = opts.args == "" and _G.ADE_State.ApkSession.original_apk or vim.fn.expand(opts.args)
        if file == "" or vim.fn.filereadable(file) == 0 then print("File not found"); return end
        vim.fn.system("adb install -r " .. vim.fn.shellescape(file))
        vim.notify("Installed: " .. file)
    end, { nargs = '?', complete = 'file' })

    vim.api.nvim_create_user_command('AdbPush', function(opts)
        if opts.args == "" then print("Provide file to push"); return end
        local args = vim.split(opts.args, " ")
        local src = vim.fn.expand(args[1])
        local dest = args[2] or "/data/local/tmp/"
        vim.fn.system(string.format("adb push %s %s", vim.fn.shellescape(src), vim.fn.shellescape(dest)))
        vim.notify("Pushed " .. src .. " to " .. dest)
    end, { nargs = '+', complete = 'file' })
end

return M
