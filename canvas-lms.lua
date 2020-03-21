
local http   = require("ssl.https")
local ltn12  = require("ltn12")
local json   = require("json")
local binser = require("binser")
local pretty = require("pl.pretty")
local lfs    = require "lfs"
local tablex = require("pl.tablex")
local csv    = require("csv")
local Date   = require("pl.Date")

lfs.mkdir("cache")

canvas = canvas or {}


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

dofile("canvas-data.lua")

require("canvas-lms-http")
require("canvas-lms-students")
require("canvas-lms-rubrics")
require("canvas-lms-message")




canvas.get_pages = function(self,download_bool,req,opt)

  local cache_name = string.gsub(req,"/"," - ")
  local cache_file = "cache/Pages - "..cache_name..".lua"

  if download_bool == "ask" then
    print("Download all pages for requested GET? Type y to do so:")
    dl_check = io.read()
    download_bool = dl_check == "y"
  end

  if download_bool then
    local canvas_pages = {}
    local has_data = true
    local data_page = 0

    while has_data do

      data_page = data_page + 1
      local opt = opt or {}
      opt.page = data_page
      canvas_data = self:get(req,opt)
      for i=1,#canvas_data do
          if not(canvas_data[i].missing) then
            canvas_pages[#canvas_pages+1] = canvas_data[i]
          end
      end

      if #canvas_data == 0 then
        has_data = false
      else
        print("Retrieved page "..data_page)
      end

    end

    binser.writeFile(cache_file,canvas_pages)
  end

  local canvas_pages = binser.readFile(cache_file)
  return canvas_pages[1]

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

canvas.assign_grades = function(self,get_switch,assign_names,students_by_cid)

  for i,assign_name in ipairs(assign_names) do
    local download_check = "y"
    if get_switch == "ask" then
      print("Download grades for assignment '"..assign_name.."'? Type y to do so:")
      download_check = io.read()
    elseif get_switch == "never" then
      download_check = "n"
    end
    local assign = canvas:get_assignment_ungrouped(download_check=="y",assign_name)
    for i,j in pairs(assign) do
      if students_by_cid[j.user_id] then
        students_by_cid[j.user_id].grades = students_by_cid[j.user_id].grades or {}
        students_by_cid[j.user_id].grades[assign_name] = j.score
      end
    end

  end

  return students_by_cid

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

  local datef = Date.Format 'yyyy-mm-dd'

  local today_date = Date{}
  local todaystr   = datef:tostring(today_date)

  local dayoffset = argday+7*(wkoffset-1)

  local duedate     = Date(self.sem_first_monday[args.sem]):add{day=dayoffset}
  local duedatestr  = datef:tostring(duedate).."T"..duehr..":00:00"
  local duediff     = today_date.time - duedate.time

  local lockdate    = Date(self.sem_first_monday[args.sem]):add{day=dayoffset}
  local lockdatestr = datef:tostring(lockdate).."T"..lockhr..":00:00"

  local dd = Date(self.sem_first_monday[args.sem]):add{day=dayoffset}
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





return canvas
