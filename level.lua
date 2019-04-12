local level = {
	spawn_x = 20,
	spawn_y = 20,
	spawn_velocity_x = 20,
	spawn_velocity_y = 20,

	world_data = {
		{
			type = "collider",
			x = 0,
			y = 80,
			w = 50,
			h = 10
		},
		
		{
			type = "collider",
			x = 60,
			y = 00,
			w = 10,
			h = 50
		},

		{
			type = "collider",
			x = 60,
			y = 80,
			w = 50,
			h = 5
		}

	},
	width = 0,
	height = 100
}
local cx = 100
local last_y = 80
for i=1, 100 do
	local rect = {
		type = "collider"
	}
	rect.x = cx + math.random(1,30)
	rect.y = math.max(math.min(last_y + math.random(-10, 10), 100), 20)
	rect.w = math.random(60, 160)
	rect.h = math.random(5, 15)
	cx = cx + rect.w
	last_y = rect.y
	table.insert(level.world_data, rect)
end

return level
