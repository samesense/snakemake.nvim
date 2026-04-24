local util = require("snakemake.util")

-- ── parse_rules ───────────────────────────────────────────────────────────────

describe("parse_rules", function()

  describe("rule detection", function()
    it("parses a rule name and line number", function()
      local rules = util.parse_rules({
        "rule foo:",
        "    output: 'out.txt'",
      })
      assert.equals(1, #rules)
      assert.equals("foo", rules[1].name)
      assert.equals(1, rules[1].lnum)
    end)

    it("parses a checkpoint as a rule", function()
      local rules = util.parse_rules({
        "checkpoint bar:",
        "    output: 'out.txt'",
      })
      assert.equals(1, #rules)
      assert.equals("bar", rules[1].name)
    end)

    it("parses multiple rules", function()
      local rules = util.parse_rules({
        "rule first:",
        "    output: 'a.txt'",
        "",
        "rule second:",
        "    output: 'b.txt'",
      })
      assert.equals(2, #rules)
      assert.equals("first",  rules[1].name)
      assert.equals("second", rules[2].name)
      assert.equals(4, rules[2].lnum)
    end)

    it("ignores rules with no output block", function()
      local rules = util.parse_rules({
        "rule no_output:",
        "    input: 'a.txt'",
        "    shell: 'echo hi'",
      })
      assert.equals(1, #rules)
      assert.same({}, rules[1].outputs)
    end)
  end)

  describe("output collection", function()
    it("collects an inline output (double quotes)", function()
      local rules = util.parse_rules({
        "rule foo:",
        '    output: "results/out.txt"',
      })
      assert.same({ "results/out.txt" }, rules[1].outputs)
    end)

    it("collects an inline output (single quotes)", function()
      local rules = util.parse_rules({
        "rule foo:",
        "    output: 'results/out.txt'",
      })
      assert.same({ "results/out.txt" }, rules[1].outputs)
    end)

    it("collects multiline outputs", function()
      local rules = util.parse_rules({
        "rule foo:",
        "    output:",
        "        'out1.txt',",
        "        'out2.txt'",
      })
      assert.same({ "out1.txt", "out2.txt" }, rules[1].outputs)
    end)

    it("strips wrappers like temp() and protected()", function()
      local rules = util.parse_rules({
        "rule foo:",
        "    output:",
        "        temp('tmp.txt'),",
        "        protected('final.txt')",
      })
      assert.same({ "tmp.txt", "final.txt" }, rules[1].outputs)
    end)

    it("collects named (keyword) outputs", function()
      local rules = util.parse_rules({
        "rule foo:",
        "    output:",
        "        bam='results/{sample}.bam',",
        "        bai='results/{sample}.bai'",
      })
      assert.same({ "results/{sample}.bam", "results/{sample}.bai" }, rules[1].outputs)
    end)

    it("stops collecting outputs when the next directive starts", function()
      local rules = util.parse_rules({
        "rule foo:",
        "    output: 'out.txt'",
        "    shell: 'touch out.txt'",
      })
      assert.same({ "out.txt" }, rules[1].outputs)
    end)

    it("stops collecting outputs at a non-indented line", function()
      local rules = util.parse_rules({
        "rule foo:",
        "    output:",
        "        'out.txt'",
        "x = 1",
      })
      assert.same({ "out.txt" }, rules[1].outputs)
    end)

    it("does not collect strings from input blocks", function()
      local rules = util.parse_rules({
        "rule foo:",
        "    input: 'in.txt'",
        "    output: 'out.txt'",
      })
      assert.same({ "out.txt" }, rules[1].outputs)
    end)

    it("ignores quoted strings inside trailing comments", function()
      local rules = util.parse_rules({
        "rule foo:",
        '    output: "out.txt",  # not "wrong.txt"',
      })
      assert.same({ "out.txt" }, rules[1].outputs)
    end)
  end)

end)

-- ── runtime behavior ───────────────────────────────────────────────────────────

describe("runtime behavior", function()
  local snakemake
  local original_cwd
  local notify
  local temp_root
  local swapfile

  local function write_file(path, lines)
    vim.fn.writefile(lines, path)
  end

  local function resolved(path)
    return vim.loop.fs_realpath(path) or vim.fn.resolve(path)
  end

  local function cursor_on(pattern)
    local line = vim.api.nvim_get_current_line()
    local start_col = assert(line:find(pattern, 1, true))
    vim.api.nvim_win_set_cursor(0, { vim.api.nvim_win_get_cursor(0)[1], start_col })
  end

  before_each(function()
    package.loaded["snakemake"] = nil
    package.loaded["snakemake.util"] = nil
    snakemake = require("snakemake")
    original_cwd = vim.fn.getcwd()
    notify = vim.notify
    swapfile = vim.o.swapfile
    vim.notify = function() end
    vim.o.swapfile = false
    temp_root = vim.fn.tempname()
    vim.fn.mkdir(temp_root, "p")
  end)

  after_each(function()
    vim.notify = notify
    vim.cmd.cd(original_cwd)
    vim.cmd("silent! %bwipeout!")
    vim.o.swapfile = swapfile
    vim.fn.delete(temp_root, "rf")
  end)

  it("rebuilds the producer index after changing cwd", function()
    local dir_one = temp_root .. "/one"
    local dir_two = temp_root .. "/two"
    vim.fn.mkdir(dir_one, "p")
    vim.fn.mkdir(dir_two, "p")

    write_file(dir_one .. "/Snakefile", {
      "rule one:",
      '    output: "shared.txt"',
      "",
      "rule consumer:",
      '    input: "shared.txt"',
    })
    write_file(dir_two .. "/Snakefile", {
      "rule two:",
      '    output: "shared.txt"',
      "",
      "rule consumer:",
      '    input: "shared.txt"',
    })

    vim.cmd.cd(dir_one)
    snakemake.setup()
    vim.cmd("edit " .. vim.fn.fnameescape(dir_one .. "/Snakefile"))
    vim.api.nvim_win_set_cursor(0, { 5, 0 })
    cursor_on("shared.txt")
    snakemake.goto_producer()
    assert.equals(resolved(dir_one .. "/Snakefile"), resolved(vim.api.nvim_buf_get_name(0)))
    assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))

    vim.cmd.cd(dir_two)
    vim.cmd("edit " .. vim.fn.fnameescape(dir_two .. "/Snakefile"))
    vim.api.nvim_win_set_cursor(0, { 5, 0 })
    cursor_on("shared.txt")
    snakemake.goto_producer()
    assert.equals(resolved(dir_two .. "/Snakefile"), resolved(vim.api.nvim_buf_get_name(0)))
    assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))
  end)

  it("indexes unsaved Snakefile buffers before jumping to a producer", function()
    local project_dir = temp_root .. "/project"
    vim.fn.mkdir(project_dir, "p")

    write_file(project_dir .. "/Snakefile", {
      "rule producer:",
      '    output: "old.txt"',
    })
    write_file(project_dir .. "/Snakefile.consumer", {
      "rule consumer:",
      '    input: "fresh.txt"',
    })

    vim.cmd.cd(project_dir)
    snakemake.setup()

    vim.cmd("edit " .. vim.fn.fnameescape(project_dir .. "/Snakefile"))
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {
      "rule producer:",
      '    output: "fresh.txt"',
    })

    vim.cmd("edit " .. vim.fn.fnameescape(project_dir .. "/Snakefile.consumer"))
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    cursor_on("fresh.txt")
    snakemake.goto_producer()

    assert.equals(resolved(project_dir .. "/Snakefile"), resolved(vim.api.nvim_buf_get_name(0)))
    assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))
  end)
end)

-- ── snakemake_to_lua_pattern ──────────────────────────────────────────────────

describe("snakemake_to_lua_pattern", function()

  it("matches a literal path exactly", function()
    local pat = util.snakemake_to_lua_pattern("results/file.txt")
    assert.truthy(("results/file.txt"):match(pat))
    assert.falsy(("results/file_txt"):match(pat))   -- dot must not match _
    assert.falsy(("results/other.txt"):match(pat))
  end)

  it("escapes dots so they match literally", function()
    local pat = util.snakemake_to_lua_pattern("results/{sample}.bam")
    assert.falsy(("results/sampleXbam"):match(pat))
  end)

  it("matches a single wildcard", function()
    local pat = util.snakemake_to_lua_pattern("results/{sample}.bam")
    assert.truthy(("results/sampleA.bam"):match(pat))
    assert.truthy(("results/my-sample_01.bam"):match(pat))
  end)

  it("wildcard does not cross a directory separator", function()
    local pat = util.snakemake_to_lua_pattern("results/{sample}.bam")
    assert.falsy(("results/subdir/sampleA.bam"):match(pat))
  end)

  it("matches multiple wildcards", function()
    local pat = util.snakemake_to_lua_pattern("results/{dataset}/{sample}.bam")
    assert.truthy(("results/data1/sampleA.bam"):match(pat))
    assert.falsy(("results/sampleA.bam"):match(pat))
  end)

  it("handles a wildcard with an inline constraint", function()
    -- constraint text is ignored; [^/]+ is used regardless
    local pat = util.snakemake_to_lua_pattern("results/{sample,[A-Z]+}.bam")
    assert.truthy(("results/SAMPLE.bam"):match(pat))
    assert.truthy(("results/sample123.bam"):match(pat))  -- constraint not enforced
  end)

  it("matches a wildcard-only pattern", function()
    local pat = util.snakemake_to_lua_pattern("{sample}")
    assert.truthy(("anything"):match(pat))
    assert.falsy(("dir/anything"):match(pat))
  end)

  it("anchors both ends — no partial matches", function()
    local pat = util.snakemake_to_lua_pattern("results/{sample}.bam")
    assert.falsy(("prefix/results/sampleA.bam"):match(pat))
    assert.falsy(("results/sampleA.bam/suffix"):match(pat))
  end)

  it("escapes Lua pattern magic characters in literal text", function()
    -- Exercises every character in the escape class: ( ) . % + - * ? [ ^ $
    local pat = util.snakemake_to_lua_pattern("out/(a+b-c*d?e[f]^g$h%i).{sample}.txt")
    assert.truthy(("out/(a+b-c*d?e[f]^g$h%i).SAMPLE.txt"):match(pat))
    -- If any magic char leaked through unescaped, this would still match.
    assert.falsy(("out/XaXbXcXdXeXfX^gX$hX%iX.SAMPLE.txt"):match(pat))
  end)

end)
