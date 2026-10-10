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

      -- Optional: customize default sorting ("mem", "cpu", or nil)
      -- default_sort = "mem",

      -- Optional: customize keymaps for the ps buffer
      -- ps_buffer_keymaps = {
      --   refresh = "R",
      --   kill = "X",
      --   inspect = "K",
      --   open_proc = "p",
      --   quit = "q",
      --   filter = "F",
      --   pin = "P",
      --   port = "O",
      --   sort_cpu = "gC",
      --   sort_mem = "gm",
      --   auto_reload = "gl",
      --   help = "g?",
      -- },

      -- Optional: customize keymaps for the lsof buffer
      -- lsof_keymaps = {
      --   refresh = "R",
      --   kill = "X",
      --   inspect = "K",
      --   filter = "f",
      --   quit = "q",
      -- },

      -- Optional: customize keymaps for the process inspector buffer
      -- inspector_keymaps = {
      --   kill = "X",
      --   refresh = "R",
      --   quit = "q",
      --   open_url = "gx",
      -- },
    })

    -- Optional: Create a keybinding to open PS
    vim.keymap.set("n", "<leader>ps", "<cmd>PS<cr>", { desc = "Open process viewer" })
  end,
}
