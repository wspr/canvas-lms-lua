--- Canvas LMS in Lua: Announcements
-- @submodule canvas
local canvas = {}

--- Get all announcements.
canvas.get_announcements = function(self)

  local tmp = self:get_paginated(true,self.course_prefix.."discussion_topics",{only_announcements=true})

  self.announcements = {}
  for _,j in ipairs(tmp) do

    self.announcements[j.title] = j

  end

end


--- Update metadata for a single announcement.
function canvas:update_announcement(title,opt)

  if(self.announcements==nil) then
    self:get_announcements()
  end

  local id = self.announcements[title].id
  if id == nil then
    error("Announcement '"..title"' not found.")
  end

  self:put(self.course_prefix.."discussion_topics/"..id,opt)

end

return canvas
