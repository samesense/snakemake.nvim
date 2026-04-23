# snakemake.nvim

A Neovim plugin that adds a keymap to quickly insert a `--forcerun` argument for the current Snakemake rule into your `run.sh` file.

## What it does

Place your cursor on a Snakemake rule definition (e.g. `rule my_rule:`), press the keymap, and the plugin will:

1. Extract the rule name from the current line
2. Open `run.sh` in Neovim's current working directory
3. Insert a `--forcerun my_rule \` line into the file
4. Save the file

**First use:** the forcerun line is inserted directly after the `snakemake` command.

**Subsequent uses:** if `--forcerun` lines are already present, the new rule is appended after the last one — so you can build up a list of rules to force-rerun without editing `run.sh` by hand.

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
2. Move your cursor to a rule definition line, e.g.:
   ```
   rule my_rule:
   ```
3. Press `<Leader>o`
4. Your `run.sh` will be updated — the rule is inserted after the `snakemake` line on the first use, or appended after the last existing `--forcerun` line on subsequent uses

For example, after pressing `<Leader>o` three times on different rules:

```sh
snakemake \
  --forcerun rule_a \
  --forcerun rule_b \
  --forcerun rule_c \
  --cores 4
```

> **Note:** An error is raised if `run.sh` does not contain a `snakemake` line and no `--forcerun` lines are present.
