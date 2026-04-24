local M = {}

-- Parses all rule/checkpoint definitions in buf_lines and returns a list of
-- { name, lnum, outputs } tables.  Only static quoted string literals in
-- output: blocks are collected.
function M.parse_rules(buf_lines)
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
      current_rule = nil
      in_output = false
    elseif current_rule then
      local directive = line:match("^%s+(%a[%w_]*)%s*:")
      if directive then
        in_output = (directive == "output")
        if in_output then
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

-- Converts a Snakemake output pattern (e.g. "results/{sample}.bam") into a
-- Lua pattern that matches concrete filenames.  Each {wildcard} becomes
-- [^/]+ so wildcards don't cross directory boundaries.
function M.snakemake_to_lua_pattern(pat)
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

return M
