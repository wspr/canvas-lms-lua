--- Canvas LMS in Lua: Assignments
-- @submodule canvas

local binser = require("binser")
local dump = require("pl.pretty").dump
local date   = require("pl.date")
local path   = require("pl.path")
--local markdown = require("markdown")

local canvas = {}

--- Get assignments.
-- Data stored in `.assignments` table, indexed by assignment `name`.
-- Code for this function uses the generic `define_getter` function in the HTTP submodule.
-- @function get_assignments

--- Get assignment groups IDs.
-- Gets details of each assignment group and stores their IDs for later lookup. Data stored in |self.assignment_groups|.
function canvas:get_assignment_groups()

  local assign_grps = self:get_paginated(true,self.course_prefix.."assignment_groups")
  local grp_hash = {}
  for _,vv in ipairs(assign_grps) do
    grp_hash[vv.name] = vv.id
  end
  self.assignment_groups = grp_hash

end

--- Setup assignment group arguments.
-- The function `canvas:setup_assignment_groups` takes a single table of arguments.
-- The table should be an ordered list
-- @field name The name of the assignment
-- @field weight The weighting of the assignment group
-- @table @{assign_group_args}

--- Set up assignment groups.
-- If any assignment group weightings are specified, the course setting to enable assignment weightings is enabled.
-- @tparam table args list of tables with fields defined by @{assign_group_args}
function canvas:setup_assignment_groups(args)

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

  for _,vv in ipairs(assign_groups) do
    dump(self.assignment_groups)
    if self.assignment_groups[vv.name]==nil then
      local xx = self:post(self.course_prefix.."assignment_groups",vv)
      self.assignment_groups[xx.name] = xx.id
    else
      self:put(self.course_prefix.."assignment_groups/"..
               self.assignment_groups[vv.name],vv)
    end
  end

  print("## ASSIGNMENT GROUPS")
  dump(self.assignment_groups)

  local Nmarks = 0
  for _,vv in ipairs(assign_groups) do
    Nmarks = Nmarks + vv.group_weight
  end
  print("TOTAL MARKS: "..Nmarks)

end






--- Get full details of a single assignment.
-- @tparam bool use_cache_bool Don't download if cache available?
-- @tparam string assign_name Name of the assignment
-- @tparam table assign_opts Additional REST arguments (link)
function canvas:get_assignment(use_cache_bool,assign_name,assign_opts)
  return self:get_assignment_generic(use_cache_bool,assign_name,assign_opts,"Assign "..assign_name)
end

function canvas:get_assignment_ungrouped(use_cache_bool,assign_name,assign_opts)
  return self:get_assignment_generic(use_cache_bool,assign_name,assign_opts,"Assign "..assign_name.." Ungrouped")
end

function canvas:get_assignment_generic(use_cache_bool,assign_name,assign_opts,cache_name_arg)

  local cache_name = cache_name_arg or assign_name
  local cache_file = self.cache_dir..cache_name..".lua"

  self:get_assignments{download=false}

  if use_cache_bool then

    if self.assignments[assign_name] == nil then
      print("Assignment names:")
      for _,j in pairs(self.assignments) do
        print("  • '"..j.name.."'")
      end
      error("Requested assignment name ('"..assign_name.."') not found.")
    end
    local canv_assign_id = self.assignments[assign_name].id
    local canv_assign = self:get(self.course_prefix .. "assignments/"..canv_assign_id)

    local assign_id = canv_assign["id"]
    local final_grader_id = canv_assign["final_grader_id"]

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
    local stub = self.course_prefix .. "assignments/" .. assign_id .. "/submissions"
    local canvas_sub = self:get_paginated(true,stub,assign_opts)

    if moderator_reset then
        print('Resetting "moderator"')
        self:put(self.course_prefix .. "assignments/"..assign_id,{assignment={final_grader_id=final_grader_id}})
    end

    print("(" .. #canvas_sub .. " submissions)")

    local to_remove = {}
    for i,j in ipairs(canvas_sub) do
      if (j.attempt==nil or j.workflow_state == "unsubmitted") and (j.score==nil) then
        print("Entry "..i.." to be removed ("..j.user.name..", ID: "..(j.user.sis_user_id or "unknown")..").")
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



--- Create assignment arguments.
-- @field ask
-- @field student_group_category (implies a group submission)
-- @field omit_from_final_grade
-- @field assign_type one of {"online_quiz","none","on_paper","discussion_topic","external_tool"}
-- @field due
-- @field unlock
-- @field lock
-- @field published
-- @field description
-- @field descr_file
-- @field rubric
-- @field external_tool
-- @table create_assignment_args

--- Create a Canvas assignment.
-- @tparam table args arguments (see `create_assignment_args`)
function canvas:create_assignment(args)

  local assign_out
  local ask = args.ask or ""
  args.due = args.due or {}
  args.due.sem = args.due.sem or 1

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

  local group_proj_id = nil
  if args.student_group_category then
    group_proj_id = self.student_group_category[args.student_group_category]
    if not(group_proj_id) then
      error("Student group category not found")
    else
      print("Student group category: "..group_proj_id)
    end
  end

  if args.mobius then
    args.external_tool = {
           new_tab = true,
           url = self.mobius_url,
                         }
  end

  local argtypes_allowed = {
    "online_quiz","none","on_paper","discussion_topic","external_tool","online_upload",
    "online_text_entry","online_url","media_recording"
  }
  if args.external_tool then
    args.assign_type = "external_tool"
  else
    args.assign_type = args.assign_type or {"online_upload"}
  end
  if type(args.assign_type) == "string" then
    args.assign_type = {args.assign_type}
  end
  do
    local arg_bad = true
    for _,vvv in ipairs(args.assign_type) do
      for _,vv in ipairs(argtypes_allowed) do
        if vvv == vv then arg_bad = false end
      end
    end
    if arg_bad then
      print("The 'assign_type' option for creating assignments can be any of:")
      dump(argtypes_allowed)
      error("Bad argument for 'assign_type'.")
    end
  end

  if args.published == nil then
     args.published = true
  end

  local new_assign = {
    assignment =  {
                              name = args.name                                 ,
                         published = args.published                            ,
                  submission_types = args.assign_type                          ,
               assignment_group_id = self.assignment_groups[args.assign_group] ,
                  }
  }
  if args.points then
    new_assign.assignment.points_possible = args.points
  end

  for _,v in ipairs(args.assign_type) do
    if v == "online_upload" then
      new_assign.assignment.allowed_extensions = args.ext or "pdf"
    end
  end
  if args.rubric then
    new_assign.assignment.use_rubric_for_grading = true
  end
  if group_proj_id then
    new_assign.assignment.group_category_id = group_proj_id
  end
  if args.omit_from_final_grade then
    new_assign.assignment.omit_from_final_grade = args.omit_from_final_grade
  end
  if args.external_tool then
    new_assign.assignment.external_tool_tag_attributes = args.external_tool
  end

--  local duediff    =  0
  local lockdiff   = -1
  local unlockdiff =  0
  -- these are set up so that an assignment with no due date will be queried but not aborted

  local today_date    = date{}
  local dateformat = date.Format('yyyy-mm-ddTHH:MM:SS')

  -- compatibility with "flattened" due date variables
  if args.week then args.due = {} end
  args.due.sem  = args.due.sem  or args.sem or 1
  args.due.week = args.due.week or args.week
  args.due.day  = args.due.day  or args.day or self.defaults.assignments.day
  args.due.hour = args.due.hour or args.hr  or self.defaults.assignments.hour
  args.due.min  = args.due.min  or args.min

  args.open_days = args.open_days or self.defaults.assignments.open_days
  args.late_days = args.late_days or self.defaults.assignments.late_days
  if args.open_days then
    args.unlock = args.unlock or {}
    args.unlock.before_days = args.open_days
  end
  if args.late_days then
    args.lock = args.lock or {}
    args.lock.after_days = args.late_days
  end

  if args.due and args.due.day then
    local duedate = self:datetime{
        sem  = args.due.sem  ,
        week = args.due.week ,
        day  = args.due.day  ,
        hour = args.due.hour ,
        min  = args.due.min  ,
      }
    print("Assignment due at: "..dateformat:tostring(duedate))
    new_assign.assignment.due_at = dateformat:tostring(duedate)
  end

  if args.unlock then
    args.unlock.before_days = args.unlock.before_days or 0

    local unlockdate = self:datetime{
        sem  = args.unlock.sem  or args.due.sem  ,
        week = args.unlock.week or args.due.week ,
        day  = args.unlock.day  or args.due.day  ,
        hour = args.unlock.hour or args.due.hour ,
        min  = args.unlock.min  or args.due.min  ,
      }
    unlockdate:add{day=-args.unlock.before_days}
    unlockdiff    = today_date.time - unlockdate.time
    new_assign.assignment.unlock_at = dateformat:tostring(unlockdate)
  end

  if args.lock then
    args.lock.after_days = args.lock.after_days or 0

    local lockdate = self:datetime{
        sem  = args.lock.sem  or args.due.sem  ,
        week = args.lock.week or args.due.week ,
        day  = args.lock.day  or args.due.day  ,
        hour = args.lock.hour or args.due.hour ,
        min  = args.lock.min  or args.due.min  ,
      }
    lockdate:add{day=args.lock.after_days}
    lockdiff      = today_date.time - lockdate.time
    new_assign.assignment.lock_at   = dateformat:tostring(lockdate)
  end

  if args.description then
    local descr_html = markdown(args.description)
    descr_html = descr_html:gsub("\n","")
    new_assign.assignment.description = descr_html
  end

  local descr_filename = args.descr_file or args.descr
  if descr_filename then
    if new_assign.assignment.description then
     error("Assignment description already specified.")
    end

    local descr
    local descr_html
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
      local _,fext = path.splitext(descr_filename)
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
  dump(new_assign)

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
    self:get_assignments()
    self.assignments[args.name] = self.assignments[args.name] or {}
    local assign_id = self.assignments[args.name].id
    print("## "..args.name)
    local a
    if assign_id then
      a = self:put(self.course_prefix.."assignments/"..assign_id,new_assign)
    else
      a = self:post(self.course_prefix.."assignments",new_assign)
      self.assignments[args.name] = a
      assign_id = a.id
    end
    if a.errors then
      dump(a)
      error("Create/update assignment failed")
    end
    assign_out = a

    -- RUBRIC
    if args.rubric then
      self:get_rubrics()
      print("ASSIGN RUBRIC: '"..args.rubric.."'")
      if self.rubrics[args.rubric] == nil then
        dump(self.rubrics)
        error("Assoc rubric failed; no rubric '"..args.rubric.."'")
      end
      local rubric_id = self.rubrics[args.rubric].id
      if rubric_id then
        self:assoc_rubric{rubric_id = rubric_id, assign_id = assign_id}
      end
    end
  end

  else

    self:get_assignments()
    assign_out = self.assignments[args.name]

  end

  return assign_out

end


--- Basic assignment metadata update function.
function canvas:update_assignment(assignname,opt)

  if(self.assignments==nil) then
    self:get_assignments()
  end

  local id = self.assignments[assignname].id
  if id == nil then
    error("Assignment '"..assignname"' not found.")
  end

  self:put(self.course_prefix.."assignments/"..id,{assignment=opt})

end

--- Basic quiz metadata update function.
function canvas:update_quiz(assignname,opt)

  if(self.quizzes==nil) then
    self:get_quizzes()
  end

  local id = self.quizzes[assignname].id
  if id == nil then
    error("Quiz '"..assignname"' not found.")
  end

  self:put(self.course_prefix.."quizzes/"..id,{quiz=opt})

end


--- Compare assignments in Canvas to what has been defined locally.
function canvas:check_assignments()

  if self.assignment_ids == nil then
    self:get_assignments()
  end

  do
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
  end

  do
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

end



return canvas

