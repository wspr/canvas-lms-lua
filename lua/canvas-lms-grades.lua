--- Canvas LMS in Lua: Grades and gradebook
-- @module canvas-grades

local tablex   = require("pl.tablex")
local pretty   = require("pl.pretty")


canvas.get_grade_columns = function(self)

  local xx = canvas:get_pages(true,canvas.course_prefix .. "custom_gradebook_columns")
  self.custom_gradebook_columns = xx

  self.custom_gradebook_column_ids = self.custom_gradebook_column_ids or {}

  for i,j in ipairs(self.custom_gradebook_columns) do
    self.custom_gradebook_column_ids[j.title] = j.id
  end

end


canvas.setup_grade_columns = function(self,columns)

  self:get_grade_columns()

  local curr_cols = {}
  for i,j in ipairs(self.custom_gradebook_columns) do
    curr_cols[j.title] = true
  end

  for i,j in ipairs(columns) do
    local column = j
    column.position = i
    if curr_cols[column.title] == nil then
      xx = self:post(self.course_prefix.."custom_gradebook_columns",{column=column})
    end
  end

end


canvas.delete_grade_columns = function(self)

  self:get_grade_columns()
  for i,j in ipairs(self.custom_gradebook_columns) do
    self:delete(self.course_prefix.."custom_gradebook_columns/"..j.id)
  end

end


canvas.get_assign_grades = function(self,opt)

  get_switch = opt.download or "ask"
  assign_names = opt.assignments

  for i,assign_name in ipairs(assign_names) do
    local download_check = "y"
    if get_switch == "ask" then
      print("Download grades for assignment '"..assign_name.."'? Type y to do so:")
      download_check = io.read()
    elseif get_switch == "never" then
      download_check = "n"
    end
    local assign = self:get_assignment_ungrouped(download_check=="y",assign_name)
    for i,j in pairs(assign) do
      if self.students_cid[j.user_id] then
        self.students_cid[j.user_id].grades = self.students_cid[j.user_id].grades or {}
        self.students_cid[j.user_id].grades[assign_name] = j.grade
      end
    end

  end

  return self.students_cid

end



canvas.write_grades = function(self,gfile,assign_names,all_assign_byname)

  print("Writing gradebook data to file '"..gfile.."'")

  local students_by_name = {}
  for k,v in pairs(self.students_cid) do
    students_by_name[v.sortable_name] = k
  end

  io.output(gfile)

  io.write("Name,ID,")
  for i,assign_name in ipairs(assign_names) do
    io.write(assign_name..",")
  end
  io.write("\n")

  io.write("Max Points,,")
  for i,assign_name in ipairs(assign_names) do
    if all_assign_byname[assign_name] then
      io.write(all_assign_byname[assign_name].points_possible..",")
    end
  end
  io.write("\n")

  for k,student_cid in tablex.sort(students_by_name) do
    io.write('"'..self.students_cid[student_cid].sortable_name..'",')
    io.write(self.students_cid[student_cid].sis_user_id..",")
    for i,assign_name in ipairs(assign_names) do
      if self.students_cid[student_cid].grades then
        io.write((self.students_cid[student_cid].grades[assign_name] or "")..",")
      end
    end
    io.write("\n")
  end


end



return canvas
