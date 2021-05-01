--[================[
      CANVAS-LMS
--]================]

--- User interface for managing Canvas LMS courses using its REST API.
-- There is a single table used in an object-like way for interacting with a single Canvas course.
-- The functions below are stored within the canvas table and store their data and metadata in the same table.
-- @module canvas

local current_folder = (...):gsub('%.init$', '')

local canvas = {}

local function copy_functions(new)
  for k,v in pairs(new) do
    canvas[k] = v
  end
end

copy_functions(require(current_folder .. ".config"))
copy_functions(require(current_folder .. ".http"))
copy_functions(require(current_folder .. ".students"))
copy_functions(require(current_folder .. ".assign"))
copy_functions(require(current_folder .. ".rubrics"))
copy_functions(require(current_folder .. ".grades"))
copy_functions(require(current_folder .. ".message"))
copy_functions(require(current_folder .. ".announcements"))
copy_functions(require(current_folder .. ".modules-pages"))
copy_functions(require(current_folder .. ".discuss"))
copy_functions(require(current_folder .. ".files"))

return canvas
