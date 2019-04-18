local menu = {}

local font, font_lg
local title = "robohobo"
local title_width
local title_dir = 1
local title_x = 0
local title_speed = 10 -- in pixels per second
local width, height
local engine
local running = 0
local titlescreen_timeout = 3

local logo_db



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
		"Credits",
		function()
			print("credits selected")
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
		menu_select = math.max(menu_select - 1, 1)
	end
end

local function on_key_down(ev)
	if ev.value ~= 0 then
		menu_select = math.min(menu_select + 1, #menu)
	end
end

local function on_key_enter(ev)
	if ev.value ~= 0 then
		menu[menu_select][2]()
	end
end


-- called when the calculations should be done
function menu:update(dt)
	running = running + dt
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





function hslToRgb(h, s, l)
  local r, g, b

  if s == 0 then
    r, g, b = l, l, l -- achromatic
  else
    function hue2rgb(p, q, t)
      if t < 0   then t = t + 1 end
      if t > 1   then t = t - 1 end
      if t < 1/6 then return p + (q - p) * 6 * t end
      if t < 1/2 then return q end
      if t < 2/3 then return p + (q - p) * (2/3 - t) * 6 end
      return p
    end

    local q
    if l < 0.5 then q = l * (1 + s) else q = l + s - l * s end
    local p = 2 * l - q

    r = hue2rgb(p, q, h + 1/3)
    g = hue2rgb(p, q, h)
    b = hue2rgb(p, q, h - 1/3)
  end

  return r * 255, g * 255, b * 255
end




-- called when the image is about to be drawn with the output drawbuffer
function menu:draw(db)
	if running >= titlescreen_timeout then
		db:clear(0,0,0,255)
		font_lg:draw_string(db, title, math.floor(title_x), 0)
		db:set_line(0, 16, width-1, 16, 255,0,0,255)
		
		for i, entry in ipairs(menu) do
			font:draw_string(db, entry[1], 8, 40+(i-1)*16)
		end
		
		db:set_line(8, 48+(menu_select-1)*16, width-1, 48+(menu_select-1)*16, 0,255,0,255)
	else
		local pct = running / titlescreen_timeout
		local g = math.floor(pct*255)
		db:clear(g,g,g,255)
		
		local scale = 2
		local target_x = math.floor((width-scale*logo_db:width())/2)
		local target_y = math.floor((height-scale*logo_db:height())/2)
		logo_db:draw_to_drawbuffer(db, target_x, target_y, 0,0, logo_db:width(), logo_db:height(), scale)
		
		local r,g,b = hslToRgb(running*2%1, 1, 0.5)
		db:set_rectangle(0, height*(5/6), width, height*(4/6), r,g,b,255)
		
		if pct < 0.5 then
			font_lg:draw_string(db, "FOR LGJ", 0, height-16)
		else
			font_lg:draw_string(db, "BY MAX1220", 0, height-16)
		end
		
	end
end

local input = require("lua-input")

function menu:init()
	font = self:load_font("cga8")
	font_lg = self:load_font("cga8_lg")
	
	logo_db = self:load_img("logo.raw", 64, 64)
	
	
	title_width = font_lg:string_size(title)
	
	width, height = self.config.output.width, self.config.output.height
	
	self:set_input_callback(input.event_codes.KEY_UP, on_key_up)
	self:set_input_callback(input.event_codes.KEY_DOWN, on_key_down)
	self:set_input_callback(input.event_codes.KEY_ENTER, on_key_enter)
	
	engine = self
end


return menu
