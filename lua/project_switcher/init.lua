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

local M = {}

-- Defaults are merged with user opts in setup() and pick_and_switch().
local defaults = {
  set_default_keymap = true,
  keymap = "<leader>pp",

  -- Behavior knobs
  save_prompt = true,         -- prompt if there are modified buffers before discarding
  save_before_switch = true,  -- run :wa before switching (tries to write all files)
  clear_tabs = true,          -- run :tabonly before clearing buffers
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

        -- 1) Save files to disk (like :wa). This does NOT save unnamed/scratch buffers.
        if opts.save_before_switch then
          pcall(function() vim.cmd("silent! wa") end)
        end

        -- 2) Save session for current working directory.
        -- This stores buffers/tabs/windows so you can come back later.
        pcall(function()
          require("persistence").save()
        end)

        -- 3) If anything is still modified, optionally ask before discarding.
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

        -- 4) Clear workspace (tabs + buffers), so you don't "mix" projects.
        if opts.clear_tabs then
          pcall(function() vim.cmd("silent! tabonly") end)
        end

        -- If user chose to discard, force wipe. Otherwise, be safe and don't force-close modified buffers.
        if force_discard then
          pcall(function() vim.cmd("silent! %bd!") end)
        else
          pcall(function() vim.cmd("silent! %bd") end)
        end

        -- 5) Switch to the new project root.
        vim.cmd("cd " .. vim.fn.fnameescape(path))

        -- 6) Restore that project's session (per cwd).
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
