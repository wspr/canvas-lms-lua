--- Canvas LMS in Lua: Grades and gradebook
-- @submodule canvas

local tablex   = require("pl.tablex")

local canvas = {}

--- Retrieve and store the names and IDs of any added custom gradebook columns
function canvas:get_grade_columns()

  local xx = self:get_paginated(true,self.course_prefix .. "custom_gradebook_columns")
  self.custom_gradebook_columns = xx

  self.custom_gradebook_column_ids = self.custom_gradebook_column_ids or {}

  for _,j in ipairs(self.custom_gradebook_columns) do
    self.custom_gradebook_column_ids[j.title] = j.id
  end

end


--- Create custom gradebook columns
-- Currently this function only creates, not updates!
function canvas:setup_grade_columns(columns)

  self:get_grade_columns()

  local curr_cols = {}
  for _,j in ipairs(self.custom_gradebook_columns) do
    curr_cols[j.title] = true
  end

  for i,j in ipairs(columns) do
    local column = j
    column.position = i
    if curr_cols[column.title] == nil then
      self:post(self.course_prefix.."custom_gradebook_columns",{column=column})
    end
  end

end


--- Delete all custom gradebook columns -- warning!
function canvas:delete_grade_columns()

  print("About to delete all custom gradebook columns, are you sure? Type y to do so:")
  if io.read() == "y" then
    self:get_grade_columns()
    for _,j in ipairs(self.custom_gradebook_columns) do
      self:delete(self.course_prefix.."custom_gradebook_columns/"..j.id)
    end
  end

end


--- Retrieve and store grades from specified assignments
function canvas:get_assign_grades(opt)

  local get_switch = opt.download or "ask"
  local assign_names = opt.assignments

  for _,assign_name in ipairs(assign_names) do
    local download_check = "y"
    if get_switch == "ask" then
      print("Download grades for assignment '"..assign_name.."'? Type y to do so:")
      download_check = io.read()
    elseif get_switch == "never" then
      download_check = "n"
    end
    local assign = self:get_assignment_ungrouped(download_check=="y",assign_name)
    for _,j in pairs(assign) do
      if self.students_cid[j.user_id] then
        self.students_cid[j.user_id].grades = self.students_cid[j.user_id].grades or {}
        self.students_cid[j.user_id].grades[assign_name] = j.grade
      end
    end

  end

  return self.students_cid

end


--- Write grades to CSV from specified assignments
function canvas:write_grades(gfile,assign_names)

  self.get_assignments{force=false}

  print("Writing gradebook data to file '"..gfile.."'")

  local students_by_name = {}
  for k,v in pairs(self.students_cid) do
    students_by_name[v.sortable_name] = k
  end

  io.output(gfile)

  io.write("Name,ID,")
  for _,assign_name in ipairs(assign_names) do
    io.write(assign_name..",")
  end
  io.write("\n")

  io.write("Max Points,,")
  for _,v in ipairs(assign_names) do
    if self.assignments[v] then
      io.write(self.assignments[v].points_possible..",")
    end
  end
  io.write("\n")

  for _,student_cid in tablex.sort(students_by_name) do
    io.write('"'..self.students_cid[student_cid].sortable_name..'",')
    io.write(self.students_cid[student_cid].sis_user_id..",")
    for _,assign_name in ipairs(assign_names) do
      if self.students_cid[student_cid].grades then
        io.write((self.students_cid[student_cid].grades[assign_name] or "")..",")
      end
    end
    io.write("\n")
  end


end



return canvas
