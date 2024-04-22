-- Options:
-- vim.g.fast_cursor_move_acceleration -> Set it to fasle to disable the acceleration behaviour

local fn = vim.fn
local api = vim.api

---@type integer
---@alias ACCELERATION_LIMIT integer
local ACCELERATION_LIMIT = 150
---@type integer[]
---@alias ACCELERATION_TABLE_VERTICAL integer[]
local ACCELERATION_TABLE_VERTICAL = { 7, 14, 20, 26, 31, 36, 40 }
---@type integer[]
---@alias ACCELERATION_TABLE_HORIZONTAL integer[]
local ACCELERATION_TABLE_HORIZONTAL = { 10, 15, 20 }
if vim.g.vscode then
	---@type table<7, 14, 20, 26>
	---@alias ACCELERATION_TABLE_VERTICAL_VSCODE integer[]
	ACCELERATION_TABLE_VERTICAL = { 7, 14, 20, 26 }
end

---@alias void nil
---
---@class Modes
---@field n string | void : "n"
---@field v string | void : "v"
---
---@class Keys<K>
---@field K string | void : K
--
---@alias H "h"
---@alias J "j"
---@alias K "k"
---@alias L "l"
---@alias GJ "gj"
---@alias GK "gk"
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
---@field default_keys Keys<"h" | "j" | "k" | "l">[] | void : Keys[]
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
	---@type Keys<"h" | "j" | "k" | "l">[]
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

--
---@enum VsCodeMovements
---@alias VsCodeMethod "cursorMove"
---@generic S
---@alias VSCodeNotify fun(method: VsCodeMethod, args: table<S, any>): void

--
---@class VsCodeArgs
---@field to "down" | "up"
---@field by "wrappedLine"
---@field value integer
--
--
--
---@type fun(direction: "j" | "k", step: integer): string
---@alias by "wrappedLine"
---@generic S : string
---@alias to "down" | "up" | S
---
---@generic K : Keys<"h" | "j" | "k" | "l">
---@param direction K
---@param step integer
---@return string
---@type fun(direction: "j" | "k", step: integer): string | fun(direction: "h" | "l", step: integer): string
local function vscode_move(direction, step)
	local to, by
	if direction == "j" then
		---@type to
		to = "down"
		---@type by
		by = "wrappedLine"
	elseif direction == "k" then
		---@type to
		to = "up"
		---@type by
		by = "wrappedLine"
	else
		return step .. direction -- won't happen
	end
	fn.VSCodeNotify("cursorMove", { to = to, by = by, value = step })
	return "<esc>" -- ! need this to clear v:count in vscode
end

-- Main logic
--
---@alias D fun(K): integer
---@generic D : D<K>
---@alias inner_func fun(D: K): integer
---@return inner_func
---@type fun(): inner_func
--
---@type fun(): fun(K): integer
---@return fun(K): integer
local get_move_step = (function()
	local prev_direction
	local prev_time = 0
	local move_count = 0

	--
	---@generic K
	---@param direction K
	---@return integer
	---@type fun(direction: K): integer
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

---@generic K : Keys<"h" | "j" | "k" | "l">
---@param direction K
---@return Keys<"h" | "gj" | "gk" | "l">
local function get_move_chars(direction)
	if direction == "j" then
		return "gj"
	elseif direction == "k" then
		return "gk"
	else
		return direction
	end
end

---@generic K : Keys<"h" | "j" | "k" | "l">
---@param direction K
local function move(direction)
	---@type Keys | "h" | "gj" | "gk" | "l"
	local move_chars = get_move_chars(direction)

	if fn.reg_recording() ~= "" or fn.reg_executing() ~= "" then
		return move_chars
	end

	---@type boolean
	---@alias is_normal boolean
	local is_normal = api.nvim_get_mode().mode:lower() == "n"
	---@type boolean
	---@alias use_vscode boolean
	local use_vscode = vim.g.vscode and is_normal and direction ~= "h" and direction ~= "l"

	if vim.v.count > 0 then
		if use_vscode then
			return vscode_move(direction, vim.v.count)
		else
			return move_chars
		end
	end

	local step = get_move_step(direction)
	if use_vscode then
		return vscode_move(direction, step)
	else
		return step .. move_chars
	end
end

---

local function setup(opts)
	---@type Opts
	local merged = vim.tbl_deep_extend("force", defaults, opts)
	local map_settings = merged.keymap_settings

	for _, motion in ipairs(merged.default_keys) do
		vim.keymap.set(merged.modes, motion, function()
			return move(motion)
		end, map_settings)
	end
end

vim.defer_fn(setup, defaults.defer_time)
