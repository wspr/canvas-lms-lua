
local binser = require("binser")
local pretty = require("pl.pretty")
local date   = require("pl.date")

canvas.setup_assignment_groups = function(self,args)

  print("# Setting up assignment groups")

  local assign_groups = {}
  local any_weights = false
  for ii,vv in ipairs(args) do
    assign_groups[ii] = {}
    assign_groups[ii].position = ii
    assign_groups[ii].name = vv.name
    assign_groups[ii].group_weight = vv.weight or vv.group_weight or 0
    if assign_groups[ii].group_weight > 0 then
      any_weights = true
    end
  end

  if any_weights then
    self:put(self.course_prefix,{course={apply_assignment_group_weights="true"}})
  end

  local assign_grps = self:get_pages(true,self.course_prefix.."assignment_groups")
  local grp_hash = {}
  for ii,vv in ipairs(assign_grps) do
    grp_hash[vv.name] = vv.id
  end

  for ii,vv in ipairs(assign_groups) do
    if grp_hash[vv.name] then
      self:put(self.course_prefix.."assignment_groups/"..grp_hash[vv.name],vv)
    else
      xx = self:post(self.course_prefix.."assignment_groups",vv)
      grp_hash[xx.name] = xx.id
    end
  end

  print("## ASSIGNMENT GROUPS")
  pretty.dump(grp_hash)

  local Nmarks = 0
  for ii,vv in ipairs(assign_groups) do
    Nmarks = Nmarks + vv.group_weight
  end
  print("TOTAL MARKS: "..Nmarks)

  self.assignment_groups = grp_hash

end



canvas.get_assignment_list = function(self,opt)

  local opt = opt or {}
  local get_bool = opt.download or false
  local print_list = opt.print or false

  local all_assign = canvas:get_pages(get_bool,canvas.course_prefix.."assignments")
  local all_assign_byname = {}
  if opt.print then print("# ASSIGNMENT LIST") end
  for k,v in pairs(all_assign) do
    if opt.print then print(" • "..v.name) end
    all_assign_byname[v.name] = v
  end

  return all_assign_byname
end


canvas.get_assignments = function(self)

  print("# Getting assignments currently in Canvas")

  local all_assign = canvas:get_pages(true,self.course_prefix.."assignments")
  local assign_hash = {}
  for ii,vv in ipairs(all_assign) do
    assign_hash[vv.name] = vv.id
  end

  self.assignments = all_assign
  self.assignment_ids = assign_hash

  print("## ASSIGNMENTS - .assignment_ids ")
  pretty.dump(self.assignment_ids)

end




canvas.get_assignment = function(self,use_cache_bool,assign_name,assign_opts)
  return canvas:get_assignment_generic(use_cache_bool,assign_name,assign_opts,"Assign "..assign_name)
end

canvas.get_assignment_ungrouped = function(self,use_cache_bool,assign_name,assign_opts)
  return canvas:get_assignment_generic(use_cache_bool,assign_name,assign_opts,"Assign "..assign_name.." Ungrouped")
end

canvas.get_assignment_generic = function(self,use_cache_bool,assign_name,assign_opts,cache_name)

  local cache_name = cache_name or assign_name
  local cache_file = canvas.cache_dir..cache_name..".lua"

  if use_cache_bool then

    canvas_data = self:get(self.course_prefix .. "assignments","search_term=" .. assign_name)
    assign_id = canvas_data[1]["id"]

    print('ASSIGNMENT NAME: '..assign_name)
    print('ASSIGNMENT ID:   '..assign_id)
    print('GETTING SUBMISSIONS:')
    local canvas_sub = canvas:get_pages(true,self.course_prefix .. "assignments/" .. assign_id .. "/submissions",assign_opts)
    print("(" .. #canvas_sub .. " submissions)")

    local to_remove = {}
    for i,j in ipairs(canvas_sub) do
      if (j.attempt==nil or j.workflow_state == "unsubmitted") and (j.score==nil) then
        print("Entry "..i.." to be removed.")
        table.insert(to_remove,i)
      end
    end
    for i = #to_remove, 1, -1 do -- backwards so that indices don't change!
      table.remove(canvas_sub,to_remove[i])
    end

    binser.writeFile(cache_file,canvas_sub)

  end

  local canvas_sub = binser.readFile(cache_file)
  canvas_sub = canvas_sub[1]

  return canvas_sub

end




local day_string_to_num = function(argday)
  if type(argday) == "string" then
    if argday == "mon"  then argday = 0 end
    if argday == "tue"  then argday = 1 end
    if argday == "wed"  then argday = 2 end
    if argday == "thu"  then argday = 3 end
    if argday == "fri"  then argday = 4 end
    if argday == "sat"  then argday = 5 end
    if argday == "sun"  then argday = 6 end
  end
  return argday
end



canvas.create_assign = function(self,args)
--[[
    ARGS:
    group_category
    day
    open_days
    late_days
    unlockhr / unlocktime
    duehr / unlocktime
    lockhr / unlocktime
    published
    sem
    assign_type = one of {"online_quiz","none","on_paper","discussion_topic","external_tool"}
    omit_from_final_grade
}
--]]

  local sem = args.sem or 1

  if not(args.points) then
    error("Need to specify 'points' this assignment is worth.")
  end

  local group_proj_id = nil
  if args.student_group_category then
    group_proj_id = self.student_group_category[args.student_group_category]
    if not(group_proj_id) then
      error("Student group category not found")
    else
      print("Student group category: "..group_proj_id)
    end
  end

  local argday = args.day or 0
  argday = day_string_to_num(argday)

  args.open_days = args.open_days or 5
  args.late_days = args.late_days or 0

  local argtypes_allowed = {"online_quiz","none","on_paper","discussion_topic","external_tool","online_upload","online_text_entry","online_url","media_recording"}
  args.assign_type = args.assign_type or "online_upload"
  do
    local arg_bad = true
    for ii,vv in ipairs(argtypes_allowed) do
      if args.assign_type == vv then arg_bad = false end
    end
    if arg_bad then
      print("The 'assign_type' option for creating assignments can be one of:")
      pretty.dump(argtypes_allowed)
      error("Bad argument for 'assign_type'.")
    end
  end

  local duehr       = args.duehr    or "15"
  local lockhr      = args.lockhr   or "17"
  local unlockhr    = args.unlockhr or "08"
  local duetime     = duehr..":00:00"
  local locktime    = lockhr..":00:00"
  local unlocktime  = unlockhr..":00:00"

  if duehr == "24" then
    duetime = "23:59:00"
  end
  if unlockhr == "24" then
    unlocktime = "23:59:00"
  end
  if lockhr == "24" then
    locktime = "23:59:00"
  end

  local wkoffset = args.week
  if self.sem_break_week[sem] > 0 and self.sem_break_length[sem] > 0 then
    if wkoffset > self.sem_break_week[sem] then
      wkoffset = wkoffset + self.sem_break_length[sem]
    end
  end

  local datef = date.Format 'yyyy-mm-dd'

  local today_date    = date{}
  local todaystr      = datef:tostring(today_date)
  local dayoffset     = argday+7*(wkoffset-1)

  local duedate       = date(self.sem_first_monday[sem]):add{day=dayoffset}
  local duedatestr    = datef:tostring(duedate).."T"..duetime
  local duediff       = today_date.time - duedate.time

  local lockdate      = date(self.sem_first_monday[sem]):add{day=dayoffset+args.late_days}
  local lockdatestr   = datef:tostring(lockdate).."T"..locktime
  local lockdiff      = today_date.time - lockdate.time

  local unlockdate    = date(self.sem_first_monday[sem]):add{day=dayoffset-args.open_days}
  local unlockdatestr = datef:tostring(unlockdate).."T"..unlocktime
  local unlockdiff    = today_date.time - unlockdate.time

  local new_assign = {
    assignment =  {
                                      name = args.name            ,
                                    due_at = duedatestr           ,
                                   lock_at = lockdatestr          ,
                                 unlock_at = unlockdatestr        ,
                                 published = args.published or "true" ,
                           points_possible = args.points          ,
                          submission_types = args.assign_type     ,
                       assignment_group_id = self.assignment_groups[args.assign_group] ,
                  }
  }
  if arg.type == "online_upload" then
    new_assign.assignment.allowed_extensions = arg.ext or "pdf"
  end
  if args.rubric then
    new_assign.assignment.use_rubric_for_grading = "true"
  end
  if group_proj_id then
    new_assign.assignment.group_category_id = group_proj_id
  end
  if arg.omit_from_final_grade then
    new_assign.assignment.omit_from_final_grade = arg.omit_from_final_grade
  end

  local descr_filename = args.descr
  if descr_filename then
    descr_html = nil
    do
      local f = assert(io.open("assign_details/"..descr_filename, "r"))
      descr_html = f:read("*all")
      f:close()
    end
    descr_html = descr_html:gsub("\n","")
    new_assign.assignment.description = descr_html
  end
  pretty.dump(new_assign)

  local diffcontinue = true
  if lockdiff >= 0 then
    print("Assignment already locked for students; aborting assignment creation/update.")
    diffcontinue = false
  else
    if unlockdiff >= 0 then
      print("Assignment already unlocked for students, are you sure?")
      print("Type y to proceed:")
      local check = io.read()
      diffcontinue = check == "y"
    end
  end

  if diffcontinue then
    local assign_id = self.assignment_ids[args.name]
    print("## "..args.name)
    local a
    if assign_id then
      a = canvas:put(self.course_prefix.."assignments/"..assign_id,new_assign)
    else
      a = canvas:post(self.course_prefix.."assignments",new_assign)
      self.assignment_ids[args.name] = a.id
    end
    if a.errors then
      pretty.dump(a)
      error("Create/update assignment failed")
    end

    -- RUBRIC
    if args.rubric then
      print("ASSIGN RUBRIC: "..args.rubric)
      local rubric_id = self.rubric_ids[args.rubric]
      if rubric_id then
        self:assoc_rubric{rubric_id = rubric_id, assign_id = assign_id}
      end
    end
  end

end


