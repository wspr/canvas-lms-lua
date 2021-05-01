--[================[
      CANVAS-LMS
--]================]

--- User interface for managing Canvas LMS courses using its REST API.
-- There is a single table used in an object-like way for interacting with a single Canvas course.
-- The functions below are stored within the canvas table and store their data and metadata in the same table.
-- @module canvas

local canvas = {}

local function copy_functions(name)
  local new = require(name)
  for k,v in pairs(new) do
    canvas[k] = v
  end
end

 copy_functions("canvas-lms.config")
copy_functions("canvas-lms.http")
copy_functions("canvas-lms.students")
copy_functions("canvas-lms.assign")
copy_functions("canvas-lms.rubrics")
copy_functions("canvas-lms.grades")
copy_functions("canvas-lms.message")
copy_functions("canvas-lms.announcements")
copy_functions("canvas-lms.modules-pages")
copy_functions("canvas-lms.discuss")
copy_functions("canvas-lms.files")

return canvas
