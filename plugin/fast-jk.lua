local fn = vim.fn

local function vscode_move(direction, step)
	fn.VSCodeNotify("cursorMove", { to = direction == "j" and "down" or "up", by = "wrappedLine", value = step })
	return "<esc>" -- ! need this to clear v:count in vscode
end

-- Main logic
local prev_direction
local prev_time = 0
local move_count = 0
local ACCELERATION_TABLE = { 6, 12, 17, 21, 24, 27, 30, 33 }
local ACCELERATION_LIMIT = 150

local function get_step()
	for idx, count in ipairs(ACCELERATION_TABLE) do
		if move_count < count then
			return idx
		end
	end
	return #ACCELERATION_TABLE
end

local function move(direction)
	if fn.reg_recording() ~= "" or fn.reg_executing() ~= "" then
		return "g" .. direction
	end

	if vim.v.count > 0 then
		if vim.g.vscode then
			return vscode_move(direction, vim.v.count)
		else
			return "g" .. direction
		end
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

	local step = get_step()
	if vim.g.vscode then
		return vscode_move(direction, step)
	else
		return step .. "g" .. direction
	end
end

local function setup()
	vim.keymap.set("n", "j", function()
		return move("j")
	end, { expr = true })
	vim.keymap.set("n", "k", function()
		return move("k")
	end, { expr = true })
end

vim.defer_fn(setup, 500)
