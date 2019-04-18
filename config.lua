return {
	output = {
		type = "sdl2fb", -- braile, blocks, sdl2fb, fb=/dev/fb0
		bpp24 = true, -- for braile/blocks: output in 24bpp or in 216-colors
		threshold = 45, -- for braile: set the threshold value for a pixel to be drawn using braile character
		width = 160,
		height = 120,
		scale = 4, -- required width, height will double
		target_dt = 1/30 -- if the FPS is higher than this, insert some sleeps to reduce the CPU load
	},
	input = {
		{
			type = "keyboard",
			driver = "uinput",
			dev = "/dev/input/event0",
		},
		{
			type = "keyboard",
			driver = "uinput",
			dev = "/dev/input/event1",
		}
	},
	fonts = {
		cga8 = {
			bmp = "fonts/cga8.bmp",
			char_w = 8,
			char_h = 8,
			alpha_color = {0,0,0},
			scale = 1
		},
		cga8_lg = {
			bmp = "fonts/cga8.bmp",
			char_w = 8,
			char_h = 8,
			alpha_color = {0,0,0},
			scale = 2
		},
	}
}
