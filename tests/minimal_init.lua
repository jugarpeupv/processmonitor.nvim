-- Minimal init for testing
vim.cmd([[set runtimepath=$VIMRUNTIME]])
vim.cmd([[set packpath=/tmp/nvim/site]])

local package_root = "/tmp/nvim/site/pack"
local install_path = package_root .. "/packer/start/plenary.nvim"

local function load_plugins()
  require("packer").startup(function(use)
    use("nvim-lua/plenary.nvim")
    use({ "/Users/jgarcia/projects/ps.nvim" })
  end)
end

_G.load_config = function()
  vim.opt.termguicolors = true
  vim.opt.swapfile = false
  
  load_plugins()
end

if vim.fn.isdirectory(install_path) == 0 then
  vim.fn.system({ "git", "clone", "https://github.com/nvim-lua/plenary.nvim", install_path })
end

vim.cmd([[packadd packer.nvim]])
require("packer").startup(function(use)
  use("nvim-lua/plenary.nvim")
end)

-- Add the plugin to runtimepath
vim.opt.runtimepath:append("/Users/jgarcia/projects/ps.nvim")
