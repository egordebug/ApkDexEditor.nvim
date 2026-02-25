local M = {}
local misc = require('apk-editor.misc')

local function open_tree(path)
    if vim.fn.exists(':Neotree') > 0 then
        vim.cmd("Neotree close")
        vim.cmd("Neotree float dir=" .. vim.fn.fnameescape(path))
    else
        vim.cmd("Explore " .. vim.fn.fnameescape(path))
    end
end

local function close_session()
    if _G.ADE_State.SmaliSession.root ~= "" then
        pcall(function()
            if vim.fn.exists(':Neotree') > 0 then vim.cmd("Neotree close") end
            local base_dir = _G.ADE_State.SmaliSession.root:gsub("/out$", "")
            if vim.fn.isdirectory(base_dir) == 1 then
                os.execute("rm -rf " .. vim.fn.shellescape(base_dir))
            end
        end)
        _G.ADE_State.SmaliSession = { root = "", original_file = "", type = "" }
    end
end

local function handle_smali_engine(engine_type, args)
    if #args == 0 then
        vim.notify("Usage: :" .. engine_type .. "2Smali <file|Compile|Back|Search|SearchFile>", vim.log.levels.ERROR)
        return
    end

    local arg1 = args[1]
    local ext = engine_type:lower()

    if arg1 == "Compile" or arg1 == "Back" or arg1 == "Search" or arg1 == "SearchFile" then
        if _G.ADE_State.SmaliSession.root == "" then
            vim.notify("No active Smali session! Open a file first.", vim.log.levels.ERROR)
            return
        end

        if arg1 == "Back" then
            close_session()
            vim.cmd("cd " .. vim.fn.shellescape(_G.ADE_State.MainProjectPath))
            vim.notify("Returned to " .. _G.ADE_State.MainProjectPath)
            return

        elseif arg1 == "Compile" then
            local tmp_dir = _G.ADE_State.SmaliSession.root:gsub("/out$", "")
            local orig_file = _G.ADE_State.SmaliSession.original_file
            
            if not misc.exec_log(string.format("java -jar %s a %s/out -o %s/classes.dex", misc.jars.smali, tmp_dir, tmp_dir), "Smali Compilation") then return end
            
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
                vim.notify("Java files cannot be cleanly recompiled from smali directly without full build system.", vim.log.levels.WARN)
            end
            vim.notify("Compiled successfully. Replaced " .. orig_file, vim.log.levels.INFO)
            return

        elseif arg1 == "Search" then
            if not args[2] then vim.notify("Provide search query", vim.log.levels.ERROR); return end
            pcall(vim.cmd, string.format("vimgrep /%s/j %s/**/*.smali", args[2], _G.ADE_State.SmaliSession.root))
            vim.cmd("copen")
            return

        elseif arg1 == "SearchFile" then
            if not args[2] then vim.notify("Provide filename", vim.log.levels.ERROR); return end
            local find_cmd = string.format("find %s -name '%s'", _G.ADE_State.SmaliSession.root, args[2])
            local res = vim.fn.system(find_cmd)
            if res ~= "" then print("Found:\n" .. res) else print("Not found.") end
            return
        end
    end

    local target_file = vim.fn.expand(arg1)
    if vim.fn.filereadable(target_file) == 0 or not target_file:match("%." .. ext .. "$") then
        vim.notify("Incorrect filename or argument. Expected ." .. ext, vim.log.levels.ERROR)
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
        misc.exec_log(string.format('javac -cp .:%s %s -d %s', android_jar, vim.fn.shellescape(target_file), tmp_dir), "Javac")
        misc.exec_log(string.format('d8 %s/*.class --lib %s --output %s', tmp_dir, android_jar, tmp_dir), "D8")
    elseif ext == "class" then
        misc.exec_log(string.format('d8 %s --output %s', vim.fn.shellescape(target_file), tmp_dir), "D8")
    elseif ext == "dex" then
        os.execute(string.format('cp %s %s/classes.dex', vim.fn.shellescape(target_file), tmp_dir))
    end

    if misc.exec_log(string.format('java -jar %s d %s/classes.dex -o %s/out', misc.jars.baksmali, tmp_dir, tmp_dir), "Baksmali") then
        vim.cmd("cd " .. _G.ADE_State.SmaliSession.root)
        open_tree(_G.ADE_State.SmaliSession.root)
    end
end

function M.setup_commands()
    vim.api.nvim_create_user_command('Dex2Smali', function(opts) handle_smali_engine("Dex", opts.fargs) end, { nargs = '+' })
    vim.api.nvim_create_user_command('Class2Smali', function(opts) handle_smali_engine("Class", opts.fargs) end, { nargs = '+' })
    vim.api.nvim_create_user_command('Java2Smali', function(opts) handle_smali_engine("Java", opts.fargs) end, { nargs = '+' })
end

return M
