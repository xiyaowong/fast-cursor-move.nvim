local fn = vim.fn

local function vscode_move(direction, step)
	local to, by
	if direction == "j" then
		to = "down"
		by = "wrappedLine"
	elseif direction == "k" then
		to = "up"
		by = "wrappedLine"
	elseif direction == "h" then
		to = "left"
		by = "character"
	else
		to = "right"
		by = "character"
	end
	fn.VSCodeNotify("cursorMove", { to = to, by = by, value = step })
	return "<esc>" -- ! need this to clear v:count in vscode
end

-- Main logic

local get_move_step = (function()
	local prev_direction
	local prev_time = 0
	local move_count = 0
	local ACCELERATION_TABLE = { 7, 14, 20, 26, 31, 36, 40, 44 }
	local ACCELERATION_LIMIT = 150
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
		-- calc step
		for idx, count in ipairs(ACCELERATION_TABLE) do
			if move_count < count then
				return idx
			end
		end
		return #ACCELERATION_TABLE
	end
end)()

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

	if vim.v.count > 0 then
		if vim.g.vscode then
			return vscode_move(direction, vim.v.count)
		else
			return move_chars
		end
	end

	local step = get_move_step(direction)
	if vim.g.vscode then
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
