local ldb = require("lua-db")
local lfb = require("lua-fb")
local sdl2fb = require("sdl2fb")
local time = require("time")
local input = require("lua-input")



-- the engine loads a stage, and is responisble for it's interactions with
-- input/output devices.
local Engine = {}


-- engine.new appends the engine infrastructure to the loaded stage, making the stage ready to run
function Engine.new(stage, config)

	-- create the output drawbuffer of required size
	local out_db = ldb.new(config.output.width, config.output.height)

	-- called when an input is received from a uinput keyboard
	local input_callbacks = {}
	local function handle_uinput_keyboard_ev(ev, config)
		if ev.type == input.event_codes.EV_KEY then
			if input_callbacks[ev.code] then
				input_callbacks[ev.code](ev)
			end
		end
	end


	-- open input devices
	local input_devs = {}
	for k, input_dev_config in ipairs(config.input) do
		if input_dev_config.type == "keyboard" and input_dev_config.driver == "uinput" then
			local dev = assert(input.open(input_dev_config.dev, true))
			table.insert(input_devs, {dev, input_dev_config, handle_uinput_keyboard_ev})
		end
	end

	
	-- get upper-left coodinate of a centered box on the terminal
	local next_update = 0
	local center_x, center_y
	local function get_center(out_w, out_h)
		if time.realtime() >= next_update then
			local term_w,term_h = ldb.term.get_screen_size()
			local _center_x = math.floor((term_w - out_w) / 2)
			local _center_y = math.floor((term_h - out_h) / 2)
			if center_x == _center_x and center_y == _center_y then
				return _center_x, _center_y
			end
			center_x = _center_x
			center_y = _center_y
			
			-- only update screen size every 5s
			-- TODO: value from config
			next_update = time.realtime() + 5
		end
		return center_x, center_y
	end


	-- output a list of lines as returned by braile/blocks
	local function output_lines(lines, w, h)
		local center_x, center_y = get_center(w, h)
		for i, line in ipairs(lines) do
			io.write(ldb.term.set_cursor(center_x, center_y+i-1))
			io.write(line)
			io.write(ldb.term.reset_color())
			io.write("\n")
		end
		io.flush()
	end


	-- called with the final drawbuffer that should be scaled and displayed
	local _scaled_db
	local function scale_db(db)
		local out_db = db
		if config.output.scale then
			_scaled_db = _scaled_db or ldb.new(config.output.width * config.output.scale, config.output.height * config.output.scale)
			db:draw_to_drawbuffer(_scaled_db, 0, 0, 0, 0, db:width(), db:height(), config.output.scale)
			out_db = _scaled_db
		end
		return out_db
	end
	
	
	-- final output to the terminal
	local function output_braile(db)
		local lines = ldb.braile.draw_db_precise(db, config.output.threshold, 45, true, config.output.bpp24)
		output_lines(lines, math.floor(out_db:width()/2), math.floor(out_db:height()/4))
	end
	
	-- final output to the terminal
	local function output_blocks(db)
		local lines = ldb.blocks.draw_db(db)
		output_lines(lines, out_db:width(), out_db:height())
	end
	
	
	-- final output to the sdl2 window
	local sdl_window
	local function output_sdl2(db)
		sdl_window:draw_from_drawbuffer(db, 0, 0)
	end
	
	-- final output to the framebuffer
	local fb_dev
	local fb_info
	local function output_fb(db)
		local center_x = math.floor((fb_info.xres-db:width()) / 2)
		local center_y = math.floor((fb_info.yres-db:height()) / 2)
		fb_dev:draw_from_drawbuffer(db, center_x, center_y)
	end
	
	local output
	if config.output.type == "braile" then
		output = output_braile
	elseif config.output.type == "blocks" then
		output = output_blocks
	elseif config.output.type:match("^fb=(.*)$") then
		fb_dev = lfb.new(config.output.type:match("^fb=(.*)$"))
		fb_info = fb_dev:get_varinfo()
		output = output_fb
	elseif config.output.type == "sdl2fb" then
		sdl_window = sdl2fb.new(config.output.width, config.output.height, "engine")
		output = output_sdl2
	else
		error("Unsupported output! Check config")
	end
	


	-- loads a font by it's filename
	function stage:load_font(font_name)
		local font_config = assert(config.fonts[font_name])
	
		local font_file = assert(io.open(font_config.bmp, "rb"))
		local font_str = font_file:read("*a")
		local font_db = ldb.bitmap.decode_from_string_drawbuffer(font_str)
		font_file:close()
		local font_header = ldb.bitmap.decode_header(font_str)

		-- create font
		local font = ldb.font.from_drawbuffer(font_db, font_config.char_w, font_config.char_h, font_config.alpha_color, font_config.scale)
		return font
	end

	-- check input devices, call appropriate callbacks
	function stage:_input()
		for i, input_dev in ipairs(input_devs) do
			local dev, config, handler = unpack(input_dev)
			local ev = dev:read()
			while ev do
				handler(ev, config)
				ev = dev:read()
			end
		end
		
		-- if we have a sdl2 window, check for events
		if sdl_window then
			local ev = sdl_window:pool_event()
			if ev and ev.type == "quit" then
				self.run = false
			end
		end
	end
	
	
	-- set or delete an input callback
	function stage:set_input_callback(key, callback)
		if callback then
			input_callbacks[key] = callback
		else
			input_callbacks[key] = nil
		end
	end
	
	
	-- run until the stage stops
	function stage:_loop()
		local last_update = time.realtime()
		while self.run do
			-- check inputs, call input callbacks
			self:_input()
			
			-- get delta time, call update callback
			local dt = time.realtime() - last_update
			last_update = time.realtime()
			self:update(dt)
			
			-- call draw callback
			self:draw(out_db)
			
			-- scale drawbuffer if necesarry
			local scaled = scale_db(out_db)			
			
			-- output updated buffer
			output(scaled)
		end
	end

	function stage:start()
		stage.config = config
		self:init()
		self.run = true
		self:_loop()
		
		-- loop has terminated, call cleanup
		self:stop()
	end

	function stage:stop()
		if sdl_window then
			sdl_window:close()
		end
	end
	
	
	return stage
end

return Engine
