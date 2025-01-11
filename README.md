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

* `:Tetris`: Opens your last note or creates a new one if none was found.
    * `l`: Rotate to right
    * `h`: Rotate to left
    * `j`: Drop piece
    * `k`: Hold piece
