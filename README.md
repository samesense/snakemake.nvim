# snakemake.nvim

A Neovim plugin with keymaps for working with Snakemake workflows: quickly add `--forcerun` arguments to your `run.sh`, and jump from any input file to the rule that produces it.

## Features

### 1. Add rule to forcerun (`open_and_insert`)

Place your cursor anywhere inside a Snakemake rule definition, press the keymap, and the plugin will:

1. Scan upward from the cursor to find the enclosing `rule my_rule:` line and extract the rule name
2. Open `run.sh` in Neovim's current working directory
3. Insert or update the `--forcerun` argument in the file
4. Save the file

**First use:** a `--forcerun rule_name \` line is inserted directly after the `snakemake` command.

**Subsequent uses:** if a `--forcerun` line is already present, the new rule name is appended to it (space-separated) — so you can build up a list of rules to force-rerun without editing `run.sh` by hand.

### 2. Go to producer rule (`goto_producer`)

Place your cursor on a quoted input filename inside any rule's `input:` block and press the keymap. The plugin will:

1. Extract the file string under the cursor
2. Scan the entire Snakefile for rules and checkpoints, collecting their `output:` patterns
3. Match the filename against each output pattern — including wildcard patterns like `results/{sample}.bam`
4. Jump the cursor to the matching rule

Both exact matches (pattern equals pattern) and concrete-to-wildcard matches are supported. For example, with cursor on `"results/sampleA.bam"` in an input block, the plugin will jump to a rule with `output: "results/{sample}.bam"`.

> **Note:** Only static quoted strings in `output:` blocks are indexed. `expand()` results, lambdas, and function callbacks are not evaluated.

## Requirements

- Neovim
- A `run.sh` file in Neovim's current working directory containing a `snakemake` command

## Installation

### lazy.nvim

```lua
{
  "samesense/snakemake.nvim",
  config = function()
    require("snakemake")
    -- add current rule to --forcerun in run.sh
    vim.keymap.set("n", "<Leader>o", function()
      require("snakemake").open_and_insert()
    end)
    -- jump to the rule that produces the file under cursor
    vim.keymap.set("n", "<Leader>g", function()
      require("snakemake").goto_producer()
    end)
  end,
},
```

## Usage

### Adding a rule to forcerun

1. Open a Snakefile in Neovim
2. Place your cursor anywhere inside a rule — on the `rule` line itself or any line within the rule body:
   ```
   rule my_rule:
       input: "data.txt"   # cursor can be here too
       output: "result.txt"
   ```
3. Press `<Leader>o`
4. Your `run.sh` will be updated — the rule is inserted after the `snakemake` line on the first use, or appended to the existing `--forcerun` line on subsequent uses

For example, after pressing `<Leader>o` three times on different rules:

```sh
snakemake \
  --forcerun rule_a rule_b rule_c \
  --cores 4
```

> **Note:** An error is raised if no `rule` definition is found above the cursor, or if `run.sh` does not contain a `snakemake` line and no `--forcerun` lines are present.

### Jumping to a producer rule

1. Open a Snakefile in Neovim
2. Place your cursor on a quoted filename inside an `input:` block:
   ```
   rule final:
       input: "results/sampleA.bam"   # cursor here
   ```
3. Press `<Leader>g`
4. The cursor jumps to the rule whose `output:` produces that file

Wildcard patterns are matched automatically — a concrete filename like `results/sampleA.bam` will match an output pattern `results/{sample}.bam`. The rule name is shown in a notification on successful navigation.
