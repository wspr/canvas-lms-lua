--- Canvas LMS in Lua: Announcements
-- @submodule canvas
local canvas = {}

canvas.get_announcements = function(self)

  local tmp = self:get(self.course_prefix.."discussion_topics",{only_announcements=true})

  self.announcements = {}
  for _,j in ipairs(tmp) do

    self.announcements[j.id] = j

  end

end

return canvas
