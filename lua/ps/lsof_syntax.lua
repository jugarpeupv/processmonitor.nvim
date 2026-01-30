-- lsof syntax highlighting
-- Provides syntax highlighting for lsof buffer

local M = {}

function M.apply()
  -- Match the header line (starts with COMMAND)
  vim.cmd([[syntax match lsofHeader "^COMMAND.*$"]])

  -- Match COMMAND column (first column)
  vim.cmd([[syntax match lsofCommand "^\S\+"]])

  -- Match PID (second column - numbers)
  vim.cmd([[syntax match lsofPID "\s\+\zs\d\+\ze\s"]])

  -- Match USER (third column)
  vim.cmd([[syntax match lsofUser "\s\+\zs[a-zA-Z0-9_-]\+\ze\s\+\w\+"]])

  -- Match FD (file descriptor - numbers followed by optional flags like r, w, u)
  vim.cmd([[syntax match lsofFD "\s\+\zs\d\+[rwu]*\ze\s"]])

  -- Match TYPE (like DIR, REG, CHR, IPv4, IPv6, unix, etc.)
  vim.cmd([[syntax match lsofType "\s\+\zs\(DIR\|REG\|CHR\|BLK\|FIFO\|unix\|IPv4\|IPv6\|sock\|PIPE\|LINK\)\ze\s"]])

  -- Match DEVICE (like 1,5 or numbers with comma)
  vim.cmd([[syntax match lsofDevice "\s\+\zs\d\+,\d\+\ze\s"]])

  -- Match SIZE/OFF (numbers)
  vim.cmd([[syntax match lsofSize "\s\+\zs\d\+\ze\s"]])

  -- Match NODE (numbers)
  vim.cmd([[syntax match lsofNode "\s\+\zs\d\+\ze\s"]])

  -- Match file paths (absolute paths starting with /)
  vim.cmd([[syntax match lsofPath "/[^ ]*"]])

  -- Match network addresses (IP:port)
  vim.cmd([[syntax match lsofNetwork "\d\+\.\d\+\.\d\+\.\d\+:\d\+"]])
  vim.cmd([[syntax match lsofNetwork "\*:\d\+"]])
  vim.cmd([[syntax match lsofNetwork ":\d\+"]])

  -- Match states (LISTEN, ESTABLISHED, etc.)
  vim.cmd([[syntax match lsofState "(LISTEN)"]])
  vim.cmd([[syntax match lsofState "(ESTABLISHED)"]])
  vim.cmd([[syntax match lsofState "(CLOSE_WAIT)"]])
  vim.cmd([[syntax match lsofState "(TIME_WAIT)"]])
  vim.cmd([[syntax match lsofState "(SYN_SENT)"]])

  -- Link to standard highlight groups
  vim.cmd([[highlight default link lsofHeader Title]])
  vim.cmd([[highlight default link lsofCommand Function]])
  vim.cmd([[highlight default link lsofPID Number]])
  vim.cmd([[highlight default link lsofUser String]])
  vim.cmd([[highlight default link lsofFD Constant]])
  vim.cmd([[highlight default link lsofType Type]])
  vim.cmd([[highlight default link lsofDevice Special]])
  vim.cmd([[highlight default link lsofSize Float]])
  vim.cmd([[highlight default link lsofNode Number]])
  vim.cmd([[highlight default link lsofPath Identifier]])
  vim.cmd([[highlight default link lsofNetwork Keyword]])
  vim.cmd([[highlight default link lsofState Statement]])
end

function M.setup()
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "lsof",
    callback = function()
      M.apply()
      vim.b.current_syntax = "lsof"
    end,
  })
end

return M
