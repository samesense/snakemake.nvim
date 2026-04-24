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
  end)

end)

-- ── snakemake_to_lua_pattern ──────────────────────────────────────────────────

describe("snakemake_to_lua_pattern", function()

  it("matches a literal path exactly", function()
    local pat = util.snakemake_to_lua_pattern("results/file.txt")
    assert.truthy("results/file.txt":match(pat))
    assert.falsy("results/file_txt":match(pat))   -- dot must not match _
    assert.falsy("results/other.txt":match(pat))
  end)

  it("escapes dots so they match literally", function()
    local pat = util.snakemake_to_lua_pattern("results/{sample}.bam")
    assert.falsy("results/sampleXbam":match(pat))
  end)

  it("matches a single wildcard", function()
    local pat = util.snakemake_to_lua_pattern("results/{sample}.bam")
    assert.truthy("results/sampleA.bam":match(pat))
    assert.truthy("results/my-sample_01.bam":match(pat))
  end)

  it("wildcard does not cross a directory separator", function()
    local pat = util.snakemake_to_lua_pattern("results/{sample}.bam")
    assert.falsy("results/subdir/sampleA.bam":match(pat))
  end)

  it("matches multiple wildcards", function()
    local pat = util.snakemake_to_lua_pattern("results/{dataset}/{sample}.bam")
    assert.truthy("results/data1/sampleA.bam":match(pat))
    assert.falsy("results/sampleA.bam":match(pat))
  end)

  it("handles a wildcard with an inline constraint", function()
    -- constraint text is ignored; [^/]+ is used regardless
    local pat = util.snakemake_to_lua_pattern("results/{sample,[A-Z]+}.bam")
    assert.truthy("results/SAMPLE.bam":match(pat))
    assert.truthy("results/sample123.bam":match(pat))  -- constraint not enforced
  end)

  it("matches a wildcard-only pattern", function()
    local pat = util.snakemake_to_lua_pattern("{sample}")
    assert.truthy("anything":match(pat))
    assert.falsy("dir/anything":match(pat))
  end)

  it("anchors both ends — no partial matches", function()
    local pat = util.snakemake_to_lua_pattern("results/{sample}.bam")
    assert.falsy("prefix/results/sampleA.bam":match(pat))
    assert.falsy("results/sampleA.bam/suffix":match(pat))
  end)

end)
