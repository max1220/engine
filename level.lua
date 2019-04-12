local level = {
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
			y = 80,
			w = 30,
			h = 5
		}

	}
}
local cx = 100
for i=1, 100 do
	local rect = {
		type = "collider"
	}
	rect.x = cx + math.random(1,30)
	rect.y = 80 + math.random(-30, 30)
	rect.w = math.random(10, 60)
	rect.h = math.random(5, 15)
	cx = cx + rect.w
	table.insert(level.world_data, rect)
end

return level
