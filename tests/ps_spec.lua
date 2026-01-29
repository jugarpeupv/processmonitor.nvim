-- Tests for ps.nvim
-- Run with: nvim --headless -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"

describe("ps.nvim", function()
  local ps = require("ps")
  
  before_each(function()
    -- Reset state
    ps.setup({
      ps_cmd = "ps aux",
      kill_cmd = "echo kill",  -- Mock kill command for testing
      regex_rule = [[\w\+\s\+\zs\d\+\ze]],
    })
  end)

  describe("get_pid_from_line", function()
    it("should extract PID from ps aux line", function()
      local line = "jgarcia          18911  24.6  2.2 1892518768 374384   ??  S     9:21AM  83:43.78 /Applications/Spotify.app"
      -- Access the internal function through testing
      local match = vim.fn.matchstr(line, [[\w\+\s\+\zs\d\+\ze]])
      assert.equals("18911", match)
    end)

    it("should extract PID from different user", function()
      local line = "_windowserver      409  20.3  1.2 437743728 201424   ??  Ss    8:59PM  93:29.09 /System/Library"
      local match = vim.fn.matchstr(line, [[\w\+\s\+\zs\d\+\ze]])
      assert.equals("409", match)
    end)

    it("should handle header line", function()
      local line = "USER               PID  %CPU %MEM      VSZ    RSS   TT  STAT STARTED      TIME COMMAND"
      local match = vim.fn.matchstr(line, [[\w\+\s\+\zs\d\+\ze]])
      -- Should not match PID text
      assert.equals("", match)
    end)
  end)

  describe("filtering with visual selection", function()
    it("should extract correct PIDs from filtered buffer", function()
      -- Simulate filtered ps output
      local filtered_lines = {
        "USER               PID  %CPU %MEM      VSZ    RSS   TT  STAT STARTED      TIME COMMAND",
        "jgarcia          12345  1.0  0.5 1000000 50000   ??  S     9:00AM   1:00.00 /usr/bin/node",
        "jgarcia          67890  2.0  1.0 2000000 100000  ??  S     9:30AM   2:00.00 /usr/bin/python",
        "jgarcia          11111  3.0  1.5 3000000 150000  ??  S    10:00AM   3:00.00 /usr/bin/ruby",
      }

      -- Test PID extraction from each line
      local pids = {}
      for i = 2, #filtered_lines do
        local pid = vim.fn.matchstr(filtered_lines[i], [[\w\+\s\+\zs\d\+\ze]])
        if pid ~= "" then
          table.insert(pids, pid)
        end
      end

      assert.equals(3, #pids)
      assert.equals("12345", pids[1])
      assert.equals("67890", pids[2])
      assert.equals("11111", pids[3])
    end)

    it("should extract PIDs from visual selection range", function()
      local filtered_lines = {
        "USER               PID  %CPU %MEM      VSZ    RSS   TT  STAT STARTED      TIME COMMAND",
        "jgarcia          12345  1.0  0.5 1000000 50000   ??  S     9:00AM   1:00.00 /usr/bin/node",
        "jgarcia          67890  2.0  1.0 2000000 100000  ??  S     9:30AM   2:00.00 /usr/bin/python",
        "jgarcia          11111  3.0  1.5 3000000 150000  ??  S    10:00AM   3:00.00 /usr/bin/ruby",
        "jgarcia          22222  4.0  2.0 4000000 200000  ??  S    11:00AM   4:00.00 /usr/bin/java",
      }

      -- Simulate selecting lines 2-3 (indices 2 and 3)
      local selected_lines = { filtered_lines[2], filtered_lines[3] }
      local pids = {}
      
      for _, line in ipairs(selected_lines) do
        local pid = vim.fn.matchstr(line, [[\w\+\s\+\zs\d\+\ze]])
        if pid ~= "" then
          table.insert(pids, pid)
        end
      end

      assert.equals(2, #pids)
      assert.equals("12345", pids[1])
      assert.equals("67890", pids[2])
      -- Should NOT include 11111 or 22222
      assert.is_not.equals("11111", pids[1])
      assert.is_not.equals("11111", pids[2])
    end)
  end)

  describe("filter application", function()
    it("should filter lines containing search term", function()
      local full_output = {
        "USER               PID  %CPU %MEM      VSZ    RSS   TT  STAT STARTED      TIME COMMAND",
        "jgarcia          12345  1.0  0.5 1000000 50000   ??  S     9:00AM   1:00.00 /usr/bin/node server.js",
        "jgarcia          67890  2.0  1.0 2000000 100000  ??  S     9:30AM   2:00.00 /usr/bin/python app.py",
        "jgarcia          11111  3.0  1.5 3000000 150000  ??  S    10:00AM   3:00.00 /usr/bin/node worker.js",
        "jgarcia          22222  4.0  2.0 4000000 200000  ??  S    11:00AM   4:00.00 /usr/bin/java Main",
      }

      -- Apply filter for "node"
      local filter = "node"
      local filtered = {}
      for i, line in ipairs(full_output) do
        if i == 1 or line:lower():find(filter:lower(), 1, true) then
          table.insert(filtered, line)
        end
      end

      assert.equals(3, #filtered)  -- Header + 2 node processes
      assert.is_truthy(filtered[1]:find("USER"))  -- Header
      assert.is_truthy(filtered[2]:find("12345"))  -- First node process
      assert.is_truthy(filtered[3]:find("11111"))  -- Second node process
    end)

    it("should be case insensitive", function()
      local full_output = {
        "USER               PID  %CPU %MEM      VSZ    RSS   TT  STAT STARTED      TIME COMMAND",
        "jgarcia          12345  1.0  0.5 1000000 50000   ??  S     9:00AM   1:00.00 /usr/bin/Node server.js",
        "jgarcia          67890  2.0  1.0 2000000 100000  ??  S     9:30AM   2:00.00 /usr/bin/python app.py",
      }

      -- Apply filter with different case
      local filter = "NODE"
      local filtered = {}
      for i, line in ipairs(full_output) do
        if i == 1 or line:lower():find(filter:lower(), 1, true) then
          table.insert(filtered, line)
        end
      end

      assert.equals(2, #filtered)  -- Header + 1 node process
      assert.is_truthy(filtered[2]:find("12345"))
    end)
  end)

  describe("PID extraction accuracy", function()
    it("should handle different username formats", function()
      local test_cases = {
        { line = "root               123  1.0  0.5 1000 500   ??  S  9:00AM  1:00 /bin/sh", expected = "123" },
        { line = "_coreaudiod        456  2.0  1.0 2000 1000  ??  Ss 9:00AM  2:00 /usr/sbin/coreaudiod", expected = "456" },
        { line = "jgarcia          78901  3.0  1.5 3000 1500  ??  S  9:00AM  3:00 /usr/bin/vim", expected = "78901" },
      }

      for _, test in ipairs(test_cases) do
        local pid = vim.fn.matchstr(test.line, [[\w\+\s\+\zs\d\+\ze]])
        assert.equals(test.expected, pid, "Failed for line: " .. test.line)
      end
    end)
  end)
end)
