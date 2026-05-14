# project-switcher.nvim

Switch between projects in one Neovim instance using:
- telescope + project.nvim project list
- persistence.nvim sessions per project

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
    require("project_switcher").setup({
      -- defaults:
      -- keymap = "<leader>fp",
      -- save_prompt = true,
    })
  end,
}
