-- Options:
-- vim.g.fast_cursor_move_acceleration -> Set it to fasle to disable the acceleration behaviour

---@type integer
---@alias ACCELERATION_LIMIT integer
local ACCELERATION_LIMIT = 150
---@type integer[]
---@alias ACCELERATION_TABLE_VERTICAL integer[]
local ACCELERATION_TABLE_VERTICAL = { 5, 10, 15, 17, 20, 24, 26, 32 }
---@type integer[]
---@alias ACCELERATION_TABLE_HORIZONTAL integer[]
local ACCELERATION_TABLE_HORIZONTAL = { 6, 10, 15, 20 }
if vim.g.vscode then
	---@type table<7, 14, 20, 26>
	---@alias ACCELERATION_TABLE_VERTICAL_VSCODE integer[]
	ACCELERATION_TABLE_VERTICAL = { 5, 10, 15, 17, 20 }
end

---@alias void nil
---@alias SingleKeys "h" | "j" | "k" | "l" | "gj" | "gk"
---@alias StandardKeys "h" | "j" | "k" | "l"
---@alias ModKeys "h" | "gj" | "gk" | "l"
---
---@class Modes
---@field n string | void : "n"
---@field v string | void : "v"
---

---@class Keys
---@field keys table<SingleKeys> | void : SingleKeys[]

---
---@class KeymapSettings
---@field expr boolean | void : true
---@field noremap boolean | void : true
---@field silent boolean | void : true
---@field nowait boolean | void : true
---@field buffer boolean | void : true
---@field script boolean | void : true
---
---@class Configuration
---@field acceleration_limit integer | void : ACCELERATION_LIMIT
---@field acceleration_table_vertical integer[] | void : ACCELERATION_TABLE_VERTICAL
---@field acceleration_table_horizontal integer[] | void : ACCELERATION_TABLE_HORIZONTAL
---
---@class Opts
---@field configuration Configuration | void : Configuration
---@field default_keys SingleKeys<"h" | "j" | "k" | "l">[] | void : Keys[]
---@field defer_time integer | void : 500
---@field fast_cursor_move_acceleration boolean | void : false
---@field keymap_settings KeymapSettings | void : KeymapSettings
---@field modes table<"n", "v"> | void : Modes[]
---@field vscode boolean | void : true
---@type Opts
local defaults = {
	---@type Configuration
	configuration = {
		---@type integer
		acceleration_limit = ACCELERATION_LIMIT,
		---@type ACCELERATION_TABLE_VERTICAL
		acceleration_table_vertical = ACCELERATION_TABLE_VERTICAL,
		---@type ACCELERATION_TABLE_HORIZONTAL
		acceleration_table_horizontal = ACCELERATION_TABLE_HORIZONTAL,
	},
	---@type SingleKeys<"h" | "j" | "k" | "l">
	default_keys = { "h", "j", "k", "l" },
	---@type Modes
	modes = { "n", "v" },
	---@type integer
	defer_time = 500,

	---@type boolean
	fast_cursor_move_acceleration = false,
	---@type KeymapSettings
	keymap_settings = {
		---@type boolean
		expr = true,
		---@type boolean
		noremap = true,
		---@type boolean
		silent = true,
	},
	---@type boolean
	vscode = false,
}

local fn = vim.fn
local api = vim.api

---VSCode's cursorMove
---@param direction SingleKeys
---@param step integer
---@generic T
---@return T SingleKeys | "<esc>
local function vscode_move(direction, step)
	local to, by
	if direction == "j" then
		to = "down"
		by = "wrappedLine"
	elseif direction == "k" then
		to = "up"
		by = "wrappedLine"
	else
		return step .. direction -- won't happen
	end
	fn.VSCodeNotify("cursorMove", { to = to, by = by, value = step })
	return "<esc>" -- ! need this to clear v:count in vscode
end

-- Main logic

local get_move_step = (function()
	---@type StandardKeys
	local prev_direction
	local prev_time = 0
	local move_count = 0

	---@param direction StandardKeys
	return function(direction)
		if vim.g.fast_cursor_move_acceleration == false then
			return 1
		end

		if direction ~= prev_direction then
			prev_time = 0
			move_count = 0
			prev_direction = direction
		else
			local time = vim.loop.hrtime()
			local elapsed = (time - prev_time) / 1e6
			if elapsed > ACCELERATION_LIMIT then
				move_count = 0
			else
				move_count = move_count + 1
			end
			prev_time = time
		end

		local acceleration_table = (
			(direction == "j" or direction == "k") and ACCELERATION_TABLE_VERTICAL or ACCELERATION_TABLE_HORIZONTAL
		)
		-- calc step
		for idx, count in ipairs(acceleration_table) do
			if move_count < count then
				return idx
			end
		end
		return #acceleration_table
	end
end)()

---@param direction StandardKeys
---@return SingleKeys
local function get_move_chars(direction)
	if direction == "j" then
		return "gj"
	elseif direction == "k" then
		return "gk"
	else
		return direction
	end
end

---
---@param direction StandardKeys
---@return SingleKeys
local function move(direction, merged)
	local move_chars = get_move_chars(direction)

	if fn.reg_recording() ~= "" or fn.reg_executing() ~= "" then
		return move_chars
	end

	---@type boolean
	local is_normal = api.nvim_get_mode().mode:lower() == "n"

	---@type boolean
	local use_vscode = merged.vscode and is_normal and direction ~= "h" and direction ~= "l"

	---@type integer
	if vim.v.count > 0 then
		if use_vscode then
			return vscode_move(direction, vim.v.count)
		else
			return move_chars
		end
	end

	---@type integer
	local step = get_move_step(direction)
	---@type string
	if use_vscode then
		return vscode_move(direction, step)
	else
		return step .. move_chars
	end
end

---@param opts Opts
local function setup(opts)
	---@type Opts
	local merged = vim.tbl_deep_extend("force", {}, defaults, opts or {})

	for _, motion in ipairs(merged.default_keys) do
		vim.keymap.set(merged.modes, motion, function()
			return move(motion, merged)
		end, merged.keymap_settings)
	end
end

vim.defer_fn(setup, defaults.defer_time)
