# snakemake.nvim
Trying to make an nvim plugin

# notes

```
-- local plugins need to be explicitly configured with dir
  { dir = "~/projects/secret.nvim" },
```

* look for lua folder, loads when require it
* look in plugin folder for stuff that runs on load
* also special for require: nvim-plugins/trash.nvim/lua/trash/init.lua 

```
# loads into cache
:lua require"trash"
```
