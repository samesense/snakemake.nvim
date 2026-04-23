-- print("loaded trash plugin")
-- require("trash")
--
local M = {}
M.example = function()
  -- print("executed trash plugin")
end

-- ── helpers (no inter-dependencies) ──────────────────────────────────────────

-- Returns the quoted string on the current line that the cursor is inside,
-- falling back to vim's <cfile> expansion.
local function get_string_under_cursor()
  local line = vim.api.nvim_get_current_line()
  local col  = vim.api.nvim_win_get_cursor(0)[2] + 1  -- 1-based
  local pos  = 1
  while pos <= #line do
    local qs = line:find('["\']', pos)
    if not qs then break end
    local qchar = line:sub(qs, qs)
    local qe = line:find(qchar, qs + 1, true)
    if not qe then break end
    if col >= qs and col <= qe then
      return line:sub(qs + 1, qe - 1)
    end
    pos = qe + 1
  end
  return vim.fn.expand('<cfile>')
end

-- Converts a Snakemake output pattern (e.g. "results/{sample}.bam") into a
-- Lua pattern that matches concrete filenames.  Each {wildcard} (with or
-- without a constraint) becomes [^/]+ so that wildcards don't cross directory
-- boundaries, matching Snakemake's default behaviour.
local function snakemake_to_lua_pattern(pat)
  local result = "^"
  local pos = 1
  while pos <= #pat do
    local ws = pat:find("{", pos, true)
    if ws then
      local we = pat:find("}", ws + 1, true)
      if we then
        local literal = pat:sub(pos, ws - 1)
        result = result .. literal:gsub("([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1")
        result = result .. "([^/]+)"
        pos = we + 1
      else
        result = result .. pat:sub(pos):gsub("([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1")
        pos = #pat + 1
      end
    else
      result = result .. pat:sub(pos):gsub("([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1")
      break
    end
  end
  return result .. "$"
end

-- Returns absolute paths of every file under cwd whose basename starts with
-- "Snakemake" or "Snakefile".
local function find_snakemake_files()
  local cwd = vim.fn.getcwd()
  local found = {}
  local seen = {}
  for _, pat in ipairs({ "**/Snakemake*", "**/Snakefile*" }) do
    for _, f in ipairs(vim.fn.glob(cwd .. "/" .. pat, false, true)) do
      if vim.fn.isdirectory(f) == 0 and not seen[f] then
        seen[f] = true
        table.insert(found, f)
      end
    end
  end
  return found
end

-- Reads filepath from disk and returns its lines as a table.
local function read_file_lines(filepath)
  local lines = {}
  local fh = io.open(filepath, "r")
  if not fh then return lines end
  for line in fh:lines() do
    table.insert(lines, line)
  end
  fh:close()
  return lines
end

-- Parses all rule/checkpoint definitions in buf_lines and returns a list of
-- { name, lnum, outputs } tables.  Only static quoted string literals in
-- output: blocks are collected; expand() arguments, lambdas, and function
-- callbacks are picked up as their literal string contents where visible.
local function parse_rules(buf_lines)
  local rules = {}
  local current_rule = nil
  local in_output = false

  local function extract_quoted(line)
    local found = {}
    for s in line:gmatch('"([^"]*)"') do
      if s ~= "" then table.insert(found, s) end
    end
    for s in line:gmatch("'([^']*)'") do
      if s ~= "" then table.insert(found, s) end
    end
    return found
  end

  for lnum, line in ipairs(buf_lines) do
    local rule_name = line:match("^rule%s+(%S+)%s*:")
                   or line:match("^checkpoint%s+(%S+)%s*:")
    if rule_name then
      current_rule = { name = rule_name, lnum = lnum, outputs = {} }
      table.insert(rules, current_rule)
      in_output = false
    elseif line:match("^%S") then
      -- non-indented, non-rule line ends the current rule context
      current_rule = nil
      in_output = false
    elseif current_rule then
      local directive = line:match("^%s+(%a[%w_]*)%s*:")
      if directive then
        in_output = (directive == "output")
        if in_output then
          -- handle inline form: output: "file.txt"
          for _, s in ipairs(extract_quoted(line)) do
            table.insert(current_rule.outputs, s)
          end
        end
      elseif in_output then
        for _, s in ipairs(extract_quoted(line)) do
          table.insert(current_rule.outputs, s)
        end
      end
    end
  end

  return rules
end

-- ── rule index cache ──────────────────────────────────────────────────────────

-- Per-file rule cache: filepath -> list of { name, file, lnum, outputs }.
-- Populated on setup and updated per-file on BufWritePost.
local rule_cache = {}

-- (Re)index a single file into rule_cache.
local function index_file(filepath)
  local rules = parse_rules(read_file_lines(filepath))
  for _, rule in ipairs(rules) do
    rule.file = filepath
  end
  rule_cache[filepath] = rules
end

-- Populate rule_cache from scratch.  Called once in setup.
local function build_index()
  rule_cache = {}
  for _, f in ipairs(find_snakemake_files()) do
    index_file(f)
  end
end

-- Lazy init: build index on first use if setup was never called explicitly.
local function ensure_index()
  if next(rule_cache) == nil then
    build_index()
  end
end

-- ── public API ────────────────────────────────────────────────────────────────

M.setup = function(opts)
  build_index()
  vim.api.nvim_create_autocmd("BufWritePost", {
    pattern  = { "**/Snakemake*", "**/Snakefile*" },
    callback = function(ev) index_file(ev.file) end,
    desc     = "Update snakemake.nvim rule index on save",
  })
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

-- Jump to the rule whose output produces the file pattern under the cursor.
-- Reads from rule_cache; the cache is built on setup and updated per-file on
-- BufWritePost, so this never re-parses unless a file changed.
M.goto_producer = function()
  local target = get_string_under_cursor()
  if not target or target == "" then
    vim.notify("no file pattern found under cursor", vim.log.levels.WARN)
    return
  end

  ensure_index()

  for _, rules in pairs(rule_cache) do
    for _, rule in ipairs(rules) do
      for _, out_pat in ipairs(rule.outputs) do
        local matched = out_pat == target
          or (out_pat:find("{", 1, true) and target:match(snakemake_to_lua_pattern(out_pat)) ~= nil)
        if matched then
          if rule.file ~= vim.api.nvim_buf_get_name(0) then
            vim.cmd("edit " .. vim.fn.fnameescape(rule.file))
          end
          vim.api.nvim_win_set_cursor(0, { rule.lnum, 0 })
          vim.notify("rule: " .. rule.name .. "  (" .. vim.fn.fnamemodify(rule.file, ":~:.") .. ")", vim.log.levels.INFO)
          return
        end
      end
    end
  end

  vim.notify("no rule found producing: " .. target, vim.log.levels.WARN)
end

return M
