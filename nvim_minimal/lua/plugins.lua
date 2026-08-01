vim.pack.add({
  { src = 'https://github.com/nvim-mini/mini.nvim', version = 'stable' },
  { src = 'https://github.com/neovim/nvim-lspconfig', version = 'v2.11.0' },
  { src = 'https://github.com/neanias/everforest-nvim.git', version = 'a0e9edc57379e8feafc6ba207c26dbb12fc1b6d8' },
})

require('mini.files').setup({
  mappings = {
    go_in_plus = 'l'
  }
})
require('mini.icons').setup({})
require('mini.pick').setup({})
require('mini.extra').setup({})
require('mini.git').setup({})
require('mini.diff').setup({})
require('mini.statusline').setup({})
require('mini.trailspace').setup()

require('everforest').setup({ background = 'dark'})

local gr = vim.api.nvim_create_augroup('custom-config', {})
new_autocmd = function(event, pattern, callback, desc)
  local opts = { group = gr, pattern = pattern, callback = callback, desc = desc }
  vim.api.nvim_create_autocmd(event, opts)
end

local process_items_opts = { kind_priority = { Text = -1, Snippet = 99 } }
local process_items = function(items, base)
  return MiniCompletion.default_process_items(items, base, process_items_opts)
end

require('mini.completion').setup({
  set_vim_settings = false,
  lsp_completion = {
    source_func = 'omnifunc',
    auto_setup = false,
    process_items = process_items,
  },
})

-- Set 'omnifunc' for LSP completion only when needed.
local on_attach = function(ev)
  vim.bo[ev.buf].omnifunc = 'v:lua.MiniCompletion.completefunc_lsp'
end
new_autocmd('LspAttach', nil, on_attach, "Set 'omnifunc'")

-- Advertise to servers that Neovim now supports certain set of completion and
-- signature features through 'mini.completion'.
vim.lsp.config('*', { capabilities = MiniCompletion.get_lsp_capabilities() })

-- When we do nvim . (mini.files is opened) then ctrl-o to jump back to previous file, it won't work
-- So check if mini.files is open, if yes then close it first before ctrl-o
vim.api.nvim_create_autocmd('User', {
  pattern = 'MiniFilesWindowOpen',
  callback = function()
    vim.keymap.set('n', '<C-o>', function()
      MiniFiles.close()

      -- \15 is ctrl-o
      vim.cmd('normal! \15') -- now in the target window
    end, { buffer = true, desc = 'Close MiniFiles then jump to older location' })
  end,
})

