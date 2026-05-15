-- project-switcher.nvim
-- A tiny helper to switch between project roots (via Telescope projects)
-- and restore the session for that project (via persistence.nvim).
--
-- Default UX:
--   - <leader>pp opens the project picker
--   - <CR> switches to the selected project:
--       1) optionally writes files (:wa)
--       2) saves the current session (per-cwd)
--       3) prompts if there are still modified buffers (optional)
--       4) clears tabs/buffers (workspace reset)
--       5) :cd into the new project root
--       6) loads that project's session
-- Optional UX:
--   - If sync_nvim_tree=true (default), the plugin will re-root nvim-tree to the new cwd
--     so toggling the tree doesn't show the old project's directory.

local M = {}

-- Defaults are merged with user opts in setup() and pick_and_switch().
local defaults = {
  set_default_keymap = true,
  keymap = "<leader>pp",

  -- Behavior knobs
  save_prompt = true,         -- prompt if there are modified buffers before discarding
  save_before_switch = true,  -- run :wa before switching (tries to write all files)
  clear_tabs = true,          -- run :tabonly before clearing buffers

  -- Integrations
  sync_nvim_tree_root = true, -- re-root nvim-tree after changing cwd (safe no-op if not installed)
}

-- Returns true if any *listed* buffer is still modified.
-- (This catches scratch buffers or buffers that couldn't be written by :wa.)
local function has_modified_listed_buffers()
  local bufs = vim.fn.getbufinfo({ buflisted = 1 })
  for _, b in ipairs(bufs) do
    if b.changed == 1 then
      return true
    end
  end
  return false
end

-- Open Telescope's projects picker and override <CR> to perform a "hard switch":
-- save session -> clear workspace -> cd -> load new session.
function M.pick_and_switch(opts)
  opts = vim.tbl_deep_extend("force", {}, defaults, opts or {})

  -- Be defensive: if users don't have the deps installed, just no-op instead of erroring.
  local ok_telescope, telescope = pcall(require, "telescope")
  if not ok_telescope then return end

  local ok_actions, actions = pcall(require, "telescope.actions")
  if not ok_actions then return end

  local ok_state, action_state = pcall(require, "telescope.actions.state")
  if not ok_state then return end

  -- Safe to call multiple times; loads the extension if available.
  pcall(function()
    telescope.load_extension("projects")
  end)

  telescope.extensions.projects.projects({
    attach_mappings = function(prompt_bufnr, map)
      local function switch_project()
        -- Grab selected entry *before* closing Telescope.
        local entry = action_state.get_selected_entry()
        actions.close(prompt_bufnr)

        -- project.nvim entries usually put the project path in `value` (sometimes `path`).
        local path = entry and (entry.value or entry.path) or nil
        if not path or path == "" then return end

        -- Save files to disk (like :wa). This does NOT save unnamed/scratch buffers.
        if opts.save_before_switch then
          pcall(function() vim.cmd("silent! wa") end)
        end

        -- Save session for current working directory.
        -- This stores buffers/tabs/windows so you can come back later.
        pcall(function()
          require("persistence").save()
        end)

        -- If anything is still modified, optionally ask before discarding.
        local force_discard = false
        if opts.save_prompt and has_modified_listed_buffers() then
          local choice = vim.fn.confirm(
            "You have unsaved buffers. Switch projects anyway?",
            "&Cancel\n&Switch (discard)",
            1
          )
          if choice ~= 2 then
            return
          end
          force_discard = true
        end

        -- Clear workspace (tabs + buffers), so you don't "mix" projects.
        if opts.clear_tabs then
          pcall(function() vim.cmd("silent! tabonly") end)
        end

        -- If user chose to discard, force wipe. Otherwise, be safe and don't force-close modified buffers.
        if force_discard then
          pcall(function() vim.cmd("silent! %bd!") end)
        else
          pcall(function() vim.cmd("silent! %bd") end)
        end

        -- Switch to the new project root.
        vim.cmd("cd " .. vim.fn.fnameescape(path))

        -- if nvim-tree is installed/open, re-root it to the new cwd.
        -- This fixes the tree still showing the older project issue after a :cd
        if opts.sync_nvim_tree then
          pcall(function()
            local api = require("nvim-tree.api")
            api.tree.change_root(vim.loop.cwd())
          end)
        end

        -- Restore that project's session (per cwd).
        pcall(function()
          require("persistence").load()
        end)
      end

      -- Make Enter switch projects in both insert and normal mode within Telescope.
      map("i", "<CR>", switch_project)
      map("n", "<CR>", switch_project)
      return true
    end,
  })
end

-- Public entrypoint. Usually called from your Neovim config.
-- Sets up the default keymap (unless disabled).
function M.setup(opts)
  opts = vim.tbl_deep_extend("force", {}, defaults, opts or {})

  if opts.set_default_keymap then
    vim.keymap.set("n", opts.keymap, function()
      -- Pass opts through so overrides (like save_prompt=false) apply to the keymap too.
      M.pick_and_switch(opts)
    end, { desc = "Find projects (switch + restore session)" })
  end
end

return M
