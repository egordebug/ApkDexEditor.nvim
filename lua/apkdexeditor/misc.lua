local M = {}

_G.ADE_State = {
    ApkSession = { root = "", target_dex = "", original_apk = "" },
    SmaliSession = { root = "", original_file = "", type = "" },
    MainProjectPath = vim.fn.getcwd()
}
local plugin_root = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":h:h:h")
M.jars = {
    smali = plugin_root .. "/bin/smali.jar",
    baksmali = plugin_root .. "/bin/baksmali.jar",
    android_jar = plugin_root .. "/bin/android.jar",
    signer = plugin_root .. "/bin/uber-apk-signer.jar"
}
function M.get_tmp_dir(prefix)
    local tmp = os.getenv("TMPDIR") or "/tmp"
    if vim.fn.isdirectory(tmp) == 0 then
        tmp = vim.fn.expand("~/.local/tmp")
        if vim.fn.isdirectory(tmp) == 0 then
            tmp = vim.fn.expand("$HOME/ade_tmp")
            if vim.fn.isdirectory(tmp) == 0 then vim.fn.mkdir(tmp, "p") end
        end
    end

    local unique = tostring(vim.loop.hrtime()):sub(-6)
    local folder_name = string.format("%s_%s_%s", prefix, os.date("%Y%m%d_%H%M%S"), unique)
    local full_path = tmp .. "/" .. folder_name
    
    return full_path
end

function M.exec_log(cmd, msg)
    print("ADE: " .. msg .. "...")
    local res = vim.fn.system(cmd)
    
    if vim.v.shell_error ~= 0 then
        vim.api.nvim_err_writeln(string.format(
            "ADE ERROR [%s]\nCommand: %s\nOutput: %s",
            msg, cmd, res
        ))
        return false
    end
    
    return true
end

function M.check_requirements()
    local reqs = { "java", "zip", "apktool" }
    for _, req in ipairs(reqs) do
        if vim.fn.executable(req) == 0 then
            vim.api.nvim_err_writeln("ADE: Missing dependency: " .. req)
            return false
        end
    end
    for name, path in pairs(M.jars) do
        if vim.fn.filereadable(path) == 0 then
            vim.api.nvim_err_writeln("ADE: Jar not found: " .. name .. " at " .. path)
            return false
        end
    end
    return true
end

return M
