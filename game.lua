local input = require("lua-input") -- for event codes, TODO: put in mapping file

-- the structure that holds all the callbacks
local game = {}

local font
local width, height
local engine
local fps
local player
local scroll_x, scroll_y = 0,0
local scroll_speed = 50
local world


-- return the screen coordinates for the given world coordinates
local function world_to_screen_coords(world_x, world_y)
	-- TODO: use scroll to calculate
	return math.floor(world_x+scroll_x), math.floor(world_y+scroll_y)
end


-- draw the player on the drawbuffer
local function draw_player(db)
	local player_db = player.drawbuffers[player.state][1]
	local screen_x, screen_y = world_to_screen_coords(player.x, player.y)	
	player_db:draw_to_drawbuffer(db, screen_x, screen_y, 0, 0, player_db:width(), player_db:height())
end


-- update player position etc. based on physics
local function update_player(dt)

	if engine:key_is_down(input.event_codes.KEY_UP) then
		if player.is_on_ground then
			player.velocity_y = -player.jump_height
		end
	end
	if engine:key_is_down(input.event_codes.KEY_LEFT) then
		player.velocity_x = -player.speed_x
	end
	if engine:key_is_down(input.event_codes.KEY_RIGHT) then
		player.velocity_x = player.speed_x
	end
	
	if player.velocity_x > 1 then
		player.state = "walking_right"
	elseif player.velocity_x < -1 then
		player.state = "walking_left"
	elseif player.state == "walking_left" then
		player.state = "standing_left"
	elseif player.state == "walking_right" then
		player.state = "standing_right"
	end
	
	-- Apply gravity
	player.velocity_y = player.velocity_y + player.gravity * dt
	
	-- apply fricton
	if player.is_on_ground then
		player.velocity_x = player.velocity_x * player.friction_ground
	else
		player.velocity_x = player.velocity_x * player.friction_air
		player.velocity_y = player.velocity_y * player.friction_air
	end
	
	if player.velocity_y ~= 0 then
		player.is_on_ground = false
	end
	if player.velocity_x ~= 0 or player.velocity_y ~= 0 then
		local cols
		player.x, player.y, cols, cols_len = world.physics_world:move(player, player.x + player.velocity_x * dt, player.y + player.velocity_y * dt)
		for i=1, cols_len do
			local col = cols[i]
			player.is_on_ground = true
			player.velocity_y = 0
			print(("col.other = %s, col.type = %s, col.normal = %d,%d"):format(col.other, col.type, col.normal.x, col.normal.y))
		end
	end
	
	
end



-- called when the calculations should be done
function game:update(dt)
	fps = 1/dt
	update_player(dt)
	scroll_x = -(player.x) + (width/2)
	
	if self:key_is_down(input.event_codes.KEY_A) then
		scroll_x = scroll_x + dt*scroll_speed
	elseif self:key_is_down(input.event_codes.KEY_D) then
		scroll_x = scroll_x - dt*scroll_speed
	end
	
end

-- called when the image is about to be drawn with the output drawbuffer
function game:draw(db)
	db:clear(10,10,10,255)
	
	-- draw the world
	world:draw(db, scroll_x, scroll_y)
	
	-- draw player
	draw_player(db)
	
	-- draw ui ontop
	font:draw_string(db, (" FPS: %.3f "):format(fps), 0, 0)
end



function game:init()
	font = self:load_font("cga8")
	
	engine = self
	
	width = self.config.output.width
	height = self.config.output.height
	
	player = {
		x = 0,
		y = 0,
		width = 8,
		height = 24,
		velocity_y = 20,
		velocity_x = 20,
		speed_x = 20,
		current_db = nil,
		state = "standing_right",
		jump_height = 40,
		gravity = 50,
		friction_air = 0.99999,
		friction_ground = 0.9,
		drawbuffers = {
			standing_left = {
				self:load_img("char_standing_left.bmp")
			},
			standing_right = {
				self:load_img("char_standing_right.bmp")
			},
			walking_left = {
				self:load_img("char_walking_left.bmp")
			},
			walking_right = {
				self:load_img("char_walking_right.bmp")
			},
			jumping_left = {
				self:load_img("char_standing_left.bmp")
			},
			jumping_right = {
				self:load_img("char_standing_right.bmp")
			},
			falling_left = {
				self:load_img("char_walking_left.bmp")
			},
			falling_right = {
				self:load_img("char_walking_right.bmp")
			}
		}
	}
	
	local level = require("level")
	world = self:new_world(level, player)
	
	-- todo: build asset loader
	self:apply_transparency_color(player.drawbuffers.standing_right[1], 255,255,255)
	player.drawbuffers.standing_right[1] = self:crop(player.drawbuffers.standing_right[1], 12,6, 8,24)
	
	self:apply_transparency_color(player.drawbuffers.standing_left[1], 255,255,255)
	player.drawbuffers.standing_left[1] = self:crop(player.drawbuffers.standing_left[1], 12,6, 8,24)
	
	self:apply_transparency_color(player.drawbuffers.walking_left[1], 255,255,255)
	player.drawbuffers.walking_left[1] = self:crop(player.drawbuffers.walking_left[1], 12,6, 8,24)
	
	self:apply_transparency_color(player.drawbuffers.walking_right[1], 255,255,255)
	player.drawbuffers.walking_right[1] = self:crop(player.drawbuffers.walking_right[1], 12,6, 8,24)
	
	print("loaded game stage!")
end


return game
