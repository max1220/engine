local input = require("lua-input") -- for event codes, TODO: put in mapping file
local ldb = require("lua-db")

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
local tileset
local assets
local tilemap_db
local background_color = {170,230,240,255}

-- return the screen coordinates for the given world coordinates
local function world_to_screen_coords(world_x, world_y)
	-- TODO: use scroll to calculate
	return math.floor(world_x+scroll_x), math.floor(world_y+scroll_y)
end


-- draw the player on the drawbuffer
local function draw_player(db)
	local player_db
	
	
	-- select correct frame
	-- TODO: animation
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
	screen_x = screen_x - player.offset_x
	screen_y = screen_y - player.offset_y
	player_db:draw_to_drawbuffer(db, screen_x, screen_y, 0, 0, player_db:width(), player_db:height())
end


-- create a bullet from the player, towards x,y
local bullets = {}
local function player_shoot(dt, dx,dy)
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


-- collision filter
local function colission_filter(item, other)
	-- print("colission_filter(item, other)", item, other)
	if other.class == "cloud" then
		-- print("cloud")
		return "cross"
	elseif other.class == "bounce" then
		return "touch"
	end
	
	return "slide"
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
				player_shoot(dt, 1, 0)
			elseif player.dir == "left" then
				player_shoot(dt, -1, 0)
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
				
			if col.other.class == "cloud" then
				print("cloud")
				player.velocity_y = player.velocity_y + 10*dt
			elseif col.other.class == "box" then
				if col.normal.y and col.normal.y == 1 then
					print("box hit")
				end
			elseif col.other.class == "bouncer" then
				player.velocity_y = -100
			end
			if col.normal.y == -1 then			
				player.is_on_ground = true
				player.velocity_y = 0
			elseif col.normal.y == 1 then
				-- collided with top, remove velocity
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
		db:set_line(screen_x, screen_y, last_x, last_y, unpack(bullet.trail or {64, 64, 64, 255}))
		db:set_pixel(screen_x, screen_y,  unpack(bullet.color or {255, 127, 0, 255}))
	end
end


local function draw_bg(db)
	local r,g,b,a = unpack(background_color)
	db:clear(r,g,b,a)
	for i=0, 8 do
		db:set_rectangle(0, height-(8-i)*5, width, 5, r-5*i,g-5*i,b-5*i,a)
	end
end


-- called when the calculations should be done
function game:update(dt)
	fps = 1/dt
	update_player(dt)
	scroll_x = -(player.x) + (width/2)
	scroll_y = -(player.y) + (height/2)
	
	update_bullets(dt)
	
	if player.y > height+player.height then
		self:change_stage("menu")
	end
	-- print("\n\n\n#player.bullets:" .. #bullets .. "     ")
end



local layer_db = ldb.new(10,10)
layer_db:clear(66,0,0,255)

-- called when the image is about to be drawn with the output drawbuffer
function game:draw(db)
	draw_bg(db)
	
	-- draw player
	draw_player(db)
	
	-- draw bullets
	draw_bullets(db)
	
	tilemap_db:draw_to_drawbuffer(db, 0,0, -scroll_x, -scroll_y, width, height)
	
	-- draw the physics world(debug!)
	-- world:draw(db, scroll_x, -scroll_y)
	
	-- draw ui ontop
	font:draw_string(db, (" FPS: %.3f "):format(fps), 0, 0)
end


-- called once when this scene is loaded
function game:init()
	font = self:load_font("cga8")
	local level = require("level")
	
	engine = self
	
	width = self.config.output.width
	height = self.config.output.height
	

	-- load required assets into an asset table
	assets = self:load_assets({
		-- character images
		{
			type = "img",
			name = "char_standing_left",
			file = "char_standing_left.bmp",
			apply_transparency_color = {255,255,255}
		},
		{
			type = "img",
			name = "char_standing_right",
			file = "char_standing_right.bmp",
			apply_transparency_color = {255,255,255}
		},
		{
			type = "img",
			name = "char_walking_left",
			file = "char_walking_left.bmp",
			apply_transparency_color = {255,255,255}
		},
		{
			type = "img",
			name = "char_walking_right",
			file = "char_walking_right.bmp",
			apply_transparency_color = {255,255,255}
		},
		{
			type = "img",
			name = "tileset_img",
			file = "tileset2.png",
			width = 64,
			height = 128
		},
		
		-- other images(fonts etc.)
		{
			type = "img",
			name = "cga8_img",
			file = "cga8.bmp",
			apply_transparency_color = {255,255,255}
		},
		
		-- font
		{
			type = "font",
			name = "cga8",
			db_name = "cga8_img",
			char_w = 8,
			char_h = 8
		},
		
		
		-- tileset
		{
			type = "tileset",
			name = "tileset",
			db_name = "tileset_img",
			tile_w = 8,
			tile_h = 8
		},
		
		
		-- example map
		{
			type = "tiled_map",
			name = "map",
			tileset_name = "tileset",
			file = "img/test_map_2.json"
		
		}
	})








	player = {
		x = level.spawn_x,
		y = level.spawn_y,
		width = 11,
		height = 24,
		offset_x = 11,
		offset_y = 6,
		can_shoot = true,
		velocity_y = level.spawn_velocity_x,
		velocity_x = level.spawn_velocity_y,
		speed_x = 60,
		dir = "right",
		jump_height = 60,
		gravity = 55,
		friction_air = 0.99,
		friction_ground = 0.75,
		drawbuffers = {
			standing_left = {
				assets.by_name.char_standing_left.db
			},
			standing_right = {
				assets.by_name.char_standing_right.db
			},
			walking_left = {
				assets.by_name.char_walking_left.db
			},
			walking_right = {
				assets.by_name.char_walking_right.db
			},
			--[[
			jumping_left = {
				assets.char_standing_left.db
			},
			jumping_right = {
				assets.char_standing_left.db
			},
			falling_left = {
				assets.char_standing_left.db
			},
			falling_right = {
				assets.char_standing_left.db
			}
			]]
		}
	}
	
	
	
	--world = self:new_world(level, player)
	
	-- draw the entire loaded tilemap to a drawbuffer
	tilemap_db = ldb.new(assets.by_name.map.tilemap.tiles_x * assets.by_name.map.tilemap.tileset.tile_w, assets.by_name.map.tilemap.tiles_y * assets.by_name.map.tilemap.tileset.tile_h)
	assets.by_name.map.tilemap:draw(tilemap_db, 0, 0)
	
	local colliders = {}
	
	local ground_colliders = {}
	for i=0, 50 do -- first 51 tileids are ground
		table.insert(ground_colliders, i)
	end
	for _, v in ipairs({56,57,58,64,65,66 }) do -- add extra ground tiles
		table.insert(ground_colliders, v)
	end
	for k,v in ipairs(ground_colliders) do
		colliders[v+1] = "ground"
	end
	colliders[73] = "cloud"
	colliders[74] = "cloud"
	colliders[75] = "cloud"
	colliders[69] = "box"
	colliders[77] = "box"
	colliders[81] = "bouncer"
	
	world = self:new_world(assets.by_name.map.tilemap:generate_level(function(tileid)
		if tileid == 0 or colliders[tileid] == "none" then
			return
		end
		return colliders[tileid] or "none"
	end), player)
	
end


return game
