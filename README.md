# project-switcher.nvim

Quickly switch between projects and restore project sessions in a single Neovim instance.
Selecting a project changes the working directory and restores that project's session automatically.
Works by:
- Browsing projects using Telescope + project.nvim
- Automatically restoring persistence.nvim sessions per project
  
Mapped to `<leader>pp` by default.

## Installation (lazy.nvim)
```lua
{
  "jeanbeanie/project-switcher.nvim",
  dependencies = {
    "nvim-telescope/telescope.nvim",
    "ahmedkhalf/project.nvim",
    "folke/persistence.nvim",
  },
  config = function()
    require("project_switcher").setup()
  end,
}
```
### Override Example


##### `sync_nvim_tree_root` (default: `true`)

If you use **nvim-tree**, this keeps the tree rooted to the newly-selected project after switching.

If you **don’t** use nvim-tree, it’s still safe to leave this enabled (it no-ops). 
You can disable it if you prefer:

```lua
{
  "jeanbeanie/project-switcher.nvim",
  dependencies = {
    "nvim-telescope/telescope.nvim",
    "ahmedkhalf/project.nvim",
    "folke/persistence.nvim",
  },
  config = function()
    require("project_switcher").setup({
      -- override defaults:
       keymap = "<leader>fp",
       save_prompt = false,
       sync_nvim_tree_root = false,
    })
  end,
}
