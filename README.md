## tetris.nvim [WIP]

*A Neovim Plugin that implements a tetris game*

**Features:**

* Tetris game

**Dependencies:**

`leonardo-luz/floatwindow.nvim`

**Installation:**  Add `leonardo-luz/tetris.nvim` to your Neovim plugin manager (e.g., `init.lua` or `plugins/tetris.lua`).

```lua
{ 
    'leonardo-luz/tetris.nvim',
}
```

**Usage:**

* `:Tetris`: Start the game
    * `l`: Move to right
    * `h`: Move to left
    * `z`: Rotate to right
    * `x`: Rotate to left
    * `j`: Drop piece
    * `k`: Hold piece
