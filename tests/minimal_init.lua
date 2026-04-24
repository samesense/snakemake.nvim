-- Minimal Neovim config for running tests with plenary.nvim.
-- Downloads plenary to /tmp if not already present.
local plenary_path = "/tmp/plenary.nvim"

if vim.fn.empty(vim.fn.glob(plenary_path)) > 0 then
  vim.fn.system({
    "git", "clone", "--depth=1",
    "https://github.com/nvim-lua/plenary.nvim",
    plenary_path,
  })
end

vim.opt.rtp:prepend(plenary_path)   -- plenary
vim.opt.rtp:prepend(".")            -- this plugin

vim.cmd("runtime plugin/plenary.vim")
