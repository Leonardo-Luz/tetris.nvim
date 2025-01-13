local floatwindow = require("floatwindow")

local M = {}

local pieces = {
  {
    "000",
    " 0 ",
    "   ",
  },
  {
    "00",
    "00",
  },
  {
    " 00",
    "00 ",
    "   ",
  },
  {
    "00 ",
    " 00",
    "   ",
  },
  {
    "0  ",
    "0  ",
    "00 ",
  },
  {
    "  0",
    "  0",
    " 00",
  },
  {
    "0   ",
    "0   ",
    "0   ",
    "0   ",
  },
}

local state = {
  window = {},
  speed = 200, -- ms
  map = {
    map_size = {
      x = 20,
      y = 30,
    },
    map = {},
  },
  loop = nil,
  current_piece = {
    piece_id = -1,
    pos = {
      x_offset = -1,
      x_limit = -1,
      y = -1,
    },
    piece = nil,
    direc = 1,
    height = -1,
    width = -1,
  },
}

local window_config = function()
  local win_width = vim.o.columns
  local win_height = vim.o.lines

  local info_tab = 10
  local background_width = state.map.map_size.x + info_tab
  local game_width = state.map.map_size.x

  local title = "0o. Tetris .o0"
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

local clear_map = function()
  state.map.map = {}
  for _ = 0, state.map.map_size.y do
    table.insert(state.map.map, string.rep(" ", state.map.map_size.x))
  end
end

local map_update = function()
  clear_map()

  for i = state.current_piece.pos.y - (#state.current_piece.piece - 1), state.current_piece.pos.y do
    local current_line = state.map.map[i]
    local piece_row_index = i - (state.current_piece.pos.y - (#state.current_piece.piece - 1)) + 1
    local new_line = current_line:sub(1, state.current_piece.pos.x_offset)
      .. state.current_piece.piece[piece_row_index]
      .. current_line:sub(state.current_piece.pos.x_limit, current_line:len() - 1)
    state.map.map[i] = new_line
  end
end

local set_current_piece = function(piece_id)
  local aux = pieces[piece_id]
  local middle = state.map.map_size.x / 2
  state.current_piece = {
    pos = {
      x_offset = middle,
      x_limit = middle + aux[1]:len(),
      y = #aux,
    },
    direc = 1,
    piece_id = piece_id,
    piece = aux,
  }
end

local window_content = function()
  map_update()

  vim.api.nvim_buf_set_lines(state.window.game.floating.buf, 0, -1, true, state.map.map)
end

local exit = function()
  if state.loop ~= nil then
    vim.fn.timer_stop(state.loop)
  end

  foreach_float(function(_, float)
    pcall(vim.api.nvim_win_close, float.floating.win, true)
  end)
end

local rotate_piece = function(increase)
  state.current_piece.direc = state.current_piece.direc + (increase and 1 or -1)

  if state.current_piece.direc > 4 then
    state.current_piece.direc = 1
  elseif state.current_piece.direc < 1 then
    state.current_piece.direc = 4
  end

  local size = #state.current_piece.piece

  --- @type string[]
  local aux = {}

  for _ = 1, size do
    table.insert(aux, "")
  end

  if state.current_piece.direc == 1 then
    aux = pieces[state.current_piece.piece_id]
  elseif state.current_piece.direc == 2 then
    for l = size, 1, -1 do
      for j = size, 1, -1 do
        aux[j] = aux[j] .. pieces[state.current_piece.piece_id][l]:sub(j, j)
      end
    end
  elseif state.current_piece.direc == 3 then
    for j = size, 1, -1 do
      aux[size + 1 - j] = pieces[state.current_piece.piece_id][j]
    end
  elseif state.current_piece.direc == 4 then
    for l = 1, size do
      for j = 1, size do
        aux[j] = aux[j] .. pieces[state.current_piece.piece_id][l]:sub(j, j)
      end
    end
  end

  state.current_piece.piece = aux

  window_content()
end

local move_piece = function(val)
  state.current_piece.pos.x_limit = state.current_piece.pos.x_limit + val
  state.current_piece.pos.x_offset = state.current_piece.pos.x_offset + val

  if state.current_piece.pos.x_offset < 0 then
    state.current_piece.pos.x_offset = 0
    state.current_piece.pos.x_limit = state.current_piece.piece[1]:len()
  elseif state.current_piece.pos.x_limit > state.map.map_size.x then
    state.current_piece.pos.x_offset = state.map.map_size.x - state.current_piece.piece[1]:len()
    state.current_piece.pos.x_limit = state.map.map_size.x
  end

  window_content()
end

local remaps = function()
  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(state.window.game.floating.win, true)
  end, { buffer = state.window.game.floating.buf })

  vim.keymap.set("n", "d", function()
    rotate_piece(false)
  end, { buffer = state.window.game.floating.buf })
  vim.keymap.set("n", "x", function()
    rotate_piece(true)
  end, { buffer = state.window.game.floating.buf })

  vim.keymap.set("n", "h", function()
    move_piece(-1)
  end, { buffer = state.window.game.floating.buf })
  vim.keymap.set("n", "l", function()
    move_piece(1)
  end, { buffer = state.window.game.floating.buf })
  vim.keymap.set("n", "j", function()
    -- drop WIP
  end, { buffer = state.window.game.floating.buf })
  vim.keymap.set("n", "k", function()
    -- hold WIP
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

local falling_piece = function()
  state.current_piece.pos.y = state.current_piece.pos.y + 1

  if state.current_piece.pos.y + 1 > state.map.map_size.y then
    set_current_piece(math.random(1, #pieces))
  end
end

local loop = function()
  state.loop = vim.fn.timer_start(state.speed, function()
    falling_piece()

    window_content()
  end, {
    ["repeat"] = -1,
  })
end

local start = function()
  math.randomseed(os.time())

  state.window = window_config()

  state.window.background.floating = floatwindow.create_floating_window(state.window.background)
  state.window.game.floating = floatwindow.create_floating_window(state.window.game)

  set_current_piece(math.random(1, #pieces))

  loop()

  remaps()
end

vim.api.nvim_create_user_command("Tetris", start, {})

M.setup = function() end

return M
