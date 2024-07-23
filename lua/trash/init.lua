-- print("loaded trash plugin")
-- require("trash")
--
local M = {}
M.example = function()
  -- print("executed trash plugin")
end

M.setup = function(opts)
  -- print("setup trash plugin")
end

-- Function to open the file and insert the line
-- 
---@return nil                                                                                                                                                                 
M.open_and_insert = function()
	-- Capture the current line and append --forcerun
    local rule_line = vim.api.nvim_get_current_line()
	rule_line = string.gsub(rule_line, "rule%s*", "")  -- Removes 'rule' and any following spaces
	rule_line = string.gsub(rule_line, ":%s*", "")
    local current_line = " --forcerun " .. rule_line .. " \\"

    -- Open the file run.sh
    vim.cmd('edit run.sh')
    -- Ensure the buffer is loaded
    vim.api.nvim_buf_set_lines(0, 3, 3, false, {current_line})
	--vim.api.nvim_buf_set_lines(0, 3, 3, false, {"--forcerun doit"})
    -- Optionally, save the file after the modification
    vim.cmd('write')
end

-- vim.keymap.set("n", "asd", M.open_and_insert())

return M

