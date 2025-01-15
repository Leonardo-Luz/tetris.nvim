local floatwindow = require("floatwindow")

local M = {}

---@type {x: integer, y:integer}
local pieces = {
  {
    { x = 1, y = 1 },
    { x = 2, y = 1 },
    { x = 3, y = 1 },
    { x = 2, y = 2 },
  },
  {
    { x = 1, y = 1 },
    { x = 2, y = 1 },
    { x = 1, y = 2 },
    { x = 2, y = 2 },
  },
  {
    { x = 2, y = 1 },
    { x = 3, y = 1 },
    { x = 1, y = 2 },
    { x = 2, y = 2 },
  },
  {
    { x = 1, y = 1 },
    { x = 2, y = 1 },
    { x = 2, y = 2 },
    { x = 3, y = 2 },
  },
  {
    { x = 1, y = 1 },
    { x = 1, y = 2 },
    { x = 1, y = 3 },
    { x = 2, y = 3 },
  },
  {
    { x = 2, y = 1 },
    { x = 2, y = 2 },
    { x = 2, y = 3 },
    { x = 1, y = 3 },
  },
  {
    { x = 1, y = 1 },
    { x = 1, y = 2 },
    { x = 1, y = 3 },
    { x = 1, y = 4 },
  },
}

local state = {
  window = {},
  speed = 120,
  map = {
    map_size = {
      x = 20,
      y = 30,
    },
    actual = {},
    pieces = {},
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

---Copies a table without referencing it
---@param obj table
---@return table
local function deep_copy(obj)
  local copy
  if type(obj) == "table" then
    copy = {}
    for k, v in pairs(obj) do
      copy[deep_copy(k)] = deep_copy(v)
    end
  else
    copy = obj
  end
  return copy
end

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
        height = state.map.map_size.y,
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
        height = state.map.map_size.y,
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
  for i, map_line in pairs(state.map.actual) do
    if map_line == ("0"):rep(state.map.map_size.x) then
      table.remove(state.map.actual, i)
      table.insert(state.map.actual, 1, (" "):rep(state.map.map_size.x))
    end
  end

  state.map.actual = {}
  for _ = 0, state.map.map_size.y do
    table.insert(state.map.actual, string.rep(" ", state.map.map_size.x))
  end
end

local map_update = function()
  clear_map()

  for _, tile in pairs(state.current_piece.piece) do
    local current_line = state.map.actual[tile.y]
    local new_line = current_line:sub(1, tile.x - 1) .. "0" .. current_line:sub(tile.x + 1, current_line:len() - 1)
    state.map.actual[tile.y] = new_line
  end

  -- FIX: CRASHS WHEN THE MAP IS CLEANED
  if #state.map.pieces > 0 then
    for _, piece in pairs(state.map.pieces) do
      for _, tile in pairs(piece.piece) do
        local current_line = state.map.actual[tile.y]
        local new_line = current_line:sub(0, tile.x - 1) .. "0" .. current_line:sub(tile.x + 1, current_line:len() - 1)
        state.map.actual[tile.y] = new_line
      end
    end
  end
end

local set_current_piece = function(piece_id)
  local clone = pieces[piece_id]

  local aux
  if type(clone) == "table" then
    aux = deep_copy(clone)
  end

  if type(aux) == "table" then
    local height = -1

    for _, tile in pairs(aux) do
      if tile.y > height then
        height = tile.y
      end
    end
    local offset = -1
    local limit = -1

    for _, tile in pairs(aux) do
      if tile.y == height then
        if tile.x > limit then
          limit = tile.x
        end
        if tile.x <= limit and tile.x > offset then
          offset = tile.x
        end
      end
    end

    state.current_piece = {
      pos = {
        x_offset = offset,
        x_limit = limit,
        y = height,
      },
      direc = 1,
      piece_id = piece_id,
      piece = deep_copy(aux),
    }
  end
end

local window_content = function()
  map_update()

  vim.api.nvim_buf_set_lines(state.window.game.floating.buf, 0, -1, true, state.map.actual)
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

  local aux = state.current_piece.piece

  if aux == nil then
    return
  end

  local max_x = -1
  local max_y = -1

  for _, tile in pairs(aux) do
    if tile.x > max_x then
      max_x = tile.x
    end
    if tile.y > max_y then
      max_y = tile.y
    end
  end

  if state.current_piece.direc == 2 then
    for _, tile in pairs(aux) do
      tile.x, tile.y = tile.y, tile.x
    end
  elseif state.current_piece.direc == 3 then
    for _, tile in pairs(aux) do
      if tile.x == 1 then
        tile.x = max_x
      elseif tile.x == max_x then
        tile.x = 1
      end
    end
  elseif state.current_piece.direc == 4 then
    for _, tile in pairs(aux) do
      tile.x, tile.y = tile.y, tile.x
    end
  end

  state.current_piece.piece = aux

  window_content()
end

local move_piece = function(val)
  for _, tile in pairs(state.current_piece.piece) do
    if state.current_piece.pos.x_offset < 1 and val < 0 then
      window_content()
      return
    elseif state.current_piece.pos.x_limit > state.map.map_size.x - 1 and val > 0 then
      window_content()
      return
    else
      tile.x = tile.x + val
    end
  end

  state.current_piece.pos.x_limit = state.current_piece.pos.x_limit + val
  state.current_piece.pos.x_offset = state.current_piece.pos.x_offset + val

  window_content()
end

local remaps = function()
  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(state.window.game.floating.win, true)
  end, { buffer = state.window.game.floating.buf })

  vim.keymap.set("n", "j", function()
    rotate_piece(false)
  end, { buffer = state.window.game.floating.buf })
  vim.keymap.set("n", "k", function()
    rotate_piece(true)
  end, { buffer = state.window.game.floating.buf })

  vim.keymap.set("n", "h", function()
    move_piece(-1)
  end, { buffer = state.window.game.floating.buf })
  vim.keymap.set("n", "l", function()
    move_piece(1)
  end, { buffer = state.window.game.floating.buf })
  vim.keymap.set("n", "d", function()
    state.current_piece.pos.y = state.current_piece.pos.y + 1
  end, { buffer = state.window.game.floating.buf })

  vim.keymap.set("n", "c", function()
    -- hold WIP
    set_current_piece(math.random(1, #pieces))
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

local gravity = function()
  for _, tile in pairs(state.current_piece.piece) do
    tile.y = tile.y + 1
  end
  state.current_piece.pos.y = state.current_piece.pos.y + 1

  if #state.map.pieces > 0 then
    for _, piece in ipairs(state.map.pieces) do
      if
        state.current_piece.pos.y > piece.pos.y - #piece.piece
        and (
          (
            state.current_piece.pos.x_offset >= piece.pos.x_offset
            and state.current_piece.pos.x_offset <= piece.pos.x_limit
          )
          or (
            state.current_piece.pos.x_limit >= piece.pos.x_offset
            and state.current_piece.pos.x_limit <= piece.pos.x_limit
          )
        )
      then
        state.current_piece.pos.y = piece.pos.y - #piece.piece

        if state.current_piece.pos.y < 0 then
          set_current_piece(math.random(1, #pieces))
          for _ = 1, #state.map.pieces do
            table.remove(state.map.pieces, 1)
          end
          return
        else
          local copy = deep_copy(state.current_piece)

          table.insert(state.map.pieces, copy)

          set_current_piece(math.random(1, #pieces))
          return
        end
      end
    end
  end

  if state.current_piece.pos.y > state.map.map_size.y then
    state.current_piece.pos.y = state.map.map_size.y

    local copy = deep_copy(state.current_piece)

    table.insert(state.map.pieces, copy)

    set_current_piece(math.random(1, #pieces))
    return
  end
end

-- local loop = function() end

local loop = function()
  state.loop = vim.fn.timer_start(state.speed, function()
    gravity()

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

  if state.current_piece.piece == nil then
    set_current_piece(math.random(1, #pieces))
  end

  -- loop()

  remaps()
end

vim.api.nvim_create_user_command("Tetris", start, {})

M.setup = function() end

return M
