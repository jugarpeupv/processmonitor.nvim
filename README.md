# processmonitor.nvim

A Neovim plugin to view and manage processes from within Neovim.

Video with a demo: https://www.youtube.com/watch?v=2WDSGvltxHo

![Demo](media/demo.png)

## Features

- View process list output (`ps aux`) in a Neovim buffer
- View list of open files (`lsof`) in a Neovim buffer with syntax highlighting
- Kill processes directly from the buffer
- Kill multiple processes using visual selection
- Filter processes by name
- Pin/filter by specific PID (toggle on/off)
- Sort processes by CPU or memory usage
- Auto-reload process list (toggle on/off)
- Refresh process list
- Inspect detailed process information
- Open `/proc` filesystem for processes (Linux)
- Quick browser access to network ports from process inspector

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "jugarpeupv/processmonitor.nvim",
  config = function()
    require("ps").setup({
      -- Optional configuration
      ps_cmd = "ps aux",             -- Command to list processes
      kill_cmd = "kill -9",          -- Command to kill processes
      default_sort = "mem",          -- Default sort: "mem", "cpu", or nil
      ps_buffer_keymaps = {
        -- Override any default PS buffer keymaps here
      },
      lsof_keymaps = {
        -- Override any default LSOF buffer keymaps here
      },
      inspector_keymaps = {
        -- Override any default Inspector buffer keymaps here
      },
    })
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "jugarpeupv/processmonitor.nvim",
  config = function()
    require("ps").setup()
  end,
}
```

## Usage

### Commands

#### Process Management (ps)

| Command | Description |
| ------- | ----------- |
| `:PS` | Open a new buffer with process list |
| `:PsRefresh` | Refresh the process list |
| `:PsKillLine` | Kill the process on the current line |
| `:PsKillAllLines` | Kill all processes in the selected range |
| `:PsKillWord` | Kill the process with PID under cursor |
| `:PsInspect` | Open detailed inspector for current process |
| `:PsOpenProcLine` | Open `/proc` directory for the process |
| `:PsFilter` | Set a filter to show only matching processes |
| `:PsPortFilter` | Filter processes by network port |
| `:PsThisBuffer` | Convert current buffer to ps buffer |

#### Open Files Management (lsof)

| Command | Description |
| ------- | ----------- |
| `:Lsof` | Open a new buffer with list of open files |
| `:LsofRefresh` | Refresh the lsof output |
| `:LsofFilter` | Set a filter to show only matching entries |

### Default Keymaps

#### PS Buffer

The buffer header displays the current state and available shortcuts:

```
[ AUTO-RELOAD: OFF | R:refresh | X:kill | K:inspect | F:filter | P:pin | O:port | gC:sort CPU | gm:sort MEM | gl:auto-reload | g?:help | q:quit ]
```

When in a ps buffer:

##### Normal Mode

| Key | Action | Description |
| --- | ------ | ----------- |
| `R` | `refresh` | Refresh the process list |
| `X` | `kill` | Kill process on current line |
| `K` | `inspect` | Inspect process (detailed view) |
| `F` | `filter` | Set/clear text filter |
| `P` | `pin` | Toggle PID filter (pin/unpin current process) |
| `O` | `port` | Filter by port number (shows processes on that port) |
| `gC` | `sort_cpu` | Sort by CPU usage (highest first) |
| `gm` | `sort_mem` | Sort by memory usage (highest first) |
| `gl` | `auto_reload` | Toggle auto-reload (every 2 seconds) |
| `g?` | `help` | Show help window with keybindings |
| `p` | `open_proc` | Open `/proc/<pid>` directory (Linux only) |
| `q` | `quit` | Close buffer |

##### Visual Mode

| Key | Action | Description |
| --- | ------ | ----------- |
| `X` | `kill` | Kill all processes in selection |

#### LSOF Buffer

When in an lsof buffer:

##### Normal Mode

| Key | Action | Description |
| --- | ------ | ----------- |
| `R` | `refresh` | Refresh lsof output |
| `X` | `kill` | Kill process on current line |
| `K` | `inspect` | Inspect process (detailed view) |
| `f` | `filter` | Filter lsof output |
| `q` | `quit` | Close buffer |

##### Visual Mode

| Key | Action | Description |
| --- | ------ | ----------- |
| `X` | `kill` | Kill all processes in selection |

#### Process Inspector Buffer

When viewing detailed process information (opened with `K` or `:PsInspect`):

##### Normal Mode

| Key | Action | Description |
| --- | ------ | ----------- |
| `R` | `refresh` | Refresh inspector |
| `X` | `kill` | Kill the inspected process |
| `q` | `quit` | Close inspector window |
| `gx` | `open_url` | Open port in browser (when cursor is on a network connection line) |

The `gx` keymap is particularly useful when inspecting processes with network connections. Position your cursor on any line showing a network connection (e.g., `TCP [::1]:4873 (LISTEN)`) and press `gx` to automatically open `http://localhost:<port>` in your default browser.

### Filtering

#### Text Filter

You can filter the process list by name or other text:

1. Press `F` in the ps buffer
2. Enter a search term (e.g., "node" to see all Node.js processes)
3. Press Enter

To clear the filter:
1. Press `F`
2. Clear the input and press Enter

The filter is case-insensitive and searches across the entire process line.

#### PID Filter (Pin Feature)

You can filter to show only a specific process by PID:

1. Move cursor to the line with the process you want to pin
2. Press `P` to toggle the PID filter
3. The view will now show only that specific process
4. Press `P` again to clear the filter

When a PID filter is active, it will be shown in the status bar at the top of the buffer.

#### Port Filter

You can filter processes by network port:

1. Press `O` in the ps buffer
2. Enter a port number (e.g., "3000" or "8080")
3. Press Enter to show processes listening or connecting on that port

To clear the port filter:
1. Press `O`
2. Leave the input empty and press Enter

### Sorting

You can sort the process list by different criteria:

- **Sort by CPU**: Press `gC` to sort processes by CPU usage (highest first)
- **Sort by Memory**: Press `gm` to sort processes by memory/RSS usage (highest first)

The sort order persists when you refresh the list with `R`. To return to the default order, close and reopen the buffer.

## Configuration

You can configure processmonitor.nvim by passing options to the setup function:

```lua
require("ps").setup({
  ps_cmd = "ps aux",           -- Command to list processes
  kill_cmd = "kill -9",        -- Command to kill processes (SIGKILL)
  regex_rule = [[\w\+\s\+\zs\d\+\ze]], -- Regex to extract PID from line
  default_sort = "mem",        -- Default sort order: nil, "cpu", or "mem"

  -- 1. PS Buffer Keymaps
  ps_buffer_keymaps = {
    refresh = "R",             -- Refresh process list
    kill = "X",                -- Kill process (normal and visual mode)
    inspect = "K",             -- Inspect process details
    open_proc = "p",           -- Open /proc/<pid> (Linux)
    quit = "q",                -- Close buffer
    filter = "F",              -- Filter processes by text
    pin = "P",                 -- Pin/filter by PID
    port = "O",                -- Filter by port number
    sort_cpu = "gC",           -- Sort by CPU usage
    sort_mem = "gm",           -- Sort by memory usage
    auto_reload = "gl",        -- Toggle auto-reload
    help = "g?",               -- Show keybinding help
  },

  -- 2. LSOF Buffer Keymaps
  lsof_keymaps = {
    refresh = "R",             -- Refresh lsof list
    kill = "X",                -- Kill process (normal and visual mode)
    inspect = "K",             -- Inspect process
    filter = "f",              -- Filter lsof output
    quit = "q",                -- Close lsof buffer
  },

  -- 3. Process Inspector Buffer Keymaps
  inspector_keymaps = {
    refresh = "R",             -- Refresh inspector
    kill = "X",                -- Kill inspected process
    quit = "q",                -- Close inspector window
    open_url = "gx",           -- Open port in browser
  },
})
```

### Customizing Keymaps

Each buffer has its own dedicated keymap table:
- `ps_buffer_keymaps`: Keybindings for the main PS process buffer
- `lsof_keymaps`: Keybindings for the LSOF buffer
- `inspector_keymaps`: Keybindings for the process inspector buffer

Any keymap omitted from your configuration will use its default value. Custom PS keymaps are automatically reflected in the buffer's status line header and help popup (`g?`). Custom Inspector keymaps are automatically shown in its `ACTIONS` header.

```lua
require("ps").setup({
  -- Customize PS buffer keymaps
  ps_buffer_keymaps = {
    refresh = "r",   -- Use lowercase 'r' for refresh
    kill = "d",      -- Use 'd' to kill process
    filter = "/",    -- Use '/' to filter
    pin = "<C-p>",   -- Pin process with Ctrl+p
  },

  -- Customize LSOF buffer keymaps
  lsof_keymaps = {
    refresh = "r",
    filter = "/",
  },

  -- Customize Process Inspector keymaps
  inspector_keymaps = {
    kill = "d",
    refresh = "r",
    open_url = "go",
  },
})
```

To disable any specific keymap, set it to `false`:

```lua
require("ps").setup({
  ps_buffer_keymaps = {
    open_proc = false, -- Disable opening /proc
  },
  inspector_keymaps = {
    kill = false,      -- Disable killing from inspector
  },
})
```

### Examples

To use a different kill signal:

```lua
require("ps").setup({
  kill_cmd = "kill -15",  -- Use SIGTERM instead of SIGKILL
})
```

To use a different ps command format:

```lua
require("ps").setup({
  ps_cmd = "ps axfu",  -- Show process tree
})
```

## Requirements

- Neovim 0.7+
- `ps` command (available on most Unix-like systems)
- `kill` command
- `lsof` command (for `:Lsof` functionality)

## License

MIT

## Credits

Based on [ps.vim](https://github.com/katonori/ps.vim) by katonori, reimplemented in Lua for Neovim with additional features.
