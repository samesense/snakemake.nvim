# snakemake.nvim

A Neovim plugin that adds a keymap to quickly insert a `--forcerun` argument for the current Snakemake rule into your `run.sh` file.

## What it does

Place your cursor on a Snakemake rule definition (e.g. `rule my_rule:`), press the keymap, and the plugin will:

1. Extract the rule name from the current line
2. Open `run.sh` in the current directory
3. Insert ` --forcerun my_rule \` on the line after the `snakemake` command
4. Save the file

## Requirements

- Neovim
- A `run.sh` file in your working directory containing a `snakemake` command

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
4. Your `run.sh` will be updated with the forcerun argument inserted after the `snakemake` line

> **Note:** An error is raised if `run.sh` does not contain a `snakemake` line.
