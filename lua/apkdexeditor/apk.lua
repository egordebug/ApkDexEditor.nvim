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
            vim.notify("Usage: :ApkOpen DexEditor <file|Compile|Back|List>", vim.log.levels.ERROR)
            return
        end

        local action = args[2]

        if action == "Back" then
            close_apk_session()
            if _G.ADE_State.MainProjectPath then
                vim.cmd("cd " .. vim.fn.shellescape(_G.ADE_State.MainProjectPath))
            end
            vim.notify("APK session closed.", vim.log.levels.INFO)
            return

        elseif action == "Compile" then
            local session = _G.ADE_State.ApkSession
            if not session or session.root == "" then 
                vim.notify("No APK session active!", vim.log.levels.ERROR)
                return 
            end
            
            local root = session.root
            local original_apk = session.original_apk
            local modified_apk = root .. "/mod_work.apk"

            local handle = io.popen('ls -d ' .. root .. '/smali* 2>/dev/null')
            local smali_folders = {}
            for line in handle:lines() do table.insert(smali_folders, line) end
            handle:close()

            for _, folder_path in ipairs(smali_folders) do
                local folder_name = vim.fn.fnamemodify(folder_path, ":t")
                local dex_name = folder_name == "smali" and "classes.dex" or folder_name:gsub("^smali_", "") .. ".dex"
                
                local cmd = string.format("java -jar %s a %s -o %s/%s", 
                    misc.jars.smali, folder_path, root, dex_name)
                
                if not misc.exec_log(cmd, "Compiling " .. folder_name) then return end
            end

            os.execute(string.format('cp %s %s', vim.fn.shellescape(original_apk), vim.fn.shellescape(modified_apk)))
            
            local dex_files_str = ""
            for _, folder_path in ipairs(smali_folders) do
                local folder_name = vim.fn.fnamemodify(folder_path, ":t")
                local dex_name = folder_name == "smali" and "classes.dex" or folder_name:gsub("^smali_", "") .. ".dex"
                dex_files_str = dex_files_str .. " " .. dex_name
            end

            local zip_cmd = string.format('cd %s && zip -u -0 %s %s', 
                vim.fn.shellescape(root), vim.fn.shellescape(modified_apk), dex_files_str)
            
            if not misc.exec_log(zip_cmd, "ZIP Injection (All DEX)") then return end
            local backup_apk = original_apk .. ".bak"
            if vim.fn.filereadable(backup_apk) == 0 then
                os.execute(string.format('mv %s %s', vim.fn.shellescape(original_apk), vim.fn.shellescape(backup_apk)))
            else
                os.remove(original_apk)
            end
            os.execute(string.format('mv %s %s', vim.fn.shellescape(modified_apk), vim.fn.shellescape(original_apk)))
            
            vim.notify("APK Compiled (All DEX) successfully!", vim.log.levels.INFO)
            return
        elseif action == "List" then
            local root = _G.ADE_State.ApkSession.root
            if root == "" then vim.notify("No APK session!", vim.log.levels.ERROR); return end

            local handle = io.popen('ls -d ' .. root .. '/smali* 2>/dev/null')
            local dex_folders = {}
            for line in handle:lines() do table.insert(dex_folders, vim.fn.fnamemodify(line, ":t")) end
            handle:close()

            vim.ui.select(dex_folders, { prompt = 'Switch to DEX folder:' }, function(choice)
                if choice then
                    _G.ADE_State.ApkSession.target_dex = choice
                    vim.cmd("cd " .. root .. "/" .. choice)
                    if vim.fn.exists(':Neotree') > 0 then 
                        vim.cmd("Neotree close")
                        vim.cmd("Neotree float dir=" .. root .. "/" .. choice) 
                    end
                end
            end)
            return
        end
        local apk = vim.fn.expand(action)
        if vim.fn.filereadable(apk) == 0 then vim.notify("APK not found!", vim.log.levels.ERROR); return end

        close_apk_session()
        local base_dir = misc.get_tmp_dir("apk_project")
        _G.ADE_State.ApkSession.original_apk = vim.fn.fnamemodify(apk, ":p")
        _G.ADE_State.ApkSession.root = base_dir

        if misc.exec_log("apktool d -f " .. vim.fn.shellescape(apk) .. " -o " .. vim.fn.shellescape(base_dir), "APKtool Decode") then
            vim.cmd("ApkOpen DexEditor List")
        end
    end, { 
        nargs = '+',
        complete = function() return {"DexEditor"} end
    })
end
