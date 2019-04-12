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
	local player_db
	if player.velocity_x == 0 then
		if player.dir == "right" then
			player_db = player.drawbuffers.standing_right[1]
		elseif player.dir == "left" then
			player_db = player.drawbuffers.standing_left[1]
		end
	else
		if player.dir == "right" then
			player_db = player.drawbuffers.walking_right[1]
		elseif player.dir == "left" then
			player_db = player.drawbuffers.walking_left[1]
		end
	end
	local screen_x, screen_y = world_to_screen_coords(player.x, player.y)	
	player_db:draw_to_drawbuffer(db, screen_x, screen_y, 0, 0, player_db:width(), player_db:height())
end


-- create a bullet from the player, towards x,y
local bullets = {}
local function player_shoot(dx,dy)
	local bullet = {
		x = player.x,
		y = player.y + 5,
		w = 1,
		h = 1,
		dx = dx,
		dy = dy,
		speed = 60
	}
	
	if dx > 0 then
		bullet.x = bullet.x + player.width + 5
	else
		bullet.x = bullet.x - 5
	end
	
	world.physics_world:add(bullet, bullet.x, bullet.y, bullet.w, bullet.h)
	table.insert(bullets, bullet)
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
		player.dir = "left"
	end
	if engine:key_is_down(input.event_codes.KEY_RIGHT) then
		player.velocity_x = player.speed_x
		player.dir = "right"
	end
	if engine:key_is_down(input.event_codes.KEY_SPACE) then
		if player.can_shoot then
			if player.dir == "right" then
				player_shoot(1, 0)
			elseif player.dir == "right" then
				player_shoot(-1, 0)
			end
		end
	end
	
	-- Apply gravity
	player.velocity_y = player.velocity_y + player.gravity * dt
	
	-- apply fricton
	if player.is_on_ground then
		player.velocity_x = player.velocity_x * player.friction_ground
	else
		player.velocity_x = player.velocity_x * player.friction_air
		--player.velocity_y = player.velocity_y * player.friction_air
	end
	
	if math.abs(player.velocity_x) < 0.01 then
		player.velocity_x = 0
	end
	
	if player.velocity_y ~= 0 then
		player.is_on_ground = false
	end
	if player.velocity_x ~= 0 or player.velocity_y ~= 0 then
		local cols, cols_len
		player.x, player.y, cols, cols_len = world.physics_world:move(player, player.x + player.velocity_x * dt, player.y + player.velocity_y * dt, colission_filter)
		for i=1, cols_len do
			local col = cols[i]
			if col.normal.y ~= 0 then			
				player.is_on_ground = true
				player.velocity_y = 0
			end
			if col.normal.x ~= 0 then
				player.velocity_x = 0
			end
			
			-- print(("col.other = %s, col.type = %s, col.normal = %d,%d"):format(col.other, col.type, col.normal.x, col.normal.y))
		end
	end
	
	
end


-- update bullet positions, handle collisions
local function update_bullets(dt)
	for i, bullet in ipairs(bullets) do
		local cols, cols_len
		bullet.x, bullet.y, cols, cols_len = world.physics_world:move(bullet, bullet.x + bullet.dx*bullet.speed*dt, bullet.y + bullet.dy*bullet.speed*dt, colission_filter)
		for j=1, cols_len do
			local col = cols[j]
			player.can_shoot = true
			table.remove(bullets, i)
			world.physics_world:remove(bullet)
			return
		end
	end
end


local function draw_bullets(db)
	for i, bullet in ipairs(bullets) do
		local screen_x, screen_y = world_to_screen_coords(bullet.x, bullet.y)
		local last_x, last_y = world_to_screen_coords(bullet.x - bullet.dx*bullet.speed*0.1, bullet.y - bullet.dy*bullet.speed*0.1)
		db:set_line(screen_x, screen_y, last_x, last_y, 0,0,255,255)
		-- db:set_pixel(screen_x, screen_y, 0,0,255,255)
	end
end


-- called when the calculations should be done
function game:update(dt)
	fps = 1/dt
	update_player(dt)
	scroll_x = -(player.x) + (width/2)
	
	update_bullets(dt)
	
	if player.y > height+player.height then
		self:change_stage("menu")
	end
	print("\n\n\n#player.bullets:" .. #bullets .. "     ")
end

-- called when the image is about to be drawn with the output drawbuffer
function game:draw(db)
	db:clear(10,10,10,255)
	
	-- draw the world
	world:draw(db, scroll_x, scroll_y)
	
	-- draw player
	draw_player(db)
	
	-- draw bullets
	draw_bullets(db)
	
	-- draw ui ontop
	font:draw_string(db, (" FPS: %.3f "):format(fps), 0, 0)
end



function game:init()
	font = self:load_font("cga8")
	local level = require("level")
	
	engine = self
	
	width = self.config.output.width
	height = self.config.output.height
	
	player = {
		x = level.spawn_x,
		y = level.spawn_y,
		width = 8,
		height = 24,
		can_shoot = true,
		velocity_y = level.spawn_velocity_x,
		velocity_x = level.spawn_velocity_y,
		speed_x = 40,
		dir = "right",
		jump_height = 40,
		gravity = 50,
		friction_air = 0.99,
		friction_ground = 0.75,
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
	
end


return game
