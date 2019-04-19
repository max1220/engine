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
local max_scroll_y = 0
local min_scroll_y = -500
local scroll_speed = 50
local world
local tileset
local assets
local tilemap_db
local background_color = {175,230,245,255}
local clevel



-- initialize colliders table, assigning tile_ids to collision classes
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
colliders[82] = "bouncer"
colliders[83] = "cloud"
colliders[84] = "cloud"
colliders[89] = "goal"
colliders[97] = "goal"




-- return the screen coordinates for the given world coordinates
local function world_to_screen_coords(world_x, world_y)
	-- TODO: use scroll to calculate
	return math.floor(world_x+scroll_x), math.floor(world_y+scroll_y)
end


-- draw the player on the drawbuffer
local function draw_player(db)
	local player_tileset = assets.by_name.char_tiles.tileset
	local tile_id = 0
	
	-- select correct frame
	-- TODO: animation
	if player.velocity_x == 0 then
		if player.dir == "right" then
			tile_id = 2
		elseif player.dir == "left" then
			tile_id = 1
		end
	else
		if player.dir == "right" then
			tile_id = 4
		elseif player.dir == "left" then
			tile_id = 3
		end
	end
	
	if (player.velocity_x ~= 0) and (player.is_on_ground) and (player.runtime*2 % 1) > 0.5 then
		tile_id = tile_id + 4
	end
	
	
	local screen_x, screen_y = world_to_screen_coords(player.x, player.y)
	screen_x = screen_x - player.offset_x
	screen_y = screen_y - player.offset_y
	
	player_tileset.draw_tile(db, screen_x, screen_y, tile_id)
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
		speed = 100,
		gravity = 3
	}
	
	if dx > 0 then
		bullet.x = bullet.x + player.width + 5
	else
		bullet.x = bullet.x - 5
	end
	
	world.physics_world:add(bullet, bullet.x, bullet.y, bullet.w, bullet.h)
	table.insert(bullets, bullet)
	
	player.can_shoot = false
	player.last_shoot = 0
end


-- collision filter
local function colission_filter(item, other)
	-- print("colission_filter(item, other)", item, other)
	if other.class == "cloud" then
		-- print("cloud")
		return "cross"
	elseif other.class == "bounce" then
		return "slide"
	end
	
	return "slide"
end


-- load the next level
local function load_next_level()
	if engine.config._clevel == "map" then
		engine.config._clevel = "map2"
		engine:change_stage("game")
	else
		engine:change_stage("menu")
	end
end


-- update player position etc. based on physics
local function update_player(dt)

	player.last_shoot = player.last_shoot + dt
	player.can_shoot = player.last_shoot >= player.firerate

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
	
	if engine:key_is_down(input.event_codes.KEY_F) then
		local tilemap = assets.by_name.map.tilemap
		tilemap:set_at_layer(tilemap.tile_layers[1], math.floor(player.x/player.width)+2, math.floor(player.y/player.height), 99, world)
	end
	
	
	-- Apply gravity
	player.velocity_y = player.velocity_y + player.gravity * dt
	
	
	-- apply fricton
	if player.is_on_ground then
		player.velocity_x = player.velocity_x - player.velocity_x*player.friction_ground*dt
	else
		player.velocity_x = player.velocity_x - player.velocity_x*player.friction_air*dt
		--player.velocity_x = player.velocity_x * player.friction_ground
	end
	
	if math.abs(player.velocity_x) < 0.01 then
		player.velocity_x = 0
	end
	
	if math.abs(player.velocity_y) > 0.01 then
		player.is_on_ground = false
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
				-- print("cloud")
				player.velocity_y = player.velocity_y + 10*dt
				player.is_on_ground = true
			elseif col.other.class == "box" then
				if col.normal.y and col.normal.y == 1 then
					player.velocity_y = 0
					print("box hit")
				end
			elseif col.other.class == "bouncer" then
				-- print("bouncer")
				player.velocity_y = -80
				player.is_on_ground = false
			elseif col.other.class == "goal" then
				load_next_level()
			elseif col.other.class == "ground" then
				if col.normal.y == -1 then -- player landed on ground
					player.is_on_ground = true
					player.velocity_y = 0
				elseif col.normal.y == 1 then
					-- collided with top, remove velocity
					player.velocity_y = 0
				end
			end
				
			-- print(("col.other = %s, col.type = %s, col.normal = %d,%d"):format(col.other, col.type, col.normal.x, col.normal.y))
		end
	end
	
end


-- update bullet positions, handle collisions
local function update_bullets(dt)
	for i, bullet in ipairs(bullets) do
		local cols, cols_len
		local new_x = bullet.x + bullet.dx*bullet.speed*dt
		local new_y = bullet.y + bullet.dy*bullet.speed*dt+dt*bullet.gravity
		bullet.x, bullet.y, cols, cols_len = world.physics_world:move(bullet, new_x, new_y, colission_filter)
		for j=1, cols_len do
			local col = cols[j]
			player.can_shoot = true
			table.remove(bullets, i)
			world.physics_world:remove(bullet)
			return
		end
	end
end


-- draw bullets and bullet trails
local function draw_bullets(db)
	for i, bullet in ipairs(bullets) do
		local screen_x, screen_y = world_to_screen_coords(bullet.x, bullet.y)
		local last_x, last_y = world_to_screen_coords(bullet.x - bullet.dx*bullet.speed*0.1, bullet.y - bullet.dy*bullet.speed*0.1)
		db:set_line(screen_x, screen_y, last_x, last_y, unpack(bullet.trail or {64, 64, 64, 255}))
		db:set_pixel(screen_x, screen_y,  unpack(bullet.color or {255, 127, 0, 255}))
	end
end



local enemies = {}
local function update_enemies()

end

local function draw_enemies()
	for i, enemy in ipairs(enemies) do
		
	end
end

local function add_enemy(x,y)
	local enemy = {
		hp = 1,
		x = x,
		y = y,
		dir = left
	}
	table.insert(enemies, enemy)
end

local clouds = {}
for i=1, 20 do
	table.insert(clouds, {
		x = math.random(0, 4000),
		y = math.random(0, 30),
		tile_id = math.random(1, 4)
	})
end

local function draw_bg(db)
	local r,g,b,a = unpack(background_color)
	db:clear(r,g,b,a)
	
	for i, cloud in ipairs(clouds) do
		assets.by_name.clouds_tiles.tileset.draw_tile(db, cloud.x+scroll_x/2, cloud.y+scroll_y/8, cloud.tile_id, 2)
	end
	
	local bar_h = math.min(math.floor(scroll_y/3 + 40), 8)
	
	local scroll_pct = ((-scroll_y) / height) * 16
	bar_h = math.floor(scroll_pct)
	
	for i=0, 8 do
		db:set_rectangle(0, height-(8-i)*bar_h, width, bar_h, r-5*i,g-5*i,b-5*i,a)
	end
end


local function load_tilemap()
	-- create tilemap_db that contains the rendered tilemap.
	-- TODO: create 2 tilemap layers, to draw below/above the player
	local tilemap = assets.by_name[engine.config._clevel].tilemap
	
	tilemap_db = ldb.new(tilemap.tiles_x * tilemap.tileset.tile_w, tilemap.tiles_y * tilemap.tileset.tile_h)
	
	-- draw the entire loaded tilemap to a drawbuffer
	tilemap:draw(tilemap_db, 0, 0)
	
	-- adjust min_scroll_y to tilemap height
	min_scroll_y = -tilemap.tiles_y*tilemap.tileset.tile_h
	
	-- create the level data
	local level = tilemap:generate_level(function(tileid)
		if tileid == 0 or colliders[tileid] == "none" then
			return
		end
		return colliders[tileid] or "none"
	end)
	
	-- initialize the player for the level
	player = {
		x = level.spawn_x,
		y = level.spawn_y,
		width = 10,
		height = 24,
		offset_x = 1,
		offset_y = 0,
		can_shoot = true,
		last_shoot = 0,
		firerate = 0.33,
		velocity_y = level.spawn_velocity_x,
		velocity_x = level.spawn_velocity_y,
		speed_x = 60,
		dir = "right",
		jump_height = 64,
		runtime = 0,
		hp = 5,
		gravity = 55,
		friction_air = 5.01,
		friction_ground = 20,
	}
	
	-- create the world, including physics, for the level and player
	world = engine:new_world(level, player)
end


-- called when the calculations should be done
function game:update(dt)
	fps = 1/dt
	update_player(dt)
	scroll_x = -(player.x) + (width/2)
	scroll_y = math.max(math.min(-(player.y) + (height/2), max_scroll_y), min_scroll_y)
	
	player.runtime = player.runtime + dt
	
	update_bullets(dt)
	
	
	
	if assets.by_name.map.tilemap.dirty then
		assets.by_name.map.tilemap:draw(tilemap_db, 0, 0)
	end
	
	if player.y > -min_scroll_y+player.height then
		self:change_stage("menu")
	end
	-- print("\n\n\n#player.bullets:" .. #bullets .. "     ")
	-- print(("fps: %.1d    "):format(fps))
end



local layer_db = ldb.new(10,10)
layer_db:clear(66,0,0,255)

-- called when the image is about to be drawn with the output drawbuffer
function game:draw(db)
	
	-- draw background
	draw_bg(db)
	
	-- draw world
	tilemap_db:draw_to_drawbuffer(db, 0,0, -scroll_x, -scroll_y, width, height)
	
	-- draw player
	draw_player(db)
	
	-- draw bullets
	draw_bullets(db)
	
	-- draw the physics world(debug!)
	-- world:draw(db, scroll_x, -scroll_y)
	
	-- draw ui ontop
	-- font:draw_string(db, (" FPS: %.3f "):format(fps), 0, 0)
end


-- called once when this scene is loaded
function game:init()
	font = self:load_font("cga8")
	
	engine = self
	
	width = self.config.output.width
	height = self.config.output.height
	

	-- load required assets into an asset table
	assets = self:load_assets({
		-- source images for tilesets, fonts
		{
			name = "char_img",
			type = "img",
			file = "char.raw",
			width = 48,
			height = 48
		},
		{
			name = "clouds_img",
			type = "img",
			file = "clouds.raw",
			width = 64,
			height = 16
		},
		{
			name = "tileset_img",
			type = "img",
			file = "tileset2.raw",
			width = 64,
			height = 128
		},
		{
			name = "cga8_img",
			type = "img",
			file = "cga8.bmp",
			apply_transparency_color = {255,255,255}
		},
		
		-- tilesets
		{
			name = "clouds_tiles",
			type = "tileset",
			db_name = "clouds_img",
			tile_w = 16,
			tile_h = 16
		},
		{
			name = "char_tiles",
			type = "tileset",
			db_name = "char_img",
			tile_w = 12,
			tile_h = 24
		},
		{
			name = "tileset",
			type = "tileset",
			db_name = "tileset_img",
			tile_w = 8,
			tile_h = 8
		},
		
		-- fonts
		{
			name = "cga8",
			type = "font",
			db_name = "cga8_img",
			char_w = 8,
			char_h = 8
		},
		
		
		
		
		-- maps
		{
			name = "map",
			type = "tiled_map",
			tileset_name = "tileset",
			file = "img/test_map_2.json"
		
		},
		{
			name = "map2",
			type = "tiled_map",
			tileset_name = "tileset",
			file = "img/test_map_3.json"
		}
		
	})
	
	
	load_tilemap()
	
	
end


return game
