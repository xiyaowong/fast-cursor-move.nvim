local api = vim.api
local fn = vim.fn

local basic_move

-- Main logic
local prev_direction
local prev_time = 0
local move_count = 0
local ACCELERATION_TABLE = { 6, 12, 17, 21, 24, 26, 28, 30 }
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
	if vim.v.count > 0 then
		return basic_move(direction, vim.v.count)
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
	basic_move(direction, step)
end

local function setup()
	if vim.g.vscode then
		basic_move = function(direction, step)
			fn.VSCodeNotify(
				"cursorMove",
				{ to = direction == "j" and "down" or "up", by = "wrappedLine", value = step }
			)
		end
	else
		basic_move = function(direction, step)
			api.nvim_feedkeys(step .. "g" .. direction, "n", true)
		end
	end
	vim.keymap.set("n", "j", function()
		move("j")
	end)
	vim.keymap.set("n", "k", function()
		move("k")
	end)
end

vim.defer_fn(setup, 500)
