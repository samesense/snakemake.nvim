-- print("loaded trash plugin")
-- require("trash")
--
local util = require("snakemake.util")
local parse_rules             = util.parse_rules
local snakemake_to_lua_pattern = util.snakemake_to_lua_pattern

local M = {}
M.example = function()
  -- print("executed trash plugin")
end

local augroup = vim.api.nvim_create_augroup("snakemake.nvim", { clear = true })

-- ── helpers ───────────────────────────────────────────────────────────────────

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

-- ── rule index cache ──────────────────────────────────────────────────────────

-- Per-file rule cache: filepath -> list of { name, file, lnum, outputs }.
-- Populated on setup and updated per-file on BufWritePost.
local rule_cache = {}
local indexed_cwd = nil

local function is_snakemake_path(filepath)
  local basename = vim.fn.fnamemodify(filepath, ":t")
  return basename:match("^Snakemake") ~= nil or basename:match("^Snakefile") ~= nil
end

local function in_current_cwd(filepath)
  local cwd = vim.fn.getcwd()
  return filepath == cwd or filepath:sub(1, #cwd + 1) == cwd .. "/"
end

-- (Re)index a single file into rule_cache.
local function index_lines(filepath, lines)
  local rules = parse_rules(lines)
  for _, rule in ipairs(rules) do
    rule.file = filepath
  end
  rule_cache[filepath] = rules
end

local function index_file(filepath)
  index_lines(filepath, read_file_lines(filepath))
end

-- Populate rule_cache from scratch.  Called once in setup.
local function build_index()
  rule_cache = {}
  indexed_cwd = vim.fn.getcwd()
  for _, f in ipairs(find_snakemake_files()) do
    index_file(f)
  end
end

local function sync_open_buffers()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local filepath = vim.api.nvim_buf_get_name(bufnr)
      if filepath ~= "" and is_snakemake_path(filepath) and in_current_cwd(filepath) then
        index_lines(filepath, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
      end
    end
  end
end

-- Lazy init: build index on first use if setup was never called explicitly.
local function ensure_index()
  if indexed_cwd ~= vim.fn.getcwd() or next(rule_cache) == nil then
    build_index()
  end
  sync_open_buffers()
end

-- ── public API ────────────────────────────────────────────────────────────────

M.setup = function(opts)
  build_index()
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = augroup,
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

-- Populate the quickfix list with every rule across all indexed Snakemake
-- files and open the quickfix window.  Each entry jumps directly to the
-- rule definition line when selected.
M.list_rules = function()
  ensure_index()

  local items = {}
  for _, rules in pairs(rule_cache) do
    for _, rule in ipairs(rules) do
      table.insert(items, {
        filename = rule.file,
        lnum     = rule.lnum,
        col      = 1,
        text     = rule.name,
      })
    end
  end

  if #items == 0 then
    vim.notify("no rules found", vim.log.levels.WARN)
    return
  end

  table.sort(items, function(a, b)
    if a.filename ~= b.filename then return a.filename < b.filename end
    return a.lnum < b.lnum
  end)

  vim.fn.setqflist({}, "r", { title = "Snakemake rules", items = items })
  vim.cmd("copen")
end

return M
