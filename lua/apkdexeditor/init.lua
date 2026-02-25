local M = {}

function M.setup(opts)
    require('apkdexeditor.misc')
    require('apkdexeditor.smali').setup_commands()
    require('apkdexeditor.apk').setup_commands()
    require('apkdexeditor.keybinds').setup()
end

return M
