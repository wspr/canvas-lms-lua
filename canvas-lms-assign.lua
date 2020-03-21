
local binser = require("binser")
local pretty = require("pl.pretty")
local date   = require("pl.date")

canvas.setup_assignment_groups = function(self,assign_groups)

  print("# Setting up assignment groups")

  local assign_grps = self:get_pages(true,self.course_prefix.."assignment_groups")
  local grp_hash = {}
  for ii,vv in ipairs(assign_grps) do
    grp_hash[vv.name] = vv.id
  end

  for ii,vv in ipairs(assign_groups) do
    local opt = "position="..ii
    for kkk,vvv in pairs(vv) do
      opt = opt .. "&" .. kkk .. "=" .. vvv
    end

    if grp_hash[vv.name] then
      canvas:put(self.course_prefix.."assignment_groups/"..grp_hash[vv.name],opt)
    else
      xx = canvas:post(self.course_prefix.."assignment_groups",opt)
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
  local cache_file = "cache/"..cache_name..".lua"

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








canvas.create_assign = function(self,args)
--[[
    ARGS:
    group_category
    day
    unlockhr
    duehr
    lockhr
    published
--]]

  if not(args.points) then
    error("Need to specify 'points' this assignment is worth.")
  end

  if args.group_category then
    local group_proj_id = self.student_group_category[args.student_group_category]
    if not(group_proj_id) then
      error("Student group category not found")
    end
  end

  local argday = args.day or 0
  if type(argday) == "string" then
    if argday == "mon"  then argday = 0 end
    if argday == "tue"  then argday = 1 end
    if argday == "wed"  then argday = 2 end
    if argday == "thu"  then argday = 3 end
    if argday == "fri"  then argday = 4 end
    if argday == "sat"  then argday = 5 end
    if argday == "sun"  then argday = 6 end
  end

  local argtype = arg.type or "online_upload"

  local duehr    = args.duehr    or "15"
  local lockhr   = args.lockhr   or "17"
  local unlockhr = args.unlockhr or "08"

  local wkoffset = args.week
  if wkoffset > self.sem_break_week[args.sem] then wkoffset = wkoffset + 2 end

  local datef = date.Format 'yyyy-mm-dd'

  local today_date = date{}
  local todaystr   = datef:tostring(today_date)

  local dayoffset = argday+7*(wkoffset-1)

  local duedate     = date(self.sem_first_monday[args.sem]):add{day=dayoffset}
  local duedatestr  = datef:tostring(duedate).."T"..duehr..":00:00"
  local duediff     = today_date.time - duedate.time

  local lockdate    = date(self.sem_first_monday[args.sem]):add{day=dayoffset}
  local lockdatestr = datef:tostring(lockdate).."T"..lockhr..":00:00"

  local dd = date(self.sem_first_monday[args.sem]):add{day=dayoffset}
  local unlockdate = dd:add{day=-5}
  local unlockdatestr = datef:tostring(unlockdate).."T"..unlockhr..":00:00"

  local new_assign = {
    assignment =  {
                                      name = args.name            ,
                                    due_at = duedatestr           ,
                                   lock_at = lockdatestr          ,
                                 unlock_at = unlockdatestr        ,
                                 published = args.published or "true" ,
                           points_possible = args.points          ,
                          submission_types = argtype              ,
                       assignment_group_id = self.assignment_groups[args.assign_group] ,
                  }
  }
  if argtype == "online_upload" then
    new_assign.assignment.allowed_extensions = arg.ext or "pdf"
  end
  if args.rubric then
    new_assign.assignment.use_rubric_for_grading = "true"
  end
  if args.group_category then
    new_assign.assignment.group_category_id = group_proj_id
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

  if duediff >= 0 then
    print("Assignment due in the past; skipping")
  else
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
    if args.rubric then print("ASSIGN RUBRIC: "..args.rubric) end
    local rubric_id = self.rubric_ids[args.rubric]
    if rubric_id then
      self:assoc_rubric{rubric_id = rubric_id, assign_id = assign_id}
    end
  end

end


