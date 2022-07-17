--- Canvas LMS in Lua: Announcements
-- @submodule canvas
local canvas = {}


--- Update metadata for a single announcement.
function canvas:update_announcement(title,opt)

  self:get_announcements{download="cache"}

  local id = self.announcements[title].id
  if id == nil then
    error("Announcement '"..title"' not found.")
  end

  self:put(self.course_prefix.."discussion_topics/"..id,opt)

end

return canvas
