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
    -- Find the line containing 'snakemake' and insert forcerun after it
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local insert_at = 3  -- fallback to line 3 if snakemake not found
    for i, line in ipairs(lines) do
      if string.match(line, "snakemake") then
        insert_at = i  -- insert after this line (i is 1-indexed, buf_set_lines is 0-indexed)
        break
      end
    end
    vim.api.nvim_buf_set_lines(0, insert_at, insert_at, false, {current_line})
    -- Optionally, save the file after the modification
    vim.cmd('write')
end

-- vim.keymap.set("n", "asd", M.open_and_insert())

return M

