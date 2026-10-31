-- Shared helpers for psdetail (process inspector) buffers.
local M = {}

function M.parent_pid_from_line(line)
	local pid = line and line:match("^PPID:%s+(%d+)")
	if not pid or tonumber(pid) == 0 then
		return nil
	end
	return pid
end

-- Return every descendant PID of `pid` using a single `ps` call.
function M.descendant_pids(pid)
	local children_by_parent = {}
	for _, line in ipairs(vim.fn.systemlist("ps -ax -o pid=,ppid=")) do
		local child, parent = line:match("^%s*(%d+)%s+(%d+)")
		if child and parent then
			children_by_parent[parent] = children_by_parent[parent] or {}
			table.insert(children_by_parent[parent], child)
		end
	end

	local result = {}
	local queue = { tostring(pid) }
	local i = 1
	while i <= #queue do
		local parent = queue[i]
		i = i + 1
		for _, child in ipairs(children_by_parent[parent] or {}) do
			table.insert(result, child)
			table.insert(queue, child)
		end
	end
	return result
end

-- Map parent-process navigation keys on a psdetail buffer.
-- `open` is called as open(ppid, mode), where mode is one of:
--   "vsplit"  - open in a vertical split
--   "split"   - open in a horizontal split
--   "replace" - open in the current window
function M.attach_parent_keys(bufnr, open)
	local opts = { noremap = true, silent = true, buffer = bufnr }

	local function open_link(mode)
		return function()
			local ppid = M.parent_pid_from_line(vim.api.nvim_get_current_line())
			if not ppid then
				vim.notify("Cursor is not on the parent process line", vim.log.levels.WARN)
				return
			end
			open(ppid, mode)
		end
	end

	vim.keymap.set("n", "<C-v>", open_link("vsplit"), opts)
	vim.keymap.set("n", "<C-s>", open_link("split"), opts)
	vim.keymap.set("n", "<CR>", function()
		local ppid = M.parent_pid_from_line(vim.api.nvim_get_current_line())
		if not ppid then
			-- Keep the default <CR> behavior outside the PPID line.
			vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "n", false)
			return
		end
		open(ppid, "replace")
	end, opts)
end

return M
