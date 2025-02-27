# tetris.nvim

*A Neovim Plugin that provides a playable text-based Tetris game.*

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
* `d`: Drop piece.
* `c`: Hold piece.
* `k`: Rotate piece right (subject to change).
* `j`: Rotate piece left (subject to change).
