local M = {}

M.config = {
  ps_cmd = "ps aux",
  kill_cmd = "kill -9",
  regex_rule = [[\w\+\s\+\zs\d\+\ze]],
}

local state = {
  bufnr = nil,
  filter = nil,
  full_output = {},
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  require("ps.syntax").setup()
end

local function get_pid_from_line(line)
  local match = vim.fn.matchstr(line, M.config.regex_rule)
  return match ~= "" and match or nil
end

local function kill_process(pid, silent)
  if not pid or pid == "" then
    if not silent then
      vim.notify("No valid PID found", vim.log.levels.ERROR)
    end
    return false
  end

  local cmd = M.config.kill_cmd .. " " .. pid
  local result = vim.fn.system(cmd)
  
  if vim.v.shell_error ~= 0 then
    if not silent then
      vim.notify("ERROR: command execution failed: " .. cmd, vim.log.levels.ERROR)
    end
    return false
  end

  if not silent then
    vim.notify("Process " .. pid .. " has been killed.", vim.log.levels.INFO)
  end
  return true
end

local function apply_filter(lines)
  if not state.filter or state.filter == "" then
    return lines
  end

  local filtered = {}
  for i, line in ipairs(lines) do
    if i == 1 or line:lower():find(state.filter:lower(), 1, true) then
      table.insert(filtered, line)
    end
  end
  return filtered
end

local function refresh()
  if not state.bufnr or not vim.api.nvim_buf_is_valid(state.bufnr) then
    return
  end

  local current_line = vim.api.nvim_win_get_cursor(0)[1]
  
  local output = vim.fn.systemlist(M.config.ps_cmd)
  if vim.v.shell_error ~= 0 then
    vim.notify("ERROR: ps command failed", vim.log.levels.ERROR)
    return
  end

  state.full_output = output
  local display_lines = apply_filter(output)

  vim.bo[state.bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(state.bufnr, 0, -1, false, display_lines)
  vim.bo[state.bufnr].modifiable = false

  local line_count = vim.api.nvim_buf_line_count(state.bufnr)
  if current_line <= line_count then
    vim.api.nvim_win_set_cursor(0, {current_line, 0})
  end
end

local function kill_line()
  local line = vim.api.nvim_get_current_line()
  local pid = get_pid_from_line(line)
  
  kill_process(pid)
end

local function kill_selected_lines()
  local start_line = vim.fn.line("'<")
  local end_line = vim.fn.line("'>")
  
  local lines = vim.api.nvim_buf_get_lines(state.bufnr, start_line - 1, end_line, false)
  local killed_pids = {}
  
  for _, line in ipairs(lines) do
    local pid = get_pid_from_line(line)
    if pid and kill_process(pid, true) then
      table.insert(killed_pids, pid)
    end
  end

  if #killed_pids > 0 then
    vim.notify("Killed " .. #killed_pids .. " process(es): " .. table.concat(killed_pids, ", "), vim.log.levels.INFO)
  else
    vim.notify("No processes were killed", vim.log.levels.WARN)
  end
end

local function kill_word()
  local word = vim.fn.expand("<cword>")
  kill_process(word)
end

local function open_proc_line()
  local line = vim.api.nvim_get_current_line()
  local pid = get_pid_from_line(line)
  
  if not pid or pid == "" then
    vim.notify("No valid PID found", vim.log.levels.ERROR)
    return
  end

  local proc_dir = "/proc/" .. pid
  if vim.fn.isdirectory(proc_dir) == 1 then
    vim.cmd("belowright vnew " .. proc_dir)
  else
    vim.notify("ERROR: " .. proc_dir .. " is not found", vim.log.levels.ERROR)
  end
end

local function set_filter()
  vim.ui.input({
    prompt = "Filter processes (empty to clear): ",
    default = state.filter or "",
  }, function(input)
    if input == nil then
      return
    end
    
    state.filter = input ~= "" and input or nil
    refresh()
    
    if state.filter then
      vim.notify("Filter applied: " .. state.filter, vim.log.levels.INFO)
    else
      vim.notify("Filter cleared", vim.log.levels.INFO)
    end
  end)
end

local function setup_buffer()
  local bufnr = vim.api.nvim_create_buf(false, true)
  state.bufnr = bufnr

  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].swapfile = false
  vim.api.nvim_buf_set_name(bufnr, "PS")
  vim.bo[bufnr].filetype = "ps"
  
  -- Apply syntax highlighting immediately
  vim.api.nvim_buf_call(bufnr, function()
    require("ps.syntax").apply()
  end)

  local opts = { noremap = true, silent = true, buffer = bufnr }

  vim.keymap.set("n", "r", refresh, opts)
  vim.keymap.set("n", "<C-k>", kill_line, opts)
  vim.keymap.set("v", "<C-k>", function()
    -- Get visual selection before exiting
    local start_line = vim.fn.line("v")
    local end_line = vim.fn.line(".")
    
    -- Ensure start is before end
    if start_line > end_line then
      start_line, end_line = end_line, start_line
    end
    
    -- Exit visual mode first
    local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
    vim.api.nvim_feedkeys(esc, "n", false)
    
    -- Kill the processes
    local lines = vim.api.nvim_buf_get_lines(state.bufnr, start_line - 1, end_line, false)
    local killed_pids = {}
    
    for _, line in ipairs(lines) do
      local pid = get_pid_from_line(line)
      if pid and kill_process(pid, true) then
        table.insert(killed_pids, pid)
      end
    end

    if #killed_pids > 0 then
      vim.notify("Killed " .. #killed_pids .. " process(es): " .. table.concat(killed_pids, ", "), vim.log.levels.INFO)
    else
      vim.notify("No processes were killed", vim.log.levels.WARN)
    end
  end, opts)
  vim.keymap.set("n", "K", kill_word, opts)
  vim.keymap.set("n", "p", open_proc_line, opts)
  vim.keymap.set("n", "q", "<cmd>q!<CR>", opts)
  vim.keymap.set("n", "f", set_filter, opts)

  return bufnr
end

function M.open()
  local bufnr = setup_buffer()
  vim.cmd("new")
  vim.api.nvim_win_set_buf(0, bufnr)
  vim.wo.wrap = false
  state.filter = nil
  refresh()
end

function M.open_this_buffer()
  state.bufnr = vim.api.nvim_get_current_buf()
  setup_buffer()
  vim.wo.wrap = false
  state.filter = nil
  refresh()
end

function M.refresh()
  refresh()
end

function M.kill_line()
  kill_line()
end

function M.kill_selected_lines()
  kill_selected_lines()
end

function M.kill_word()
  kill_word()
end

function M.open_proc_line()
  open_proc_line()
end

function M.set_filter()
  set_filter()
end

return M
