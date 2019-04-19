#!/usr/bin/env luajit
local engine = require("engine")
local config = require("config")

-- randomize events
math.randomseed(os.time())

-- overwrite output config values
config.output.type = "braile"
config.output.width = 160
config.output.height = 120
config.output.scale = 2
config.output.threshold = 30

-- load the entry point from the config
local entry = require("menu")
local inst = engine.new(entry, config)

-- start the instance
inst:start()
