--- Canvas LMS in Lua: Students
-- @submodule canvas

local binser = require("binser")
local pretty = require("pl.pretty")

local canvas = {}

--- Find a single user by name or ID.
function canvas:find_user(str)

  local user_data = self:get(self.course_prefix.."users",{search_term=str})

  return user_data

end

--- Get all enrolled students.
function canvas:get_students(opt)

  local optv = opt or {}
  local download_bool = optv.download or false
  if self.students_cid == false then
    download_bool = true
  end

  local students = self:get_paginated(download_bool,self.course_prefix.."users",{["enrollment_type[]"]="student"})

  local students_by_cid = {}
  local students_by_id = {}
  for _,v in pairs(students) do
    students_by_cid[v.id] = v
    students_by_id[v.sis_user_id] = v
  end

  self.students_cid = students_by_cid
  self.students_id  = students_by_id
  return students_by_cid

end


--- Get groups.
function canvas:get_groups(use_cache_bool,group_category_name)

  local cache_path = self.cache_dir.."Group - "..group_category_name..".lua"

  if use_cache_bool then
    local gcats = self:get( self.course_prefix .. "group_categories" )
    local gcat_id = 0;
    for _,j in ipairs(gcats) do
      if j.name == group_category_name then
        gcat_id = j.id
      end
    end
    if gcat_id == 0 then error("oops") end
    print('Group category id for "'..group_category_name..'" = '..gcat_id)
    local canvas_data = self:get_paginated(true, "group_categories/" .. gcat_id .. "/groups" )
    local groups = {}
    for _,j in ipairs(canvas_data) do
      local group_users = self:get( "groups/" .. j.id .. "/users" )
      groups[j.id] = {
                       canvasid   = j.id ,
                       canvasname = j.name ,
                       users      = group_users ,
                     }
    end
    binser.writeFile(cache_path,groups)
  end

  local groups = binser.readFile(cache_path)
  return groups[1]

end

--- Creating group categories.
function canvas:setup_group_categories(categories)

  print("# Setting up student group categories")

  local group_cats = self:get_paginated(true,self.course_prefix.."group_categories")
  local projgrp_hash = {}
  for _,vv in ipairs(group_cats) do
    projgrp_hash[vv.name] = vv.id
  end

  for _,vv in ipairs(categories) do
    if projgrp_hash[vv] == nil then
      local xx = self:post(self.course_prefix.."group_categories","name="..vv)
      projgrp_hash[xx.name] = xx.id
    end
  end

  self.student_group_category = projgrp_hash

  print("## STUDENT GROUP CATEGORIES: .student_group_category =")
  pretty.dump(self.student_group_category)

end

--- Get all group categories.
function canvas:get_student_group_categories()

  print("# Getting student group categories")

  local group_cats = self:get_paginated(true,self.course_prefix.."group_categories")
  local projgrp_hash = {}
  for _,vv in ipairs(group_cats) do
    projgrp_hash[vv.name] = vv.id
  end

  self.student_group_category = projgrp_hash

  print("## STUDENT GROUP CATEGORIES: .student_group_category =")
  pretty.dump(self.student_group_category)

end

return canvas
