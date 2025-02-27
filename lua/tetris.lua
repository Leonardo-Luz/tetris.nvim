local floatwindow = require("floatwindow")

local M = {}

---@type {x: integer, y:integer}
local pieces = {
  { -- 1 = T
    { x = 1, y = 1 },
    { x = 2, y = 1 },
    { x = 3, y = 1 },
    { x = 2, y = 2 },
  },
  { -- 2 = Square
    { x = 1, y = 1 },
    { x = 2, y = 1 },
    { x = 1, y = 2 },
    { x = 2, y = 2 },
  },
  { -- 3 = s
    { x = 2, y = 1 },
    { x = 3, y = 1 },
    { x = 1, y = 2 },
    { x = 2, y = 2 },
  },
  { -- 4 = z
    { x = 1, y = 1 },
    { x = 2, y = 1 },
    { x = 2, y = 2 },
    { x = 3, y = 2 },
  },
  { -- 5 = L
    { x = 1, y = 1 },
    { x = 1, y = 2 },
    { x = 1, y = 3 },
    { x = 2, y = 3 },
  },
  { -- 6 = J
    { x = 2, y = 1 },
    { x = 2, y = 2 },
    { x = 2, y = 3 },
    { x = 1, y = 3 },
  },
  { -- 7 = I
    { x = 1, y = 1 },
    { x = 1, y = 2 },
    { x = 1, y = 3 },
    { x = 1, y = 4 },
  },
}

local state = {
  window = {},
  info_tab = 16,
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
  aux_piece = {},
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
  score = 0,
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

  local info_tab = state.info_tab
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

local string_mescle = function(char1, char2, size)
  local line = ""

  for i = 1, size, 1 do
    if i % 2 == 0 then
      line = line .. char1
    else
      line = line .. char2
    end
  end

  return line
end

local clear_map = function()
  for i, map_line in pairs(state.map.actual) do
    if map_line == ("0"):rep(state.map.map_size.x) then
      table.remove(state.map.actual, i)
      table.insert(state.map.actual, 1, string_mescle("|", " ", state.map.map_size.x))
    end
  end

  state.map.actual = {}
  for _ = 0, state.map.map_size.y do
    table.insert(state.map.actual, string_mescle("|", " ", state.map.map_size.x))
  end
end

local map_update = function()
  clear_map()

  for _, tile in pairs(state.current_piece.piece) do
    local current_line = nil

    if tile.y < state.map.map_size.y then
      current_line = state.map.actual[tile.y]
    end

    if current_line == nil then
      return
    end

    local new_line = current_line:sub(0, tile.x - 1) .. "0" .. current_line:sub(tile.x + 1, current_line:len())
    state.map.actual[tile.y] = new_line
  end

  if #state.map.pieces > 0 then
    for _, tile in pairs(state.map.pieces) do
      local current_line = state.map.actual[tile.y]
      local new_line = current_line:sub(0, tile.x - 1) .. "0" .. current_line:sub(tile.x + 1, current_line:len())
      state.map.actual[tile.y] = new_line
    end
  end
end

local set_current_piece = function(piece_id)
  -- FIX: debug
  -- piece_id = 2

  local clone = pieces[piece_id]

  local aux
  if type(clone) == "table" then
    aux = deep_copy(clone)
  end

  if type(aux) == "table" then
    state.current_piece = {
      direc = 1,
      piece_id = piece_id,
      piece = aux,
    }

    state.aux_piece = deep_copy(aux)
  end
end

local window_content = function()
  map_update()

  local lines = {}

  for i = 1, state.map.map_size.y, 1 do
    local line = ""
    if i == state.map.map_size.y then
      line = ("-"):rep(state.window.background.opts.width - ("Score:  " .. tostring(state.score)):len())
        .. "Score: "
        .. state.score
        .. "-"
    else
      line = ("-"):rep(state.window.background.opts.width)
    end

    table.insert(lines, line)
  end

  vim.api.nvim_buf_set_lines(state.window.game.floating.buf, 0, -1, true, state.map.actual)
  vim.api.nvim_buf_set_lines(state.window.background.floating.buf, 0, -1, true, lines)
end

local exit = function()
  if state.loop ~= nil then
    vim.fn.timer_stop(state.loop)
  end

  foreach_float(function(_, float)
    pcall(vim.api.nvim_win_close, float.floating.win, true)
  end)
end

local collision = function(aux)
  -- Check for boundary collisions
  for _, tile in pairs(aux) do
    if tile.x < 1 or tile.x > state.map.map_size.x or tile.y < 1 or tile.y > state.map.map_size.y then
      return true
    end
  end

  for _, placed_tile in pairs(state.map.pieces) do
    for _, tile in pairs(aux) do
      if placed_tile.x == tile.x and placed_tile.y == tile.y then
        return true
      end
    end
  end

  return false
end

local get_center_of_rotation = function(piece_id)
  if piece_id == 1 then -- T-piece
    return 2, 1
  elseif piece_id == 2 then -- Square-piece
    return 1.5, 1.5
  elseif piece_id == 3 then -- S-piece
    return 2, 2
  elseif piece_id == 4 then -- Z-piece
    return 2, 2
  elseif piece_id == 5 then -- L-piece
    return 1, 2
  elseif piece_id == 6 then -- J-piece
    return 2, 2
  elseif piece_id == 7 then -- I-piece
    return 1, 2
  end
end

local rotate_piece = function(increase)
  local backup_direc = state.current_piece.direc

  state.current_piece.direc = state.current_piece.direc + (increase and 1 or -1)
  state.current_piece.direc = (state.current_piece.direc - 1) % 4 + 1

  local aux = deep_copy(state.aux_piece)
  if not aux then
    return
  end

  local center_x, center_y = get_center_of_rotation(state.current_piece.piece_id)

  local angle = math.rad((state.current_piece.direc - 1) * 90)

  for _, tile in pairs(aux) do
    local dx = tile.x - center_x
    local dy = tile.y - center_y
    tile.x = center_x + dx * math.cos(angle) - dy * math.sin(angle)
    tile.y = center_y + dx * math.sin(angle) + dy * math.cos(angle)
    tile.x = math.floor(tile.x + 0.5)
    tile.y = math.floor(tile.y + 0.5)
  end

  local min = {
    x = 100,
    y = 100,
  }

  for _, value in pairs(state.current_piece.piece) do
    if value.x < min.x then
      min.x = value.x
    end
    if value.y < min.y then
      min.y = value.y
    end
  end

  for _, value in pairs(aux) do
    value.x = value.x + min.x
    value.y = value.y + min.y
  end

  if not collision(aux) then
    state.current_piece.piece = aux
  else
    state.current_piece.direc = backup_direc
  end

  window_content()
end

local move_piece = function(val)
  local hit_wall = false

  for _, tile in pairs(state.current_piece.piece) do
    if tile.x < 2 and val < 0 or tile.x > state.map.map_size.x - 1 and val > 0 then
      hit_wall = true
    end
  end

  if hit_wall then
    window_content()
    return
  end

  for _, tile in pairs(state.current_piece.piece) do
    tile.x = tile.x + val
  end

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
    for _, tile in pairs(state.current_piece.piece) do
      tile.y = tile.y + 1
    end
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

local removeValuesFromTable = function(tbl, valuesToRemove)
  local valuesSet = {}
  for _, v in ipairs(valuesToRemove) do
    valuesSet[v] = true
  end

  for i = #tbl, 1, -1 do
    if valuesSet[tbl[i]] then
      table.remove(tbl, i)
    end
  end
end

local gravity = function()
  for _, tile in pairs(state.current_piece.piece) do
    tile.y = tile.y + 1
  end

  -- checks if the piece hit another piece in the map
  -- FIX: doesnt check horizontal for collision
  if #state.map.pieces > 0 then
    for _, mapPos in ipairs(state.map.pieces) do
      for _, myPos in ipairs(state.current_piece.piece) do
        if mapPos.x == myPos.x and mapPos.y == myPos.y then
          vim.print("Your tetris tile hit a map tile!")

          for _, tile in pairs(state.current_piece.piece) do
            tile.y = tile.y - 1

            if tile.y <= 1 then -- GAME OVER
              set_current_piece(math.random(1, #pieces))
              for _ = 1, #state.map.pieces do
                table.remove(state.map.pieces, 1)
              end
              return
            end
          end

          local copy = deep_copy(state.current_piece.piece)

          for _, cpy in pairs(copy) do
            table.insert(state.map.pieces, cpy)
          end

          set_current_piece(math.random(1, #pieces))
          return
        end
      end
    end
  end

  -- check if piece is in the bottom of the map
  for _, tile in pairs(state.current_piece.piece) do
    if tile.y == state.map.map_size.y then
      local copy = deep_copy(state.current_piece.piece)

      for _, cpy in pairs(copy) do
        table.insert(state.map.pieces, cpy)
      end

      set_current_piece(math.random(1, #pieces))
      return
    end
  end

  -- check for line clear
  for y = 1, state.map.map_size.y do
    local remove = {}
    for x = 1, state.map.map_size.x do
      for _, tile in pairs(state.map.pieces) do
        if tile.y == y and tile.x == x then
          table.insert(remove, tile)

          -- last line char
          if x == state.map.map_size.x then
            vim.print("line clear")

            removeValuesFromTable(state.map.pieces, remove)

            for _, value in pairs(state.map.pieces) do
              if value.y < y then
                value.y = value.y + 1
              end
            end

            state.score = state.score + 100
            goto next_line
          else
            goto next_col
          end
        end
      end
      goto next_line

      ::next_col::
    end
    ::next_line::
    remove = {}
  end
end

local loop = function()
  state.loop = vim.fn.timer_start(state.speed, function()
    local status = pcall(function()
      gravity()

      window_content()
    end, 10, 2)
    if status == false then
      print("Error")
      vim.fn.timer_stop(state.loop)
      return
    end
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

  loop()

  remaps()
end

vim.api.nvim_create_user_command("Tetris", start, {})

---setup tetris plugin
---@param opts { map_size: {x: number, y:number}|nil, info_tab_size:number|nil, speed:number|nil }|nil
M.setup = function(opts)
  if not opts then
    return
  end

  state.map.map_size = opts.map_size and opts.map_size or { x = 20, y = 30 }
  state.info_tab = opts.info_tab_size and opts.info_tab_size or 16
  state.speed = opts.speed and opts.speed or 120
end

return M
