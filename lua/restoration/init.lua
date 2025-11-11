local M = {}
local pickers = require("restoration.pickers")
local state = require("restoration.state")
local utils = require("restoration.utils")
local session_dir = utils.session_dir
local uv = vim.uv or vim.loop

M.config = {
	-- overwrite current session on exit
	auto_save = true,
	notify = true,
	-- extra aspects of the user session to preserve
	preserve = {
		breakpoints = false, -- requires dap-utils.nvim
		qflist = false, -- requires quickfix.nvim
		undo = false,
		watches = false, -- requires dap-utils.nvim
		folds = false,
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
}

M.active_session = false

---@param opts? table
M.select = function(opts)
	local default_picker = M.config.picker.default
	local picker_options = M.config.picker[default_picker]

	if opts and opts.cwd == true then
		local cwd = vim.fn.getcwd()
		local project = cwd:gsub("[\\/:]+", "%%")
		if M.config.branch_scope and utils.is_repo(cwd) then
			picker_options.preview = function(ctx)
				pickers.git_preview(cwd, ctx)
			end
			pickers[default_picker]("branches", project, picker_options, { repo = true })
			return
		end
		pickers[default_picker]("sessions", project, picker_options)
		return
	end

	if opts then
		picker_options.rename = opts.rename
		picker_options.delete = opts.delete
		picker_options.delete_project = opts.delete_project
		print(vim.inspect(picker_options))
		pickers[default_picker]("projects", nil, picker_options)
		return
	end

	pickers[default_picker]("projects", nil, picker_options)
end

---@param opts table
---@param project string
---@param session string
---@param branch? string
M.load = function(opts, project, session, branch)
	local s
	if opts and opts.latest then
		s = state.load()
		if not s then
			return
		end
		project, session, branch = s.project, s.session, s.branch
	end

	if not (project and session) or session == "" then
		return
	end

	local path
	if branch and M.config.branch_scope then
		path = vim.fs.joinpath(session_dir, project, branch, session)
	else
		path = vim.fs.joinpath(session_dir, project, session)
	end

	utils.load_session(path, project, M.config.preserve, branch or nil)
	M.active_session = true

	state.save(project, session, (branch and M.config.branch_scope) and branch or nil)

	if M.config.notify then
		vim.notify("Loaded session: " .. session, vim.log.levels.INFO)
	end
end

---@param auto_save? boolean
M.save = function(auto_save)
	if M.active_session and not auto_save then
		local overwrite = vim.fn.confirm("Overwrite your current session?", "&Yes\n&No", 2)
		if overwrite == 1 then
			local s = state.load()
			if not s then
				vim.notify("Unable to load session details", vim.log.levels.ERROR)
				return
			end

			local session_path = vim.fs.joinpath(session_dir, s.project, s.branch or "", s.session)
			utils.save_session(session_path, M.config.preserve)

			if M.config.notify then
				vim.notify("Saved session as: " .. s.session, vim.log.levels.INFO)
			end
			return
		end
	elseif auto_save and M.active_session then
		local s = state.load()
		if not s then
			vim.notify("Unable to load session details", vim.log.levels.ERROR)
			return
		end

		local session_path = vim.fs.joinpath(session_dir, s.project, s.branch or "", s.session)
		utils.save_session(session_path, M.config.preserve)

		return
	end

	local cwd = vim.fn.getcwd()
	local sanitized_dir = vim.fn.getcwd():gsub("[\\/:]+", "%%")
	local project_dir = vim.fs.joinpath(session_dir, sanitized_dir)

	if not uv.fs_stat(project_dir) then
		vim.fn.mkdir(project_dir, "p")
	end

	vim.ui.input({ prompt = "Session name:" }, function(name)
		if not name or name == "" then
			vim.notify("Session save cancelled", vim.log.levels.WARN)
			return
		end

		local branch = (utils.is_repo(cwd) and M.config.branch_scope) and utils.current_branch(cwd) or nil
		local session_path = vim.fs.joinpath(project_dir, branch or "", name)
		vim.fn.mkdir(session_path, "p")

		utils.save_session(session_path, M.config.preserve)
		state.save(sanitized_dir, name, branch)

		if M.config.notify then
			vim.notify("Saved session as: " .. name, vim.log.levels.INFO)
		end
	end)
end

---@param project string
---@param session string
---@param branch? string
M.delete = function(project, session, branch)
	local overwrite
	if (not project or not session or session == "") and M.active_session then
		local use_current = vim.fn.confirm("Delete current session?", "&Yes\n&No", 2)
		if use_current == 1 then
			overwrite = true
			local s = state.load()
			if not s then
				vim.notify("Unable to load session details", vim.log.levels.ERROR)
				return
			end
			project, session, branch = s.project, s.session, s.branch
		else
			M.select({ delete = true })
			return
		end
	elseif not (project and session) or session == "" then
		M.select({ delete = true })
		return
	end

	local path = vim.fs.joinpath(session_dir, project, branch or "", session)
	local ok = vim.fn.delete(path, "rf")
	if ok ~= 0 then
		vim.notify("Unable to delete session: " .. session, vim.log.levels.ERROR)
		return
	end

	if overwrite then
		state.save("", "", nil)
		M.active_session = false
	end

	if M.config.notify then
		vim.notify("Deleted session: " .. session, vim.log.levels.INFO)
	end
end

---@param project string
M.delete_project = function(project)
	local overwrite
	if (not project or project == "") and M.active_session then
		local use_current = vim.fn.confirm("Delete current project?", "&Yes\n&No", 2)
		if use_current == 1 then
			overwrite = true
			local s = state.load()
			if not s then
				vim.notify("Unable to load session details", vim.log.levels.ERROR)
				return
			end
			project = s.project
		else
			M.select({ delete_project = true })
			return
		end
	elseif not project or project == "" then
		M.select({ delete_project = true })
		return
	end

	local path = vim.fs.joinpath(session_dir, project)
	local ok = vim.fn.delete(path, "rf")
	if ok ~= 0 then
		vim.notify("Unable to delete project: " .. project, vim.log.levels.ERROR)
		return
	end

	if overwrite then
		state.save("", "", nil)
		M.active_session = false
	end

	if M.config.notify then
		project = project:gsub("%%", "/")
		vim.notify("Deleted project: " .. project, vim.log.levels.INFO)
	end
end

---@param project string
---@param session string
---@param branch? string
M.rename = function(project, session, branch)
	local overwrite
	if (not project or not session or session == "") and M.active_session then
		local use_current = vim.fn.confirm("Rename current session?", "&Yes\n&No", 2)
		if use_current == 1 then
			overwrite = true
			local s = state.load()
			if not s then
				vim.notify("Unable to load session details", vim.log.levels.ERROR)
				return
			end
			project, session, branch = s.project, s.session, s.branch
		else
			M.select({ rename = true })
			return
		end
	elseif not (project and session) or session == "" then
		M.select({ rename = true })
		return
	end

	vim.ui.input({ prompt = "New Name" }, function(name)
		if not name or name == "" then
			vim.notify("Session rename cancelled", vim.log.levels.WARN)
			return
		end

		local old_dir = vim.fs.joinpath(session_dir, project, branch or "", session)
		local new_dir = vim.fs.joinpath(session_dir, project, branch or "", name)

		local ok = vim.fn.rename(old_dir, new_dir)
		if ok ~= 0 then
			vim.notify("Unable to rename session folder: " .. old_dir, vim.log.levels.ERROR)
			return
		end

		local old_file = vim.fs.joinpath(new_dir, session .. ".vim")
		local new_file = vim.fs.joinpath(new_dir, name .. ".vim")

		if vim.fn.filereadable(old_file) == 1 then
			vim.fn.rename(old_file, new_file)
		end

		if overwrite then
			state.save(project, name, branch)
		end

		if M.config.notify then
			vim.notify("Renamed session " .. session .. " to: " .. name, vim.log.levels.INFO)
		end
	end)
end

M.setup = function(opts)
	if uv.fs_stat(session_dir) then
		vim.fn.mkdir(session_dir, "p")
	end
	state.file_check()

	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	pickers.branch_scope = M.config.branch_scope
	utils.branch_scope = M.config.branch_scope
	utils.restore_venv = M.config.restore_venv

	if M.config.auto_save then
		vim.api.nvim_create_autocmd("VimLeavePre", {
			callback = function()
				if M.active_session then
					local s = state.load()
					if not s then
						return
					end
					M.save(true)
				end
			end,
		})
	end

	if M.config.preserve.folds then
		local view_group = vim.api.nvim_create_augroup("auto_view", { clear = true })

		vim.api.nvim_create_autocmd({ "BufWinLeave", "BufWritePost", "WinLeave" }, {
			desc = "Save view with mkview for real files",
			group = view_group,
			callback = function(args)
				if vim.b[args.buf].view_activated then
					vim.cmd.mkview({ mods = { emsg_silent = true } })
				end
			end,
		})

		vim.api.nvim_create_autocmd("BufWinEnter", {
			desc = "Try to load file view if available and enable view saving for real files",
			group = view_group,
			callback = function(args)
				if not vim.b[args.buf].view_activated then
					local filetype = vim.api.nvim_get_option_value("filetype", { buf = args.buf })
					local buftype = vim.api.nvim_get_option_value("buftype", { buf = args.buf })
					local ignore_filetypes = { "gitcommit", "gitrebase", "svg", "hgcommit" }
					if
						buftype == ""
						and filetype
						and filetype ~= ""
						and not vim.tbl_contains(ignore_filetypes, filetype)
					then
						vim.b[args.buf].view_activated = true
						vim.cmd.loadview({ mods = { emsg_silent = true } })
					end
				end
			end,
		})
	end
end

return M
