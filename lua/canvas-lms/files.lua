--- Canvas LMS in Lua: Files
-- @submodule canvas

local canvas = {}


--- Get files.
-- Data stored in: `.files` table indexed by `filename` of the file.
-- @function get_files
-- Code for this function uses the generic `define_getter` function in the HTTP submodule.


function canvas:update_file(filename,opt)

  if(self.files==nil) then
    self:get_files()
  end

  local id = self.files[filename].id
  if id == nil then
    error("Filename '"..filename"' not found.")
  end

  self:put("files/"..id,opt)

end

return canvas
