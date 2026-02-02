-- Example configuration for ps.nvim
-- Add this to your init.lua or plugins configuration

return {
  "jugarpeupv/ps.nvim",
  config = function()
    require("ps").setup({
      -- Optional: customize the ps command
      -- ps_cmd = "ps aux",
      
      -- Optional: customize the kill command
      -- kill_cmd = "kill -9",  -- Use SIGKILL (force kill)
      -- kill_cmd = "kill -15", -- Use SIGTERM (graceful termination)
      
      -- Optional: customize PID extraction regex
      -- regex_rule = [[\w\+\s\+\zs\d\+\ze]],
    })

    -- Optional: Create a keybinding to open PS
    vim.keymap.set("n", "<leader>ps", "<cmd>PS<cr>", { desc = "Open process viewer" })
  end,
}
