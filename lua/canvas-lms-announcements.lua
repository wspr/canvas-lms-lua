

canvas.get_announcements = function(self)

  tmp = self:get(self.course_prefix.."discussion_topics",{only_announcements=true})

  self.announcements = {}
  for i,j in ipairs(tmp) do

    self.announcements[j.id] = j

  end

end
