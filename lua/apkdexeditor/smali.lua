local M = {}
local misc = require('apkdexeditor.misc')
local state_file = vim.fn.stdpath('data') .. '/ade_smali_session.txt'

local function cleanup_temp_data(root_path)
    if root_path and root_path ~= "" then
        local base_dir = root_path:gsub("/out$", "")
        if vim.fn.isdirectory(base_dir) == 1 then
            os.execute("rm -rf " .. vim.fn.shellescape(base_dir))
        end
    end
    os.remove(state_file)
end

local function save_session()
    local s = _G.ADE_State.SmaliSession
    if s and s.root ~= "" and s.type == "dex" then
        local f = io.open(state_file, "w")
        if f then
            f:write(string.format("%s\n%s\n%s", s.root, s.original_file, s.type))
            f:close()
        end
    end
end

local function open_tree(path)
    if vim.fn.exists(':Neotree') > 0 then
        vim.cmd("Neotree close")
        vim.cmd("Neotree float dir=" .. vim.fn.fnameescape(path))
    else
        vim.cmd("Explore " .. vim.fn.fnameescape(path))
    end
end

local function close_session()
    if _G.ADE_State.SmaliSession and _G.ADE_State.SmaliSession.root ~= "" then
        pcall(function()
            if vim.fn.exists(':Neotree') > 0 then vim.cmd("Neotree close") end
            cleanup_temp_data(_G.ADE_State.SmaliSession.root)
        end)
        _G.ADE_State.SmaliSession = { root = "", original_file = "", type = "" }
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
        vim.ui.select({ "Restore DEX Session", "Ignore", "Delete Session" }, {
            prompt = "Active Dex2Smali session detected:",
        }, function(choice)
            if choice == "Restore DEX Session" then
                _G.ADE_State.SmaliSession = { 
                    root = root, 
                    original_file = lines[2] or "", 
                    type = lines[3] or "dex" 
                }
                vim.cmd("cd " .. vim.fn.shellescape(root))
                vim.notify("DEX Session restored", vim.log.levels.INFO)
            elseif choice == "Delete Session" then
                cleanup_temp_data(root)
                _G.ADE_State.SmaliSession = { root = "", original_file = "", type = "" }
                vim.notify("Temporary files deleted", vim.log.levels.WARN)
            end
        end)
    end)
end

local function handle_smali_engine(engine_type, args)
    if #args == 0 then
        vim.notify("Usage: :" .. engine_type .. "2Smali <file|Compile|Back|List|Search|SearchFile>", vim.log.levels.ERROR)
        return
    end

    local arg1 = args[1]
    local ext = engine_type:lower()

    if arg1 == "Compile" or arg1 == "Back" or arg1 == "List" or arg1 == "Search" or arg1 == "SearchFile" then
        if not _G.ADE_State.SmaliSession or _G.ADE_State.SmaliSession.root == "" then
            vim.notify("No active Smali session!", vim.log.levels.ERROR)
            return
        end

        if arg1 == "Back" then
            close_session()
            if _G.ADE_State.MainProjectPath then
                vim.cmd("cd " .. vim.fn.shellescape(_G.ADE_State.MainProjectPath))
            end
            vim.notify("Session closed.")
            return

        elseif arg1 == "List" then
            local root = _G.ADE_State.SmaliSession.root
            vim.cmd("cd " .. vim.fn.shellescape(root))
            open_tree(root)
            return

        elseif arg1 == "Compile" then
            local session = _G.ADE_State.SmaliSession
            local tmp_dir = session.root:gsub("/out$", "")
            local orig_file = session.original_file
            
            local smali_cmd = string.format("java -jar %s a %s/out -o %s/classes.dex", misc.jars.smali, tmp_dir, tmp_dir)
            if not misc.exec_log(smali_cmd, "Smali Compilation") then return end
            
            local backup_file = orig_file .. ".bak"
            if vim.fn.filereadable(backup_file) == 0 then
                os.execute(string.format('cp %s %s', vim.fn.shellescape(orig_file), vim.fn.shellescape(backup_file)))
            else
                os.remove(orig_file)
            end

            if engine_type == "Dex" then
                os.execute(string.format('cp %s/classes.dex %s', tmp_dir, vim.fn.shellescape(orig_file)))
            elseif engine_type == "Class" then
                misc.exec_log(string.format('dex2jar %s/classes.dex -o %s', tmp_dir, vim.fn.shellescape(orig_file)), "Dex2Jar")
            elseif engine_type == "Java" then
                vim.notify("Java files cannot be fully recompiled to .java from smali.", vim.log.levels.WARN)
            end
            vim.notify("Replaced: " .. orig_file, vim.log.levels.INFO)
            return

        elseif arg1 == "Search" then
            if not args[2] then vim.notify("Query required", vim.log.levels.ERROR); return end
            vim.cmd(string.format("silent! vimgrep /%s/j %s/**/*.smali", args[2], _G.ADE_State.SmaliSession.root))
            vim.cmd("copen")
            return
        end
    end

    local target_file = vim.fn.expand(arg1)
    if vim.fn.filereadable(target_file) == 0 then
        vim.notify("File not found: " .. target_file, vim.log.levels.ERROR)
        return
    end

    close_session()
    local tmp_dir = misc.get_tmp_dir(engine_type .. "2Smali")
    os.execute("mkdir -p " .. tmp_dir)
    
    _G.ADE_State.SmaliSession.root = tmp_dir .. "/out"
    _G.ADE_State.SmaliSession.original_file = vim.fn.fnamemodify(target_file, ":p")
    _G.ADE_State.SmaliSession.type = ext

    if ext == "java" then
        local android_jar = misc.jars.android_jar
        if not misc.exec_log(string.format('javac -cp .:%s %s -d %s', android_jar, vim.fn.shellescape(target_file), tmp_dir), "Javac") then return end
        misc.exec_log(string.format('d8 %s/*.class --lib %s --output %s', tmp_dir, android_jar, tmp_dir), "D8")
    elseif ext == "class" then
        misc.exec_log(string.format('d8 %s --output %s', vim.fn.shellescape(target_file), tmp_dir), "D8")
    elseif ext == "dex" then
        os.execute(string.format('cp %s %s/classes.dex', vim.fn.shellescape(target_file), tmp_dir))
    end

    local baksmali_cmd = string.format('java -jar %s d %s/classes.dex -o %s/out', misc.jars.baksmali, tmp_dir, tmp_dir)
    if misc.exec_log(baksmali_cmd, "Baksmali") then
        save_session()
        vim.cmd("cd " .. _G.ADE_State.SmaliSession.root)
        open_tree(_G.ADE_State.SmaliSession.root)
    end
end

function M.setup_commands()
    local opts = { nargs = '+', complete = function() return {"Compile", "Back", "List", "Search"} end }
    vim.api.nvim_create_user_command('Dex2Smali', function(o) handle_smali_engine("Dex", o.fargs) end, opts)
    vim.api.nvim_create_user_command('Class2Smali', function(o) handle_smali_engine("Class", o.fargs) end, opts)
    vim.api.nvim_create_user_command('Java2Smali', function(o) handle_smali_engine("Java", o.fargs) end, opts)
end

return M
