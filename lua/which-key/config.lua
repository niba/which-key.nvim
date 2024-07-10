---@class wk.Config: wk.Opts
local M = {}

M.ns = vim.api.nvim_create_namespace("wk")

---@class wk.Opts
local defaults = {
  ---@type "classic" | "modern" | "helix"
  preset = "classic",
  -- Delay before showing the popup. Can be a number or a function that returns a number.
  ---@type number | fun(ctx: { lhs: string, mode: string, plugin?: string }):number
  delay = function(ctx)
    return ctx.plugin and 0 or 200
  end,
  -- Enable/disable WhichKey for certain mapping modes
  modes = {
    n = true, -- Normal mode
    i = true, -- Insert mode
    x = true, -- Visual mode
    s = true, -- Select mode
    o = true, -- Operator pending mode
    t = true, -- Terminal mode
    c = true, -- Command mode
  },
  plugins = {
    marks = true, -- shows a list of your marks on ' and `
    registers = true, -- shows your registers on " in NORMAL or <C-r> in INSERT mode
    -- the presets plugin, adds help for a bunch of default keybindings in Neovim
    -- No actual key bindings are created
    spelling = {
      enabled = true, -- enabling this will show WhichKey when pressing z= to select spelling suggestions
      suggestions = 20, -- how many suggestions should be shown in the list?
    },
    presets = {
      operators = true, -- adds help for operators like d, y, ...
      motions = true, -- adds help for motions
      text_objects = true, -- help for text objects triggered after entering an operator
      windows = true, -- default bindings on <c-w>
      nav = true, -- misc bindings to work with windows
      z = true, -- bindings for folds, spelling and others prefixed with z
      g = true, -- bindings for prefixed with g
    },
  },
  ---@type wk.Win
  win = {
    width = 0.9,
    -- width = { min = 40, max = 0.4 },
    height = { min = 4, max = 25 },
    padding = { 1, 2 }, -- extra window padding [top/bottom, right/left]
    col = 0.05,
    row = -1,
    border = "rounded",
    title = true,
    title_pos = "center",
    zindex = 1000,
    -- Additional vim.wo and vim.bo options
    bo = {},
    wo = {
      -- winblend = 10, -- value between 0-100 0 for fully opaque and 100 for fully transparent
    },
  },
  layout = {
    width = { min = 20, max = 50 }, -- min and max width of the columns
    spacing = 3, -- spacing between columns
    align = "left", -- align columns left, center or right
  },
  keys = {
    scroll_down = "<c-d>", -- binding to scroll down inside the popup
    scroll_up = "<c-u>", -- binding to scroll up inside the popup
  },
  ---@type (string|wk.Sorter)[]
  sort = { "order", "group", "alphanum", "mod", "lower", "icase" },
  ---@type table<string, ({[1]:string, [2]:string}|fun(str:string):string)[]>
  replace = {
    key = {
      -- { "<Space>", "SPC" },
    },
    desc = {
      { "<Plug>%((.*)%)", "%1" },
      { "^%+", "" },
      { "<[cC]md>", "" },
      { "<[cC][rR]>", "" },
      { "<[sS]ilent>", "" },
      { "^lua%s+", "" },
      { "^call%s+", "" },
      { "^:%s*", "" },
    },
  },
  icons = {
    breadcrumb = "»", -- symbol used in the command line area that shows your active key combo
    separator = "➜", -- symbol used between a key and it's label
    group = "+", -- symbol prepended to a group
    ellipsis = "…",
  },
  show_help = true, -- show a help message in the command line for using WhichKey
  show_keys = true, -- show the currently pressed key and its label as a message in the command line
  -- Which-key automatically sets up triggers for your mappings.
  -- But you can disable this and manually setup triggers.
  -- Be aware, that triggers are not used for visual and operator pending mode.
  ---@type boolean | string[]
  triggers = true, -- automatically setup triggers
  -- triggers = {"<leader>"} -- or specify a list manually
  disable = {
    -- disable WhichKey for certain buf types and file types.
    ft = {},
    bt = {},
  },
}

M.loaded = false

---@type wk.Keymap[]
M.mappings = {}

---@type wk.Opts
M.options = nil

---@param opts? wk.Opts
function M.setup(opts)
  if vim.fn.has("nvim-0.9") == 0 then
    return vim.notify("whichkey.nvim requires Neovim >= 0.9", vim.log.levels.ERROR)
  end
  M.options = vim.tbl_deep_extend("force", {}, defaults, opts or {})

  local function load()
    if M.options.preset then
      local Presets = require("which-key.presets")
      M.options = vim.tbl_deep_extend("force", M.options, Presets[M.options.preset] or {})
    end
    require("which-key.plugins").setup()
    local wk = require("which-key")
    wk.register = M.register
    for _, v in ipairs(wk._queue) do
      M.register(v.mappings, v.opts)
    end
    wk._queue = {}
    require("which-key.colors").setup()
    require("which-key.state").setup()
    M.loaded = true
  end
  load = vim.schedule_wrap(load)

  if vim.v.vim_did_enter == 1 then
    load()
  else
    vim.api.nvim_create_autocmd("VimEnter", { once = true, callback = load })
  end
end

function M.register(mappings, opts)
  local Mappings = require("which-key.mappings")
  local ret = {} ---@type wk.Keymap[]
  for _, km in ipairs(Mappings.parse(mappings, opts)) do
    if km.rhs or km.callback then
      vim.keymap.set(km.mode, km.lhs, km.callback or km.rhs or "", Mappings.opts(km))
    else
      km.virtual = true
      ret[#ret + 1] = km
    end
  end
  vim.list_extend(M.mappings, ret)
  if M.loaded then
    require("which-key.buf").reset()
  end
end

return setmetatable(M, {
  __index = function(_, k)
    if rawget(M, "options") == nil then
      M.setup()
    end
    local opts = rawget(M, "options")
    return k == "options" and opts or opts[k]
  end,
})
