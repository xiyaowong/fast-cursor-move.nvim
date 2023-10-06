local fn = vim.fn
local api = vim.api

local ACCELERATION_LIMIT = 150
local ACCELERATION_TABLE_VERTICAL = { 7, 14, 20, 26, 31, 36, 40 }
local ACCELERATION_TABLE_HORIZONTAL = { 10, 15, 20 }
if vim.g.vscode then
	ACCELERATION_TABLE_VERTICAL = { 7, 14, 20, 26 }
end

---VSCode's cursorMove
---@param direction "j" | "k"
---@param step integer
---@return string
local function vscode_move(direction, step)
	local to, by
	local value = step
	local curr_lnum = fn.line(".")
	if direction == "j" then
		to = "down"
		by = "wrappedLine"
		value = math.min(fn.line("$") - curr_lnum, step)
	elseif direction == "k" then
		to = "up"
		by = "wrappedLine"
		value = math.min(curr_lnum - 1, step)
	else
		return step .. direction -- won't happen
	end
	if value > 0 then
		fn.VSCodeNotify("cursorMove", { to = to, by = by, value = step })
	end
	return "<esc>" -- ! need this to clear v:count in vscode
end

-- Main logic

local get_move_step = (function()
	local prev_direction
	local prev_time = 0
	local move_count = 0
	return function(direction)
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

---@param direction "h" | "j" | "k" | "l"
---@return "h" | "gj" | "gk" | "l"
local function get_move_chars(direction)
	if direction == "j" then
		return "gj"
	elseif direction == "k" then
		return "gk"
	else
		return direction
	end
end

local function move(direction)
	local move_chars = get_move_chars(direction)

	if fn.reg_recording() ~= "" or fn.reg_executing() ~= "" then
		return move_chars
	end

	local is_normal = api.nvim_get_mode().mode:lower() == "n"
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

local function setup()
	for _, motion in ipairs({ "h", "j", "k", "l" }) do
		vim.keymap.set({ "n", "v" }, motion, function()
			return move(motion)
		end, { expr = true })
	end
end

vim.defer_fn(setup, 500)
