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
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

    -- If --forcerun already exists, append the rule name to that line
    local forcerun_idx = nil
    for i, line in ipairs(lines) do
      if string.match(line, "%-%-forcerun") then
        forcerun_idx = i
        break
      end
    end

    if forcerun_idx ~= nil then
      -- Strip trailing whitespace and backslash, append new rule, restore backslash
      local updated = string.gsub(lines[forcerun_idx], "%s*\\%s*$", "")
      updated = updated .. " " .. rule_line .. " \\"
      vim.api.nvim_buf_set_lines(0, forcerun_idx - 1, forcerun_idx, false, {updated})
    else
      -- No --forcerun yet: insert a new line after the snakemake line
      local insert_at
      for i, line in ipairs(lines) do
        if string.match(line, "snakemake") then
          insert_at = i
          break
        end
      end
      if insert_at == nil then
        error("snakemake not found in run.sh")
      end
      vim.api.nvim_buf_set_lines(0, insert_at, insert_at, false, {current_line})
    end

    vim.cmd('write')
end

-- vim.keymap.set("n", "asd", M.open_and_insert())

return M

