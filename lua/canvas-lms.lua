
--[================[
      CANVAS-LMS
--]================]

--- "User" "interface" for managing Canvas LMS courses using its REST API
-- @module canvas

canvas = canvas or {}

require("canvas-lms-config")
require("canvas-lms-http")
require("canvas-lms-students")
require("canvas-lms-assign")
require("canvas-lms-rubrics")
require("canvas-lms-grades")
require("canvas-lms-message")
require("canvas-lms-announcements")
require("canvas-lms-modules-pages")
require("canvas-lms-discuss")

return canvas
