# snakemake.nvim

A Neovim plugin that adds a keymap to quickly insert a `--forcerun` argument for the current Snakemake rule into your `run.sh` file.

## What it does

Place your cursor anywhere inside a Snakemake rule definition, press the keymap, and the plugin will:

1. Scan upward from the cursor to find the enclosing `rule my_rule:` line and extract the rule name
2. Open `run.sh` in Neovim's current working directory
3. Insert or update the `--forcerun` argument in the file
4. Save the file

**First use:** a `--forcerun rule_name \` line is inserted directly after the `snakemake` command.

**Subsequent uses:** if a `--forcerun` line is already present, the new rule name is appended to it (space-separated) — so you can build up a list of rules to force-rerun without editing `run.sh` by hand.

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
    vim.keymap.set("n", "<Leader>o", function()
      require("snakemake").open_and_insert()
    end)
  end,
},
```

## Usage

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
