local M = {}

function M.setup(opts)
    require('apk-editor.misc')
    require('apk-editor.smali').setup_commands()
    require('apk-editor.apk').setup_commands()
    require('apk-editor.keybinds').setup()
end

return M
