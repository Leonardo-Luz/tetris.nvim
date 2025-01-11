local floatwindow = require("floatwindow")

local M = {}

local state = {
  window = {},
  speed = 200, -- ms
  map = {
    map_size = {
      x = 20,
      y = 30,
    },
  },
}

local window_config = function()
  local win_width = vim.o.columns
  local win_height = vim.o.lines

  local info_tab = 10
  local background_width = state.map.map_size.x + info_tab
  local game_width = state.map.map_size.x

  local title = "0o.Tetris.o0"
  local padding = string.rep("#", (game_width - title:len()) / 2)

  return {
    background = {
      floating = {
        buf = -1,
        win = -1,
      },
      ---@type vim.api.keyset.win_config
      opts = {
        relative = "editor",
        style = "minimal",
        width = background_width,
        height = state.map.map_size.y + 1,
        col = math.floor((win_width - (state.map.map_size.x + info_tab)) / 2),
        row = math.floor((win_height - state.map.map_size.y + 2) / 2),
        border = { "#", "#", "#", "#", "#", "#", "#", "#" },
      },
      enter = false,
    },
    game = {
      floating = {
        buf = -1,
        win = -1,
      },
      ---@type vim.api.keyset.win_config
      opts = {
        relative = "editor",
        style = "minimal",
        width = game_width,
        height = state.map.map_size.y + 1,
        col = math.floor((win_width - state.map.map_size.x - info_tab) / 2),
        row = math.floor((win_height - state.map.map_size.y + 2) / 2),
        border = { "#", "#", "#", "#", "#", "#", "#", "#" },
        title = padding .. title,
      },
      enter = true,
    },
  }
end

local foreach_float = function(callback)
  for name, float in pairs(state.window) do
    callback(name, float)
  end
end

local window_content = function() end

local exit = function()
  foreach_float(function(_, float)
    pcall(vim.api.nvim_win_close, float.floating.win, true)
  end)
end

local remaps = function()
  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(state.window.game.floating.win, true)
  end, { buffer = state.window.game.floating.buf })

  vim.keymap.set("n", "h", function()
    -- turn right
  end, { buffer = state.window.game.floating.buf })
  vim.keymap.set("n", "l", function()
    -- turn left
  end, { buffer = state.window.game.floating.buf })
  vim.keymap.set("n", "j", function()
    -- drop
  end, { buffer = state.window.game.floating.buf })
  vim.keymap.set("n", "k", function()
    -- hold
  end, { buffer = state.window.game.floating.buf })

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = state.window.game.floating.buf,
    callback = function()
      exit()
    end,
  })

  vim.api.nvim_create_autocmd("VimResized", {
    group = vim.api.nvim_create_augroup("tetris-resized", {}),
    callback = function()
      if not vim.api.nvim_win_is_valid(state.window.game.floating.win) or state.window.game.floating.win == nil then
        return
      end

      local updated = window_config()

      foreach_float(function(name, float)
        float.opts = updated[name].opts
        vim.api.nvim_win_set_config(float.floating.win, updated[name].opts)
      end)

      window_content()
    end,
  })
end

local loop = function()
  vim.fn.timer_start(state.speed, function()
    window_content()
  end, {
    ["repeat"] = -1,
  })
end

local start = function()
  state.window = window_config()

  state.window.background.floating = floatwindow.create_floating_window(state.window.background)
  state.window.game.floating = floatwindow.create_floating_window(state.window.game)

  loop()

  remaps()
end

vim.api.nvim_create_user_command("Tetris", start, {})

M.setup = function() end

return M
