local Date   = require("pl.tablex")

canvas.assign_grades = function(self,get_switch,assign_names,students_by_cid)

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
      if students_by_cid[j.user_id] then
        students_by_cid[j.user_id].grades = students_by_cid[j.user_id].grades or {}
        students_by_cid[j.user_id].grades[assign_name] = j.score
      end
    end

  end

  return students_by_cid

end



canvas.write_grades = function(self,gfile,assign_names,all_assign_byname,students_by_cid)

  print("Writing gradebook data to file '"..gfile.."'")

  local students_by_name = {}
  for k,v in pairs(students_by_cid) do
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
    io.write('"'..students_by_cid[student_cid].sortable_name..'",')
    io.write(students_by_cid[student_cid].sis_user_id..",")
    for i,assign_name in ipairs(assign_names) do
      if students_by_cid[student_cid].grades then
        io.write((students_by_cid[student_cid].grades[assign_name] or "")..",")
      end
    end
    io.write("\n")
  end


end



return canvas
