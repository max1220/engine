local menu = {}

local font, font_lg
local title = "robohobo"
local title_width
local title_dir = 1
local title_x = 0
local title_speed = 10 -- in pixels per second
local width, height
local engine

local menu = {
	{
		"Start game",
		function()
			engine:change_stage("game")
		end
	},
	{
		"Setup",
		function()
			print("setup selected")
		end
	},
	{
		"Exit",
		function()
			print("exit selected")
			engine.run = false
		end
	}
}
local menu_select = 1

local function on_key_up(ev)
	if ev.value ~= 0 then
		print("up")
		menu_select = math.max(menu_select - 1, 1)
	end
end

local function on_key_down(ev)
	if ev.value ~= 0 then
		print("down")
		menu_select = math.min(menu_select + 1, #menu)
	end
end

local function on_key_enter(ev)
	if ev.value ~= 0 then
		print("Selected item number;", menu_select)
		menu[menu_select][2]()
	end
end


-- called when the calculations should be done
function menu:update(dt)
	if title_dir == 1 then
		title_x = title_x + dt*title_speed
		if title_x + title_width > width then
			title_dir = 2
		end
	else
		title_x = title_x - dt*title_speed
		if title_x < 0 then
			title_dir = 1
		end
	end
end

-- called when the image is about to be drawn with the output drawbuffer
function menu:draw(db)
	db:clear(0,0,0,255)
	font_lg:draw_string(db, title, math.floor(title_x), 0)
	db:set_line(0, 16, width-1, 16, 255,0,0,255)
	
	for i, entry in ipairs(menu) do
		font:draw_string(db, entry[1], 8, 40+(i-1)*16)
	end
	
	db:set_line(8, 48+(menu_select-1)*16, width-1, 48+(menu_select-1)*16, 0,255,0,255)
	
end

local input = require("lua-input")

function menu:init()
	font = self:load_font("cga8")
	font_lg = self:load_font("cga8_lg")
	
	title_width = font_lg:string_size(title)
	
	width, height = self.config.output.width, self.config.output.height
	
	self:set_input_callback(input.event_codes.KEY_UP, on_key_up)
	self:set_input_callback(input.event_codes.KEY_DOWN, on_key_down)
	self:set_input_callback(input.event_codes.KEY_ENTER, on_key_enter)
	
	engine = self
	
	print("loaded menu stage!")
end


return menu
