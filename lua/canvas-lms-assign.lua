--- Canvas LMS in Lua: Assignments
-- @submodule canvas

local binser = require("binser")
local pretty = require("pl.pretty")
local date   = require("pl.date")
local path   = require("pl.path")
local markdown = require("markdown")

--- Get assignment groups IDs.
-- Gets details of each assignment group and stores their IDs for later lookup. Data stored in |self.assignment_groups|.
-- @param self
canvas.get_assignment_groups = function(self)

  local assign_grps = self:get_pages(true,self.course_prefix.."assignment_groups")
  local grp_hash = {}
  for ii,vv in ipairs(assign_grps) do
    grp_hash[vv.name] = vv.id
  end
  self.assignment_groups = grp_hash

end

--- Set up assignment groups.
-- @param self
-- @tparam table args setup arguments
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

  if self.assignment_groups == nil then
    self:get_assignment_groups()
  end

  for ii,vv in ipairs(assign_groups) do
    if self.assignment_groups[vv.name] then
      self:put(self.course_prefix.."assignment_groups/"..self.assignment_groups[vv.name],vv)
    else
      xx = self:post(self.course_prefix.."assignment_groups",vv)
      self.assignment_groups[xx.name] = xx.id
    end
  end

  print("## ASSIGNMENT GROUPS")
  pretty.dump(self.assignment_groups)

  local Nmarks = 0
  for ii,vv in ipairs(assign_groups) do
    Nmarks = Nmarks + vv.group_weight
  end
  print("TOTAL MARKS: "..Nmarks)

end




--- Get all assignments and store their metadata.
-- @tparam table arg list of arguments
-- download = true | false | "ask"
function canvas:get_assignments(arg)

  local arg = arg or {}
  local force = arg.force or false
  local dl_check
  if self.assignments then
    dl_check = false
  else
    dl_check = true
  end
  if self.assignments and force == "ask" then
    print("Assignment data exists but might be out of date. Re-download assignment data?")
    print("Type y to do so:")
    dl_check = io.read() == "y"
  end

  if dl_check then
    print("# Getting assignments currently in Canvas")
    local all_assign = self:get_pages(true,self.course_prefix.."assignments")
    local assign_tbl = {}
    for ii,vv in ipairs(all_assign) do
      assign_tbl[vv.name] = vv
    end
    self.assignments = assign_tbl
  end

  print("## ASSIGNMENTS - .assignments ")
  pretty.dump(self.assignments)

end



--- Get full details of a single assignment
-- @tparam bool use_cache_bool Don't download if cache available?
-- @tparam string assign_name Name of the assignment
-- @tparam table assign_opts Additional REST arguments (link)
function canvas:get_assignment(use_cache_bool,assign_name,assign_opts)
  return self:get_assignment_generic(use_cache_bool,assign_name,assign_opts,"Assign "..assign_name)
end

canvas.get_assignment_ungrouped = function(self,use_cache_bool,assign_name,assign_opts)
  return self:get_assignment_generic(use_cache_bool,assign_name,assign_opts,"Assign "..assign_name.." Ungrouped")
end

canvas.get_assignment_generic = function(self,use_cache_bool,assign_name,assign_opts,cache_name)

  local cache_name = cache_name or assign_name
  local cache_file = canvas.cache_dir..cache_name..".lua"

  if use_cache_bool then

    canvas_data = self:get(self.course_prefix .. "assignments","search_term=" .. assign_name)
    assign_id = canvas_data[1]["id"]
    local final_grader_id = canvas_data[1]["final_grader_id"]

    local moderator_reset = false

    if final_grader_id then
      print('Moderated assignment -- checking')

      local canvas_me = self:get("users/self")
      local my_id = canvas_me.id

      if final_grader_id == my_id then
        print('You are the allocated "moderator" -- good')
      else
        print('Switching "moderator"')
        self:put(self.course_prefix .. "assignments/"..assign_id,{assignment={final_grader_id=my_id}})
        moderator_reset = true
      end

    end

    print('ASSIGNMENT NAME: '..assign_name)
    print('ASSIGNMENT ID:   '..assign_id)
    print('GETTING SUBMISSIONS:')
    local canvas_sub = self:get_pages(true,self.course_prefix .. "assignments/" .. assign_id .. "/submissions",assign_opts)

    if moderator_reset then
        print('Resetting "moderator"')
        self:put(self.course_prefix .. "assignments/"..assign_id,{assignment={final_grader_id=final_grader_id}})
    end

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
    if argday == "mon"       then argday =   0 end
    if argday == "tue"       then argday =   1 end
    if argday == "tues"      then argday =   1 end
    if argday == "wed"       then argday =   2 end
    if argday == "thu"       then argday =   3 end
    if argday == "fri"       then argday =   4 end
    if argday == "sat"       then argday =   5 end
    if argday == "sun"       then argday =   6 end
    if argday == "mon-next"  then argday = 7+0 end
    if argday == "tue-next"  then argday = 7+1 end
    if argday == "tues-next" then argday = 7+1 end
    if argday == "wed-next"  then argday = 7+2 end
    if argday == "thu-next"  then argday = 7+3 end
    if argday == "fri-next"  then argday = 7+4 end
    if argday == "sat-next"  then argday = 7+5 end
    if argday == "sun-next"  then argday = 7+6 end
  end
  return argday
end


--- Create a Canvas assignment.
-- @param self
-- @tparam table args arguments
canvas.create_assignment = function(self,args)
--[[
    ARGS:
    ask
    student_group_category -- implies a group submission
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
	descr
	description
}
--]]
--[[
canvas.defaults.assignment.day = 0
--]]


  local assign_out
  local ask = args.ask or ""

  self.assignment_setup = self.assignment_setup or {}
  self.assignment_setup[args.name] = args

  if ask == "" then
    print("Create/update assignment '"..args.name.."'?")
    print("Type y to proceed:")
    ask = io.read()
  end

  if ask == "y" then

  if self.assignment_groups == nil then
    self:get_assignment_groups()
  end
  if self.student_group_category == nil then
    self:get_student_group_categories()
  end

  local sem = args.sem or 1

  local group_proj_id = nil
  if args.student_group_category then
    group_proj_id = self.student_group_category[args.student_group_category]
    if not(group_proj_id) then
      error("Student group category not found")
    else
      print("Student group category: "..group_proj_id)
    end
  end

  local argtypes_allowed = {"online_quiz","none","on_paper","discussion_topic","external_tool","online_upload","online_text_entry","online_url","media_recording"}
  args.assign_type = args.assign_type or "online_upload"
  if type(args.assign_type) == "string" then
    args.assign_type = {args.assign_type}
  end
  do
    local arg_bad = true
    for iii,vvv in ipairs(args.assign_type) do
      for ii,vv in ipairs(argtypes_allowed) do
        if vvv == vv then arg_bad = false end
      end
    end
    if arg_bad then
      print("The 'assign_type' option for creating assignments can be any of:")
      pretty.dump(argtypes_allowed)
      error("Bad argument for 'assign_type'.")
    end
  end

  if args.published == nil then
     args.published = "true"
  end

  local new_assign = {
    assignment =  {
                              name = args.name                                 ,
                         published = args.published                            ,
                   points_possible = args.points or "0"                        ,
                  submission_types = args.assign_type                          ,
               assignment_group_id = self.assignment_groups[args.assign_group] ,
                  }
  }

  if args.assign_type == "online_upload" then
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


  local duediff    =  0
  local lockdiff   = -1
  local unlockdiff =  0
  -- these are set up so that an assignment with no due date will be queried but not aborted

  if args.week then

    local argday = args.day or canvas.defaults.assignment.day or 4 -- friday
    argday = day_string_to_num(argday)

    args.open_days = args.open_days or canvas.defaults.assignment.open_days
    args.late_days = args.late_days or canvas.defaults.assignment.late_days

    local duehr       = args.duehr    or "15"
    local lockhr      = args.lockhr   or "17"
    local unlockhr    = args.unlockhr or "08"
    local duetime     = duehr..":00:00"
    local unlocktime  = unlockhr..":00:00"
    local locktime    = lockhr..":00:00"

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
    duediff       = today_date.time - duedate.time
    new_assign.assignment.due_at    = duedatestr

    if args.open_days then
      local unlockdate    = date(self.sem_first_monday[sem]):add{day=dayoffset-args.open_days}
      local unlockdatestr = datef:tostring(unlockdate).."T"..unlocktime
      unlockdiff    = today_date.time - unlockdate.time
      new_assign.assignment.unlock_at = unlockdatestr
    end

    if args.late_days then
      local lockdate      = date(self.sem_first_monday[sem]):add{day=dayoffset+args.late_days}
      local lockdatestr   = datef:tostring(lockdate).."T"..locktime
      lockdiff      = today_date.time - lockdate.time
      new_assign.assignment.lock_at   = lockdatestr
    end

  end

  if args.description then
    local descr_html = markdown(args.description)
    descr_html = descr_html:gsub("\n","")
    new_assign.assignment.description = descr_html
  end

  local descr_filename = args.descr
  if descr_filename then
    if new_assign.assignment.description then
     error("Assignment description already specified.")
    end

    local descr = nil
    local descr_html = nil
    if not(path.isfile(descr_filename)) then
      descr_filename = "assign_details/"..descr_filename
      if not(path.isfile(descr_filename)) then
        error("Description file '"..descr_filename.."' does not seem to exist.")
      end
    end
    do
      local f = assert(io.open(descr_filename, "r"))
      descr = f:read("*all")
      f:close()
    end
    do
      local fname,fext = path.splitext(descr_filename)
      if fext == ".html" then
        descr_html = descr
      elseif fext == ".md" then
        descr_html = markdown(descr)
      else
        error("Filename with extension '"..fext.."' is not supported.")
      end
    end
    descr_html = descr_html:gsub("\n","")
    new_assign.assignment.description = descr_html
  end



  print("ASSIGNMENT DETAILS FOR CREATION/UPDATE:")
  pretty.dump(new_assign)

  local diffcontinue = true
  if lockdiff >= 0 then
    print("Assignment already locked for students; skipping assignment creation/update.")
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
    if self.assignment_ids == nil then
      self:get_assignments()
    end
    local assign_id = self.assignment_ids[args.name]
    print("## "..args.name)
    local a
    if assign_id then
      a = self:put(self.course_prefix.."assignments/"..assign_id,new_assign)
    else
      a = self:post(self.course_prefix.."assignments",new_assign)
      self.assignment_ids[args.name] = a.id
    end
    if a.errors then
      pretty.dump(a)
      error("Create/update assignment failed")
    end
    assign_out = a

    -- RUBRIC
    if args.rubric then
      if self.rubric_ids == nil then
        self:get_rubrics()
      end
      print("ASSIGN RUBRIC: "..args.rubric)
      local rubric_id = self.rubric_ids[args.rubric]
      if rubric_id then
        self:assoc_rubric{rubric_id = rubric_id, assign_id = assign_id}
      else
        pretty.dump(self.rubric_ids)
        error("Assoc rubric failed; no rubric '"..args.rubric.."'")
      end
    end
  end

  else

    if self.assignment_ids == nil then
      self:get_assignments()
    end
    assign_out = {id = self.assignment_ids[args.name]}

  end

  return assign_out

end

--- Compare assignments in Canvas to what has been defined locally.
canvas.check_assignments = function(self)

  if self.assignment_ids == nil then
    self:get_assignments()
  end

  local assign_def = {}
  for kk in pairs(self.assignment_ids) do
    assign_def[kk] = "true"
  end
  for kk in pairs(self.assignment_setup) do
    assign_def[kk] = nil
  end
  for kk in pairs(assign_def) do
    print("Assignment exists in Canvas but not defined: "..kk)
  end

  local assign_def = {}
  for kk in pairs(self.assignment_setup) do
    assign_def[kk] = "true"
  end
  for kk in pairs(self.assignment_ids) do
    assign_def[kk] = nil
  end
  for kk in pairs(assign_def) do
    print("Assignment defined but does not exist in Canvas: "..kk)
  end

end




