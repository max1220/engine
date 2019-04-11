local input = require("lua-input") -- for event codes, TODO: put in mapping file

-- the structure that holds all the callbacks
local game = {}

local font
local width, height
local engine
local fps
local player
local scroll_x, scroll_y



-- return the screen coordinates for the given world coordinates
local function world_to_screen_coords(world_x, world_y)
	-- TODO: use scroll to calculate
	return math.floor(world_x), math.floor(world_y)
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
		if player.velocity_y == 0 then
			player.velocity_y = -player.jump_height
		end
	elseif engine:key_is_down(input.event_codes.KEY_DOWN) then
		print("down")
	elseif engine:key_is_down(input.event_codes.KEY_LEFT) then
		player.velocity_x = -player.speed_x
	elseif engine:key_is_down(input.event_codes.KEY_RIGHT) then
		player.velocity_x = player.speed_x
	end


	if player.y_velocity ~= 0 then
		player.y = player.y + player.velocity_y * dt
		player.velocity_y = player.velocity_y + player.gravity * dt
	end
	
	if player.x_velocity ~= 0 then
		player.x = player.x + player.velocity_x * dt
		player.velocity_x = player.velocity_x * 0.9
	end
	if player.x < 0 then
		player.x = width - player.width
	end
	if player.x > width-player.width then
		player.x = 0
	end
	if math.abs(player.velocity_x) < 0.01 then
		player.velocity_x = 0
	end
	
	print("player.velocity_x", player.velocity_x)
	

	if player.y > player.ground then
		player.velocity_y = 0
    	player.y = player.ground
	end
end


-- called when the calculations should be done
function game:update(dt)
	fps = 1/dt
	update_player(dt)
end

-- called when the image is about to be drawn with the output drawbuffer
function game:draw(db)
	db:clear(0,0,0,255)
	
	-- draw the ground
	db:set_rectangle(0, 80, width, 10, 255,0,0,255)
	
	-- draw player
	draw_player(db)
	
	-- draw ui ontop
	font:draw_string(db, (" FPS: %.3f "):format(fps), 0, 0)
end



function game:init()
	font = self:load_font("cga8")
	
	self:set_input_callback(input.event_codes.KEY_UP, on_key_up)
	self:set_input_callback(input.event_codes.KEY_DOWN, on_key_down)
	self:set_input_callback(input.event_codes.KEY_LEFT, on_key_left)
	self:set_input_callback(input.event_codes.KEY_RIGHT, on_key_right)
	self:set_input_callback(input.event_codes.KEY_ENTER, on_key_enter)
	
	engine = self
	
	width = self.config.output.width
	height = self.config.output.height
	
	player = {
		x = 0,
		y = 0,
		width = 32,
		height = 32,
		velocity_y = 0,
		velocity_x = 0,
		speed_x = 10,
		current_db = nil,
		state = "standing_right",
		jump_height = 20,
		gravity = 20,
		ground = 50,
		drawbuffers = {
			standing_left = {
				self:load_img("char_standing_left.bmp")
			},
			standing_right = {
				self:load_img("char_standing_right.bmp")
			},
			walking_left = {
				self:load_img("robot3.bmp")
			},
			walking_right = {
				self:load_img("robot4.bmp")
			},
			jumping_left = {
				self:load_img("robot5.bmp")
			},
			jumping_right = {
				self:load_img("robot6.bmp")
			},
			falling_left = {
				self:load_img("robot7.bmp")
			},
			falling_right = {
				self:load_img("robot8.bmp")
			}
		}
	}
	
	local function transparency_color(db, tr,tg,tb)
		db:pixel_function(function(x,y,r,g,b,a)
			if tr == r and tg == g and tb == b then
				return r,g,b,0
			end
			return r,g,b,a
		end)
	end
	
	transparency_color(player.drawbuffers.standing_right[1], 255,255,255)
	
	print("loaded game stage!")
end


return game
