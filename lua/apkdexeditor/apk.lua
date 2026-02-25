local M = {}
local misc = require('apkdexeditor.misc')

local function close_apk_session()
    if _G.ADE_State.ApkSession.root ~= "" then
        if vim.fn.exists(':Neotree') > 0 then vim.cmd("Neotree close") end
        if vim.fn.isdirectory(_G.ADE_State.ApkSession.root) == 1 then
            os.execute("rm -rf " .. vim.fn.shellescape(_G.ADE_State.ApkSession.root))
        end
        _G.ADE_State.ApkSession = { root = "", target_dex = "", original_apk = "" }
    end
end

function M.setup_commands()
    vim.api.nvim_create_user_command('ApkOpen', function(opts)
        local args = opts.fargs
        if #args < 2 or args[1] ~= "DexEditor" then
            vim.notify("Usage: :ApkOpen DexEditor <file|Compile|Back>", vim.log.levels.ERROR)
            return
        end

        local action = args[2]

        if action == "Back" then
            close_apk_session()
            vim.cmd("cd " .. vim.fn.shellescape(_G.ADE_State.MainProjectPath))
            vim.notify("APK session closed.", vim.log.levels.INFO)
            return
        elseif action == "Compile" then
            if _G.ADE_State.ApkSession.root == "" then vim.notify("No APK session!", vim.log.levels.ERROR); return end
            
            local smali_folder = _G.ADE_State.ApkSession.root .. "/" .. _G.ADE_State.ApkSession.target_dex
            local original_apk = _G.ADE_State.ApkSession.original_apk
            local dex_name = _G.ADE_State.ApkSession.target_dex == "smali" and "classes.dex" or _G.ADE_State.ApkSession.target_dex:gsub("^smali_", "") .. ".dex"
            local modified_apk = _G.ADE_State.ApkSession.root .. "/mod_work.apk"
            local backup_apk = original_apk .. ".bak"

            if not misc.exec_log(string.format("java -jar %s a %s -o %s/%s", misc.jars.smali, smali_folder, _G.ADE_State.ApkSession.root, dex_name), "Smali Compile") then return end
            
            os.execute(string.format('cp %s %s', vim.fn.shellescape(original_apk), vim.fn.shellescape(modified_apk)))
            if not misc.exec_log(string.format('cd %s && zip -u -0 %s %s', vim.fn.shellescape(_G.ADE_State.ApkSession.root), vim.fn.shellescape(modified_apk), dex_name), "ZIP Injection") then return end

            if vim.fn.filereadable(backup_apk) == 0 then
                os.execute(string.format('mv %s %s', vim.fn.shellescape(original_apk), vim.fn.shellescape(backup_apk)))
            else
                os.remove(original_apk)
            end
            os.execute(string.format('mv %s %s', vim.fn.shellescape(modified_apk), vim.fn.shellescape(original_apk)))
            vim.notify("APK Compiled successfully!", vim.log.levels.INFO)
            return
        end

        -- Логика открытия APK
        local apk = vim.fn.expand(action)
        if vim.fn.filereadable(apk) == 0 then vim.notify("APK not found!", vim.log.levels.ERROR); return end

        close_apk_session()
        local base_dir = misc.get_tmp_dir("apk_project")
        
        _G.ADE_State.ApkSession.original_apk = vim.fn.fnamemodify(apk, ":p")
        _G.ADE_State.ApkSession.root = base_dir

        if misc.exec_log("apktool d -f " .. vim.fn.shellescape(apk) .. " -o " .. vim.fn.shellescape(base_dir), "APKtool Decode") then
            local handle = io.popen('ls -d ' .. base_dir .. '/smali* 2>/dev/null')
            local dex_folders = {}
            for line in handle:lines() do table.insert(dex_folders, vim.fn.fnamemodify(line, ":t")) end
            handle:close()

            if #dex_folders == 0 then vim.notify("No smali folders found", vim.log.levels.ERROR); return end

            vim.ui.select(dex_folders, { prompt = 'Select DEX (smali folder):' }, function(choice)
                if choice then
                    _G.ADE_State.ApkSession.target_dex = choice
                    vim.cmd("cd " .. base_dir .. "/" .. choice)
                    if vim.fn.exists(':Neotree') > 0 then vim.cmd("Neotree float dir=" .. base_dir .. "/" .. choice) end
                end
            end)
        end
    end, { nargs = '+' })
end

return M
