# restoration.nvim

**Smart, scoped session management for Neovim.**

Restore your editor exactly as you left it

# ✨ Features

- 🔁 Multiple named sessions per project

- 🌿 Branch-scoped sessions with auto checkout

- 🧠 Auto-restore virtual environments

- 🔍 Search sessions across all projects or just the current dir

- 🧪 Restore extras: breakpoints, quickfix list, watches, undo history

- 🧬 Optional auto-save session on exit

- 🔧 Fully configurable and lazy-load friendly

# 🚀 Installation

Lazy:

```lua
{
    "paradoxical-dev/restoration.nvim",
    event = "BufReadPre", -- optional but recommended
    opts = {
        -- optional config here
    }
}
```

Packer:

```lua
use {
    "olimorris/restoration.nvim",
    config = function()
        require("restoration").setup({
            -- optional config here
        })
    end,
}
```

## Optional Dependencies

- [dap-utils.nvim](https://github.com/niuiic/dap-utils.nvim) for restoring breakpoints and watches
- [quickfix.nvim](https://github.com/niuiic/quickfix.nvim) for restoring the quickfix list
- [snacks.nvim](https://github.com/folke/snacks.nvim) to use the snacks picker

# 🛠️ Configuration

Default options are shown below

```lua
require("restoration").setup({
	-- overwrite current session on exit
	auto_save = true,
	notify = true,
	-- extra aspects of the user session to preserve
	preserve = {
		breakpoints = false, -- requires dap-utils.nvim
		qflist = false, -- requires quickfix.nvim
		undo = false,
		watches = false, -- requires dap-utils.nvim
	},
	branch_scope = true, -- store per branch sessions for git repos
	-- detects and adds venv to vim.env,PATH before loading session
	restore_venv = {
		enabled = true,
		patterns = { "venv", ".venv" }, -- patterns to match against for venv
	},
	picker = {
		default = "vim", -- vim|snacks
		vim = {
			icons = {
				project = "",
				session = "󰑏",
				branch = "",
			},
		},
		snacks = {
			-- can be any snacks preset layout or custom layout table
			-- see https://github.com/folke/snacks.nvim/blob/main/docs/picker.md#%EF%B8%8F-layouts
			layout = "default",
			icons = {
				project = "",
				session = "󰑏",
				branch = "",
			},
			hl = {
				base_dir = "SnacksPickerDir",
				project_dir = "Directory",
				session = "SnacksPickerBold",
				branch = "SnacksPickerGitBranch",
			},
		},
	},
})

```

> [!NOTE]
> The defualt vim picker uses `vim.ui.select()`. If this is the default value it is recommended (but not required) to use a plugin like [dressing.nvim](https://github.com/stevearc/dressing.nvim) for the best experience

Example config:

```lua
require("restoration").setup({
    auto_save = false
    preserve = {
        breakpoints = true,
        qflist = true,
        undo = true,
        watches = true
    },
    picker = { default = "snacks" }
})
```

# 📦 Lua API

The API is exposed via the `require("restoration")` module and is fairly simple to implement.

```lua
-- Opens the picker to select across all projects
require("restoration").select()

-- Select within the current dir
require("restoration").select({ cwd = true })

-- Save the current session
require("restoration").save()

-- Restore last session
require("restoration").load({ latest = true })

-- Select a session to rename
-- If already within a session will prompt to overwrite the current
require("restoration").rename()

-- Behaves the same as `rename` but deletes the session
require("restoration").delete()

-- Same as `delete` but deletes entire project
require("restoration").delete_project()
```

> [!TIP]
> All sessions are stored the neovim state path `vim.fn.stdpath("state")` under the restoration directory
>
> Session files will be stored within in the following format: `<project path>/<session name>/<session name>.vim`

## ️⌨️ Example Mappings

```lua
vim.keymap.set("n", "<leader>ss", function()
    require("restoration").select()
end, { desc = "Select Session" })

vim.keymap.set("n", "<leader>sc", function()
    require("restoration").select({ cwd = true })
end, { desc = "Select Session in Current Dir" })

vim.keymap.set("n", "<leader>sl", function()
    require("restoration").load({ latest = true })
end, { desc = "Restore Last Session" })
```

# 🗂️ Extras Restored

If enabled within the config, restoration can restore the following extras:

- 🐞 `nvim-dap` breakpoints & watches
- ❗ Quickfix list
- ⏪ Undo history (:rundo)

See [Optional Dependencies](#optional-dependencies) section for more info on requirements

## 🧠 Virtual Environments

If enabled, restoration will automatically detect virtual environments and add them to `vim.env.PATH` before restoring sessions.

If already within a session, restoration will also restart LSP servers before restoring to ensure the correct environment is used.

Users also have the ability to match against custom patterns to detect virtual environments.

> [!NOTE]
> Patterns will be matched against the base project directory

## 🌿 Git Branch Scopes

restoration also has the ability to store sessions per branch for git repos.

Each session wihin a new branch will be stored under the project name and the branch name.

When loading a branch session, restoration will automatically switch the branch before restoring the session.

# 👀 Inspirations

- [persistence.nvim](https://github.com/folke/persistence.nvim)
- [multiple-sessions.nvim](https://github.com/niuiic/multiple-session.nvim)
- [lvim-space](https://github.com/lvim-tech/lvim-space)
