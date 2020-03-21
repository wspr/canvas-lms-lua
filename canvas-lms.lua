
local lfs    = require "lfs"
lfs.mkdir("cache")

canvas = canvas or {}

require("canvas-lms-config")
require("canvas-lms-http")
require("canvas-lms-students")
require("canvas-lms-assign")
require("canvas-lms-rubrics")
require("canvas-lms-grades")
require("canvas-lms-message")

return canvas
