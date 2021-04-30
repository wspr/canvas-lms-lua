--[================[
      CANVAS-LMS
--]================]

--- User interface for managing Canvas LMS courses using its REST API.
-- There is a single table used in an object-like way for interacting with a single Canvas course.
-- The functions below are stored within the canvas table and store their data and metadata in the same table.
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
require("canvas-lms-files")

return canvas
