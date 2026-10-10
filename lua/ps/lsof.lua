local M = {}

local default_config = {
	lsof_cmd = "lsof -i -n -P",
	kill_cmd = "kill -9",
	regex_rule = [[\w\+\s\+\zs\d\+\ze]],
	keymaps = {
		refresh = "R",
		kill = "X",
		inspect = "K",
		filter = "f",
		quit = "q",
	},
	lsof_keymaps = {
		refresh = "R",
		kill = "X",
		inspect = "K",
		filter = "f",
		quit = "q",
	},
	inspector_keymaps = {
		kill = "X",
		refresh = "R",
		quit = "q",
		open_url = "gx",
	},
}

M.config = vim.deepcopy(default_config)
M.config.lsof_keymaps = M.config.keymaps

local state = {
	bufnr = nil,
	filter = nil,
	full_output = {},
}

local apply_keymaps

function M.setup(opts)
	local merged_opts = vim.deepcopy(opts or {})
	if merged_opts.lsof_buffer_keymaps and not merged_opts.lsof_keymaps then
		merged_opts.lsof_keymaps = merged_opts.lsof_buffer_keymaps
	end
	if merged_opts.lsof_keymaps and not merged_opts.keymaps then
		merged_opts.keymaps = merged_opts.lsof_keymaps
	elseif merged_opts.keymaps and not merged_opts.lsof_keymaps then
		merged_opts.lsof_keymaps = merged_opts.keymaps
	end

	M.config = vim.tbl_deep_extend("force", vim.deepcopy(default_config), merged_opts)
	M.config.lsof_keymaps = M.config.keymaps
	require("ps.lsof_syntax").setup()
	if state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) and apply_keymaps then
		apply_keymaps(state.bufnr)
	end
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

	local output = vim.fn.systemlist(M.config.lsof_cmd)
	if vim.v.shell_error ~= 0 then
		vim.notify("ERROR: lsof command failed", vim.log.levels.ERROR)
		return
	end

	state.full_output = output
	local display_lines = apply_filter(output)

	vim.bo[state.bufnr].modifiable = true
	vim.api.nvim_buf_set_lines(state.bufnr, 0, -1, false, display_lines)
	vim.bo[state.bufnr].modifiable = false

	local line_count = vim.api.nvim_buf_line_count(state.bufnr)
	if current_line <= line_count then
		vim.api.nvim_win_set_cursor(0, { current_line, 0 })
	end
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

	-- Check if process exists before attempting to kill
	local check_before = vim.fn.system("ps -p " .. pid .. " -o pid= 2>/dev/null")
	if vim.v.shell_error ~= 0 or check_before:match("^%s*$") then
		if not silent then
			vim.notify("Process " .. pid .. " does not exist", vim.log.levels.WARN)
		end
		return false
	end

	local cmd = M.config.kill_cmd .. " " .. pid
	vim.fn.system(cmd)

	if vim.v.shell_error ~= 0 then
		if not silent then
			vim.notify("ERROR: command execution failed: " .. cmd, vim.log.levels.ERROR)
		end
		return false
	end

	-- Wait a bit and verify the process is actually gone
	vim.defer_fn(function()
		local check_after = vim.fn.system("ps -p " .. pid .. " -o pid= 2>/dev/null")

		if vim.v.shell_error == 0 and not check_after:match("^%s*$") then
			if not silent then
				vim.notify("WARNING: Process " .. pid .. " may still be running", vim.log.levels.WARN)
			end
		else
			if not silent then
				vim.notify("Process " .. pid .. " has been killed.", vim.log.levels.INFO)
			end
		end
	end, 100)

	return true
end

local function kill_line()
	local line = vim.api.nvim_get_current_line()
	local pid = get_pid_from_line(line)
	kill_process(pid)
end

local function set_filter()
	vim.ui.input({
		prompt = "Filter lsof output (empty to clear): ",
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

local function inspect_process(target_pid)
	local pid = target_pid
	if not pid or pid == "" then
		local line = vim.api.nvim_get_current_line()
		pid = get_pid_from_line(line)
	end

	if not pid or pid == "" then
		vim.notify("No valid PID found", vim.log.levels.ERROR)
		return
	end

	-- Get various process information
	local ps_detail_cmd = "ps -p " .. pid .. " -o user,pid,%cpu,%mem,vsz,rss,tt,stat,start,time,command"
	local detail_output = vim.fn.systemlist(ps_detail_cmd)

	if vim.v.shell_error ~= 0 then
		vim.notify("ERROR: Failed to get process details for PID " .. pid, vim.log.levels.ERROR)
		return
	end

	-- Get real memory usage using top (as shown in Activity Monitor)
	local real_mem_cmd = "top -l 1 -pid " .. pid .. " -stats mem 2>/dev/null | tail -1"
	local real_mem_output = vim.fn.system(real_mem_cmd)
	local real_mem = vim.trim(real_mem_output)
	if real_mem == "" or vim.v.shell_error ~= 0 then
		real_mem = "N/A"
	end

	-- Get parent process info
	local parent_info = vim.fn.systemlist("ps -p " .. pid .. " -o ppid=,comm=")

	-- Get child processes (recursive)
	local all_child_pids = {}
	local function get_all_children(parent_pid)
		local direct_children = vim.fn.systemlist("pgrep -P " .. parent_pid .. " 2>/dev/null")
		for _, child in ipairs(direct_children) do
			if child ~= "" and tonumber(child) then
				table.insert(all_child_pids, child)
				get_all_children(child)
			end
		end
	end
	get_all_children(pid)

	-- Get network connections - filter by exact PID match using grep
	local network = {}
	if #all_child_pids > 0 then
		local pid_pattern = pid .. "|" .. table.concat(all_child_pids, "|")
		local network_cmd = "lsof -i -n -P 2>/dev/null | grep -E '^\\S+\\s+(" .. pid_pattern .. ")\\s'"
		network = vim.fn.systemlist(network_cmd)
	else
		local network_cmd = "lsof -i -n -P 2>/dev/null | grep -E '^\\S+\\s+" .. pid .. "\\s'"
		network = vim.fn.systemlist(network_cmd)
	end

	-- Get open files (limited to first 20)
	local open_files = vim.fn.systemlist("lsof -p " .. pid .. " 2>/dev/null | head -20")

	-- Get working directory
	local cwd_cmd = "lsof -a -p " .. pid .. " -d cwd -Fn 2>/dev/null | grep '^n' | cut -c2-"
	local cwd_output = vim.fn.systemlist(cwd_cmd)
	local cwd = cwd_output[1] or ""

	-- Use unique buffer name with PID
	local buf_name = "processmonitor://inspect/" .. pid

	-- Check if buffer already exists for this PID
	local existing_bufnr = vim.fn.bufnr(buf_name)
	local bufnr

	if existing_bufnr ~= -1 and vim.api.nvim_buf_is_valid(existing_bufnr) then
		-- Buffer exists, reuse it
		bufnr = existing_bufnr
	else
		-- Create a new buffer for inspection
		bufnr = vim.api.nvim_create_buf(true, false)
		vim.bo[bufnr].buftype = "nofile"
		vim.bo[bufnr].bufhidden = "hide"
		vim.bo[bufnr].swapfile = false
		vim.bo[bufnr].filetype = "psdetail"
		vim.api.nvim_buf_set_name(bufnr, buf_name)
	end

	-- Build the content
	local content = {
		"╔═══════════════════════════════════════════════════════════════╗",
		"║              PROCESS INSPECTOR - PID: " .. pid .. string.rep(" ", 18 - #pid) .. "║",
		"╚═══════════════════════════════════════════════════════════════╝",
		"",
	}

	-- Basic info
	table.insert(content, "📊 BASIC INFORMATION")
	table.insert(content, "═══════════════════")
	for _, detail_line in ipairs(detail_output) do
		table.insert(content, detail_line)
	end
	table.insert(content, "")
	table.insert(content, "💾 REAL MEMORY (as in Activity Monitor)")
	table.insert(content, "═══════════════════")
	table.insert(content, "Real Memory: " .. real_mem)
	table.insert(content, "")

	-- Working directory
	if cwd and cwd ~= "" then
		table.insert(content, "📁 WORKING DIRECTORY")
		table.insert(content, "═══════════════════")
		table.insert(content, cwd)
		table.insert(content, "")
	end

	-- Parent process
	if parent_info and #parent_info > 0 then
		table.insert(content, "⬆️  PARENT PROCESS")
		table.insert(content, "═══════════════════")
		for _, pinfo in ipairs(parent_info) do
			if pinfo ~= "" then
				table.insert(content, "PPID: " .. pinfo)
			end
		end
		table.insert(content, "")
	end

	-- Child processes
	if #all_child_pids > 0 then
		table.insert(content, "⬇️  CHILD PROCESSES (" .. #all_child_pids .. ")")
		table.insert(content, "═══════════════════")
		for _, child in ipairs(all_child_pids) do
			local child_info = vim.fn.systemlist("ps -p " .. child .. " -o pid,comm")
			for _, child_line in ipairs(child_info) do
				table.insert(content, child_line)
			end
		end
		table.insert(content, "")
	end

	-- Network connections
	if network and #network > 0 then
		table.insert(content, "🌐 NETWORK CONNECTIONS (this process + children)")
		table.insert(content, "═══════════════════")
		for i, net in ipairs(network) do
			if i <= 20 then
				table.insert(content, net)
			end
		end
		if #network > 20 then
			table.insert(content, "... and " .. (#network - 20) .. " more")
		end
		table.insert(content, "")
	else
		table.insert(content, "🌐 NETWORK CONNECTIONS")
		table.insert(content, "═══════════════════")
		table.insert(content, "(No network connections found)")
		table.insert(content, "")
	end

	-- Open files
	if open_files and #open_files > 1 then
		table.insert(content, "📄 OPEN FILES (first 20)")
		table.insert(content, "═══════════════════")
		for _, file in ipairs(open_files) do
			table.insert(content, file)
		end
		table.insert(content, "")
	end

	-- Actions
	local ikm = M.config.inspector_keymaps or {}
	local k_kill = (ikm.kill and ikm.kill ~= false and ikm.kill ~= "") and ikm.kill or nil
	local k_refresh = (ikm.refresh and ikm.refresh ~= false and ikm.refresh ~= "") and ikm.refresh or nil
	local k_quit = (ikm.quit and ikm.quit ~= false and ikm.quit ~= "") and ikm.quit or nil
	local k_open_url = (ikm.open_url and ikm.open_url ~= false and ikm.open_url ~= "") and ikm.open_url
		or ((ikm.browser and ikm.browser ~= false and ikm.browser ~= "") and ikm.browser or nil)

	table.insert(content, "⌨️  ACTIONS")
	table.insert(content, "═══════════════════")
	if k_kill then
		table.insert(content, string.format("  %-2s - Kill this process", k_kill))
	end
	if k_refresh then
		table.insert(content, string.format("  %-2s - Refresh inspector", k_refresh))
	end
	if k_quit then
		table.insert(content, string.format("  %-2s - Close this window", k_quit))
	end
	if k_open_url then
		table.insert(content, string.format("  %-2s - Open port in browser (when cursor on network connection)", k_open_url))
	end
	table.insert(content, "")

	-- Set the content
	vim.bo[bufnr].modifiable = true
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)
	vim.bo[bufnr].modifiable = false

	-- Open the buffer in a new split
	vim.cmd("belowright vsplit")
	vim.api.nvim_win_set_buf(0, bufnr)
	vim.wo.wrap = false

	-- Set up keymaps for the inspection buffer
	local opts = { noremap = true, silent = true, buffer = bufnr }
	if k_kill then
		vim.keymap.set("n", k_kill, function()
			if kill_process(pid) then
				vim.notify("Process " .. pid .. " killed. Closing inspector.", vim.log.levels.INFO)
				vim.defer_fn(function()
					if vim.api.nvim_buf_is_valid(bufnr) then
						vim.cmd("close")
					end
				end, 500)
			end
		end, opts)
	end
	if k_refresh then
		vim.keymap.set("n", k_refresh, function()
			vim.cmd("close")
			inspect_process(pid)
		end, opts)
	end
	if k_quit then
		vim.keymap.set("n", k_quit, "<cmd>q!<CR>", opts)
	end
	if k_open_url then
		vim.keymap.set("n", k_open_url, function()
			local line = vim.api.nvim_get_current_line()
			-- Match patterns like [::1]:4873, localhost:8080, 127.0.0.1:3000, *:8080, etc.
			local port = line:match("]:%d+") or line:match(":%d+")
			if port then
				port = port:match("%d+")
				local url = "http://localhost:" .. port
				vim.notify("Opening " .. url .. " in browser...", vim.log.levels.INFO)
				vim.fn.jobstart({ "open", url }, { detach = true })
			else
				vim.notify("No port found on current line", vim.log.levels.WARN)
			end
		end, opts)
	end
end

apply_keymaps = function(bufnr)
	local opts = { noremap = true, silent = true, buffer = bufnr }
	local km = M.config.keymaps or {}

	local map = function(mode, lhs, rhs)
		if lhs and lhs ~= false and lhs ~= "" then
			vim.keymap.set(mode, lhs, rhs, opts)
		end
	end

	map("n", km.refresh, refresh)
	map("n", km.kill, kill_line)
	map("v", km.kill_visual or km.kill, function()
		local start_line = vim.fn.line("v")
		local end_line = vim.fn.line(".")
		if start_line > end_line then
			start_line, end_line = end_line, start_line
		end
		local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
		vim.api.nvim_feedkeys(esc, "n", false)

		local lines = vim.api.nvim_buf_get_lines(state.bufnr, start_line - 1, end_line, false)
		local killed_pids = {}
		for _, line in ipairs(lines) do
			local pid = get_pid_from_line(line)
			if pid and kill_process(pid, true) then
				table.insert(killed_pids, pid)
			end
		end
		if #killed_pids > 0 then
			vim.notify(
				"Killed " .. #killed_pids .. " process(es): " .. table.concat(killed_pids, ", "),
				vim.log.levels.INFO
			)
		else
			vim.notify("No processes were killed", vim.log.levels.WARN)
		end
	end)
	map("n", km.inspect, inspect_process)
	map("n", km.quit, "<cmd>q!<CR>")
	map("n", km.filter, set_filter)
end

local function setup_buffer()
	local bufnr = vim.api.nvim_create_buf(true, false)
	state.bufnr = bufnr

	vim.bo[bufnr].buftype = "nofile"
	vim.bo[bufnr].bufhidden = "hide"
	vim.bo[bufnr].swapfile = false
	vim.api.nvim_buf_set_name(bufnr, "processmonitor://lsof")
	vim.bo[bufnr].filetype = "lsof"

	-- Apply syntax highlighting immediately
	vim.api.nvim_buf_call(bufnr, function()
		require("ps.lsof_syntax").apply()
	end)

	apply_keymaps(bufnr)

	-- Ensure buffer has content when displayed
	vim.api.nvim_create_autocmd("BufEnter", {
		buffer = bufnr,
		callback = function()
			-- If buffer is empty, refresh it
			local line_count = vim.api.nvim_buf_line_count(bufnr)
			if line_count <= 1 then
				local first_line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or ""
				if first_line == "" then
					refresh()
				end
			end
		end,
	})

	return bufnr
end

function M.open()
	-- Check if LSOF buffer already exists
	local existing_bufnr = vim.fn.bufnr("processmonitor://lsof")

	if existing_bufnr ~= -1 and vim.api.nvim_buf_is_valid(existing_bufnr) then
		-- Buffer exists, check if it's visible in any window
		for _, win in ipairs(vim.api.nvim_list_wins()) do
			if vim.api.nvim_win_get_buf(win) == existing_bufnr then
				-- Buffer is visible, switch focus to that window
				vim.api.nvim_set_current_win(win)
				return
			end
		end

		-- Buffer exists but not visible, show it in a new window
		vim.cmd("split")
		vim.api.nvim_win_set_buf(0, existing_bufnr)
		vim.wo.wrap = false
		state.bufnr = existing_bufnr
		-- Don't refresh here - buffer already has content
		return
	end

	-- Buffer doesn't exist, create a new one
	local bufnr = setup_buffer()
	vim.cmd("split")
	vim.api.nvim_win_set_buf(0, bufnr)
	vim.wo.wrap = false
	state.filter = nil
	refresh()
end

function M.refresh()
	refresh()
end

function M.set_filter()
	set_filter()
end

function M.kill_line()
	kill_line()
end

function M.inspect_process(target_pid)
	inspect_process(target_pid)
end

return M
