

canvas.set_course_id = function(self,str)
  self.courseid = str
  self.course_prefix = "courses/"..str.."/"
end

canvas.set_url = function(self,str)
  self.url = str
end

canvas.set_token = function(self,str)
  self.token = str
end

canvas.sem_first_monday = {}
canvas.sem_break_week = {}

canvas.set_first_monday = function(self,arg)
  self.sem_first_monday[#self.sem_first_monday+1] = arg
end

canvas.set_break_week = function(self,arg)
  self.sem_break_week[#self.sem_break_week+1] = arg
end

do
  local shared = {
    canvas_url   = function(x) canvas:set_url(x)          end,
    course_id    = function(x) canvas:set_course_id(x)    end,
    token        = function(x) canvas:set_token(x)        end,
    first_monday = function(x) canvas:set_first_monday(x) end,
    break_week   = function(x) canvas:set_break_week(x)   end,
  }
  loadfile('canvas-data.lua', 't', shared)()
end
