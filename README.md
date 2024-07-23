# snakemake.nvim
Add keymap update run.sh to force run a snakemake rule.

# install w/ lazyvim

```
{
  "samesense/snakemake.nvim",
config = function () require("snakemake") vim.keymap.set('n', '<Leader>o', function() require("snakemake").open_and_insert() end ) end},
```
