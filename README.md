# snakemake.nvim

A Neovim plugin with keymaps for working with Snakemake workflows: add or remove `--forcerun` rules in your `run.sh`, jump from any input file to the rule that produces it, and browse every rule in a quickfix picker.

## Features

### 1. Add rule to forcerun (`open_and_insert`)

Place your cursor anywhere inside a Snakemake rule definition, press the keymap, and the plugin will:

1. Scan upward from the cursor to find the enclosing `rule my_rule:` line and extract the rule name
2. Open `run.sh` in Neovim's current working directory
3. Insert or update the `--forcerun` argument in the file
4. Save the file

**First use:** a `--forcerun rule_name \` line is inserted directly after the `snakemake` command.

**Subsequent uses:** if a `--forcerun` line is already present, the new rule name is appended to it (space-separated) — so you can build up a list of rules to force-rerun without editing `run.sh` by hand.

### 2. Remove rule from forcerun (`remove_from_forcerun`)

Place your cursor anywhere inside a Snakemake rule, press the keymap, and the plugin will:

1. Scan upward from the cursor to find the enclosing rule name
2. Open `run.sh` and remove that rule from the `--forcerun` list
3. If the removed rule was the only one, drop the entire `--forcerun` line
4. Save

If the rule isn't currently in `--forcerun`, a notification is shown and the list is left unchanged.

### 3. Go to producer rule (`goto_producer`)

Place your cursor on a quoted input filename inside any rule's `input:` block and press the keymap. The plugin will:

1. Extract the file string under the cursor
2. Scan all `Snakemake*` and `Snakefile*` files under the current working directory, collecting every rule and checkpoint's `output:` patterns
3. Match the filename against each output pattern — including wildcard patterns like `results/{sample}.bam`
4. Open the file containing the matching rule (if different from the current buffer) and jump to it

Both exact matches (pattern equals pattern) and concrete-to-wildcard matches are supported. For example, with cursor on `"results/sampleA.bam"` in an input block, the plugin will jump to a rule with `output: "results/{sample}.bam"`. The rule name and source file are shown in a notification.

> **Note:** Only static quoted strings in `output:` blocks are indexed. `expand()` results, lambdas, and function callbacks are not evaluated.

### 4. List all rules (`list_rules`)

Press the keymap to populate Neovim's quickfix window with every rule and checkpoint across all `Snakemake*` / `Snakefile*` files under the current working directory, sorted by file and line number. Select an entry to jump straight to its definition.

## Requirements

- Neovim
- A `run.sh` file in Neovim's current working directory containing a `snakemake` command

## Installation

### lazy.nvim

```lua
{
  "samesense/snakemake.nvim",
  config = function()
    require("snakemake").setup()
    -- add current rule to --forcerun in run.sh
    vim.keymap.set("n", "<Leader>o", function()
      require("snakemake").open_and_insert()
    end)
    -- remove current rule from --forcerun in run.sh
    vim.keymap.set("n", "<Leader>O", function()
      require("snakemake").remove_from_forcerun()
    end)
    -- jump to the rule that produces the file under cursor
    vim.keymap.set("n", "<Leader>g", function()
      require("snakemake").goto_producer()
    end)
    -- list every rule in the quickfix window
    vim.keymap.set("n", "<Leader>r", function()
      require("snakemake").list_rules()
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

### Removing a rule from forcerun

1. Open a Snakefile in Neovim
2. Place your cursor anywhere inside the rule you want out of `--forcerun`
3. Press `<Leader>O`
4. `run.sh` is updated: the rule is dropped from the `--forcerun` list; if it was the only entry, the `--forcerun` line is removed entirely

### Listing all rules

1. Open any file in Neovim (a Snakefile isn't required)
2. Press `<Leader>r`
3. The quickfix window opens with every rule and checkpoint across all `Snakemake*` / `Snakefile*` files under the current working directory; use `:cnext` / `:cprev` or select an entry to jump to its definition

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
