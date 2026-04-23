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
    -- Scan upward from the cursor to find the enclosing 'rule <name>:' line
    local cursor_row = vim.api.nvim_win_get_cursor(0)[1]  -- 1-indexed
    local buf_lines = vim.api.nvim_buf_get_lines(0, 0, cursor_row, false)
    local rule_line = nil
    for i = #buf_lines, 1, -1 do
      local m = string.match(buf_lines[i], "^rule%s+(%S+)%s*:")
      if m then
        rule_line = m
        break
      end
    end
    if rule_line == nil then
      error("no rule definition found above cursor")
    end
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

