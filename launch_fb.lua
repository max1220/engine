#!/usr/bin/env luajit
-- this is the default launch script for the virtual machine.

package.path = package.path .. ";/root/engine/?.lua"
os.execute("cd /root/engine")
os.execute("stty -echo")
print(("\n"):rep(50))

local engine = require("engine")
local config = require("config")

-- overwrite fb config value
config.output.type = "fb=/dev/fb0"
config.output.scale = 5

-- load the entry point from the config
local entry = require("menu")
local inst = engine.new(entry, config)

-- start the instance
inst:start()
