# tetris.nvim (WIP)

*A Neovim plugin that provides a playable Tetris game.*

**Features:**

* Persistent high score between sessions.

**Dependencies:**

`leonardo-luz/floatwindow.nvim`

**Installation:**  Add `leonardo-luz/tetris.nvim` to your Neovim plugin manager (e.g., `init.lua` or `plugins/tetris.lua`).

```lua
{ 
    'leonardo-luz/tetris.nvim',
}
```

**Usage:**

* `:Tetris`: Start the game.
* `l`: Move piece right.
* `h`: Move piece left.
* `j`: Drop piece.
* `k`: Hold piece.
* `d`: Rotate piece right (subject to change).
* `x`: Rotate piece left (subject to change).
