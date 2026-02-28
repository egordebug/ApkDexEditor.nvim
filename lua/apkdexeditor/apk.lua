local M = {}
local misc = require('apkdexeditor.misc')
local state_file = vim.fn.stdpath('data') .. '/ade_session.txt'
local progress_win = nil
local progress_buf = nil

local function show_progress(title, current, total)
    vim.schedule(function()
        if not progress_buf or not vim.api.nvim_buf_is_valid(progress_buf) then
            progress_buf = vim.api.nvim_create_buf(false, true)
        end
        
        local width = 40
        local height = 3
        local text = string.format(" %s", title)
        local bar = ""

        if total and total > 0 then
            text = string.format(" [%d/%d] %s", current, total, title)
            local bar_len = width - 4
            local fill = math.floor((current / total) * bar_len)
            bar = "[" .. string.rep("=", fill) .. string.rep(" ", bar_len - fill) .. "]"
        else
            bar = "[============= Wait =============]"
        end

        vim.api.nvim_buf_set_lines(progress_buf, 0, -1, false, { " ADE Progress", text, " " .. bar })

        if not progress_win or not vim.api.nvim_win_is_valid(progress_win) then
            local ui = vim.api.nvim_list_uis()[1]
            local row = ui.height - height - 2
            local col = ui.width - width - 2
            progress_win = vim.api.nvim_open_win(progress_buf, false, {
                relative = 'editor',
                width = width,
                height = height,
                row = row,
                col = col,
                style = 'minimal',
                border = 'rounded',
                zindex = 150,
            })
        end
    end)
end

local function close_progress()
    vim.schedule(function()
        if progress_win and vim.api.nvim_win_is_valid(progress_win) then
            vim.api.nvim_win_close(progress_win, true)
            progress_win = nil
        end
        if progress_buf and vim.api.nvim_buf_is_valid(progress_buf) then
            vim.api.nvim_buf_delete(progress_buf, {force = true})
            progress_buf = nil
        end
    end)
end
-- ========================
local function save_apk_session()
    local session = _G.ADE_State.ApkSession
    if session and session.root ~= "" then
        local f = io.open(state_file, "w")
        if f then
            f:write(session.root .. "\n" .. session.original_apk .. "\n" .. (session.target_dex or ""))
            f:close()
        end
    end
end

local function cleanup_temp_data(root_path)
    if root_path and root_path ~= "" and vim.fn.isdirectory(root_path) == 1 then
        os.execute("rm -rf " .. vim.fn.shellescape(root_path))
    end
    os.remove(state_file)
end

local function close_apk_session()
    if _G.ADE_State.ApkSession.root ~= "" then
        if vim.fn.exists(':Neotree') > 0 then vim.cmd("Neotree close") end
        cleanup_temp_data(_G.ADE_State.ApkSession.root)
        _G.ADE_State.ApkSession = { root = "", target_dex = "", original_apk = "" }
    end
end

function M.check_active_session()
    local f = io.open(state_file, "r")
    if not f then return end

    local lines = {}
    for line in f:lines() do table.insert(lines, line) end
    f:close()

    local root = lines[1]
    if not root or vim.fn.isdirectory(root) == 0 then
        os.remove(state_file)
        return
    end

    vim.schedule(function()
        vim.ui.select({ "Restore Session", "Ignore", "Delete Session" }, {
            prompt = "Active APK session detected:",
        }, function(choice)
            if choice == "Restore Session" then
                _G.ADE_State.ApkSession = { 
                    root = root, 
                    original_apk = lines[2] or "", 
                    target_dex = lines[3] or "" 
                }
                vim.cmd("cd " .. vim.fn.shellescape(root))
                vim.notify("Session restored", vim.log.levels.INFO)
            elseif choice == "Delete Session" then
                cleanup_temp_data(root)
                _G.ADE_State.ApkSession = { root = "", target_dex = "", original_apk = "" }
                vim.notify("Session and temporary files deleted", vim.log.levels.WARN)
            end
        end)
    end)
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

            if #smali_folders == 0 then
                vim.notify("No smali folders found!", vim.log.levels.WARN)
                return
            end
            local function inject_zip_async(dex_files_str)
                show_progress("Injecting to APK...", 0, 0)
                local zip_cmd = string.format('cd %s && zip -u -0 %s %s', 
                    vim.fn.shellescape(root), vim.fn.shellescape(modified_apk), dex_files_str)
                
                vim.fn.jobstart(zip_cmd, {
                    on_exit = function(_, code)
                        close_progress()
                        if code == 0 then
                            local backup_apk = original_apk .. ".bak"
                            if vim.fn.filereadable(backup_apk) == 0 then
                                os.execute(string.format('mv %s %s', vim.fn.shellescape(original_apk), vim.fn.shellescape(backup_apk)))
                            else
                                os.remove(original_apk)
                            end
                            os.execute(string.format('mv %s %s', vim.fn.shellescape(modified_apk), vim.fn.shellescape(original_apk)))
                            vim.notify("APK Compiled (All DEX) successfully!", vim.log.levels.INFO)
                        else
                            vim.notify("ZIP Injection failed!", vim.log.levels.ERROR)
                        end
                    end
                })
            end
            os.execute(string.format('cp %s %s', vim.fn.shellescape(original_apk), vim.fn.shellescape(modified_apk)))
            local dex_files = {}
            local current_task = 1
            local total_tasks = #smali_folders
            local function compile_next()
                if current_task > total_tasks then
                    local dex_files_str = table.concat(dex_files, " ")
                    inject_zip_async(dex_files_str)
                    return
                end

                local folder_path = smali_folders[current_task]
                local folder_name = vim.fn.fnamemodify(folder_path, ":t")
                local dex_name = folder_name == "smali" and "classes.dex" or folder_name:gsub("^smali_", "") .. ".dex"
                table.insert(dex_files, dex_name)
                
                show_progress("Compiling " .. folder_name, current_task, total_tasks)

                local cmd = string.format("java -jar %s a %s -o %s/%s", misc.jars.smali, folder_path, root, dex_name)
                
                vim.fn.jobstart(cmd, {
                    on_exit = function(_, code)
                        if code == 0 then
                            current_task = current_task + 1
                            compile_next()
                        else
                            close_progress()
                            vim.notify("Failed compiling " .. folder_name, vim.log.levels.ERROR)
                        end
                    end
                })
            end
            compile_next()
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
                    save_apk_session()
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
        
        show_progress("Decoding APK...", 0, 0)
        local cmd = "apktool d -f " .. vim.fn.shellescape(apk) .. " -o " .. vim.fn.shellescape(base_dir)
        vim.fn.jobstart(cmd, {
            on_exit = function(_, code)
                close_progress()
                if code == 0 then
                    _G.ADE_State.ApkSession.original_apk = vim.fn.fnamemodify(apk, ":p")
                    _G.ADE_State.ApkSession.root = base_dir
                    save_apk_session()
                    
                    vim.schedule(function()
                        vim.cmd("ApkOpen DexEditor List")
                    end)
                else
                    vim.notify("APKtool Decode failed!", vim.log.levels.ERROR)
                end
            end
        })

    end, { 
        nargs = '+',
        complete = function() return {"DexEditor"} end
    })
end

return M
