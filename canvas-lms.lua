
local http   = require("ssl.https")
local ltn12  = require("ltn12")
local json   = require("json")
local binser = require("binser")
local pretty = require("pl.pretty")
local lfs    = require "lfs"
local tablex = require("pl.tablex")
local csv    = require("csv")

lfs.mkdir("cache")

canvas = canvas or {}


canvas.set_course_id = function(self,str)
  self.courseid = str
  self.course_prefix = "courses/"..str.."/"
end

canvas.set_url = function(self,str)
  self.url = str
end

canvas.set_year = function(self,yr)
  self.year = yr
end

canvas.set_token = function(self,str)
  self.token = str
end

canvas.set_week1 = function(self,date)
  self.week1 = date
end

dofile("canvas-data.lua")



local urlencode = function(str_table)

  local str_result = ""
  if type(str_table) == "string" then
    str_result = str_table
  end

  for k,v in pairs(str_table) do
    str_result = str_result..k.."="..v
  end

  return str_result

end

canvas.getpostput = function(self,param,req,opt_arg)

    local use_json = false
    local opt_str
    local opt_json
    local canvas_data

    if type(opt_arg) == "table" then
      use_json = true
      opt_json = json:encode(opt_arg)
    else
      opt_str = opt_arg or ""
    end

    if use_json then
      canvas_data = canvas.getpostput_json(self,param,req,opt_json)
    else
      canvas_data = canvas.getpostput_str(self,param,req,opt_str)
    end

    return canvas_data

end

canvas.getpostput_str = function(self,param,req,opt)

    if not(opt == "") then
      opt = "?"..opt
      opt = opt:gsub(" ","+")
      opt = opt:gsub("–","%%E2%%80%%93")
    end

    local httpreq = self.url .. "api/v1/" .. req .. opt
    print("HTTP "..param.." REQUEST: " .. httpreq )

    local res = {}
    local body, code, headers, status = http.request{
        url = httpreq,
        method = param,
        headers = {
          ["authorization"] = "Bearer " .. self.token,
          ["content-type"]  = "application/json"
        },
        sink = ltn12.sink.table(res),
    }

    res = table.concat(res)
    canvas_data = json:decode(res)

    return canvas_data

end

canvas.getpostput_json = function(self,param,req,opt)

    local httpreq = self.url .. "api/v1/" .. req
    print("HTTP "..param.." REQUEST: " .. httpreq )
    print("JSON: " .. opt )

    local res = {}
    local body, code, headers, status = http.request{
        url = httpreq,
        method = param,
        headers = {
          ["authorization"] = "Bearer " .. self.token ,
          ["content-type"]  = "application/json" ,
          ["content-length"] = opt:len()     ,
        },
        source = ltn12.source.string(opt),
        sink   = ltn12.sink.table(res),
    }

    res = table.concat(res)
    canvas_data = json:decode(res)

    return canvas_data

end

canvas.get = function(self,req,opt)
  return canvas.getpostput(self,"GET",req,opt)
end
canvas.post = function(self,req,opt)
  return canvas.getpostput(self,"POST",req,opt)
end
canvas.put = function(self,req,opt)
  return canvas.getpostput(self,"PUT",req,opt)
end

canvas.find_user = function(self,str)

  user_data = self:get(self.course_prefix.."users","search_term="..str)

  return user_data

end

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


canvas.get_students = function(self,download_bool)

  local download_bool = download_bool
  if download_bool == nil then
    download_bool = true
  end

  local students = canvas:get_pages(download_bool,canvas.course_prefix.."users","enrollment_type[]=student")

  local students_by_cid = {}
  for k,v in pairs(students) do
    students_by_cid[v.id] = v
  end

  return students_by_cid

end


canvas.upload = function(self,path,file)

  local formparam = "name="..file.."&".."parent_folder_path="..path
  local res = {}

  local body, code, headers, status = http.request{
      url = self.url .. "api/v1/" .. "files" ,
      method = "POST",
      headers = {
        ["authorization"]  = "Bearer " .. self.token,
        ["Content-Type"]   = "application/x-www-form-urlencoded";
        ["Content-Length"] = #formparam;
      },
      source = ltn12.source.string(formparam),
      sink = ltn12.sink.table(res),
  }

  serialise(res)

  res = table.concat(res)
  canvas_data = json:decode(res)

  return canvas_data

end


canvas.get_groups = function(self,use_cache_bool,group_category_name)

  local cache_path = "cache/Group - "..group_category_name..".lua"

  if use_cache_bool then
    local gcats = canvas:get( canvas.course_prefix .. "group_categories" , "" )
    gcat_id = 0;
    for i,j in ipairs(gcats) do
      if j.name == group_category_name then
        gcat_id = j.id
      end
    end
    if gcat_id == 0 then error("oops") end
    print('Group category id for "'..group_category_name..'" = '..gcat_id)
    local canvas_data = canvas:get_pages(true, "group_categories/" .. gcat_id .. "/groups" , "" )
    local groups = {}
    for i,j in ipairs(canvas_data) do
      local group_users = canvas:get( "groups/" .. j.id .. "/users" , "" )
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



canvas.message_group_wfile = function(self,send_check,msg)

  local function encode(str)
		str = string.gsub (str, "\n", "\r\n")
    str = string.gsub(str, "([^%w _ %- . ~])",
      function (c) return string.format ("%%%02X", string.byte(c)) end
    )
    str = string.gsub (str, " ", "+")
	  return str
	end


  local recipients="recipients[]=group_"..msg.canvasid
  local subject="subject="..msg.subject
  local body="body="..msg.body

  local attachfile = canvas:get("users/self/files","search_term="..msg.filestub)
  if #attachfile > 0 then
    local fileid = "attachment_ids[]="..attachfile[1].id
    local isgroup = "group_conversation=true"

    opt = recipients.."&"..subject.."&"..body.."&"..fileid.."&"..isgroup

    if send_check=="y" then
      canvas:post("conversations",encode(opt))
    else
      print("MESSAGE:")
      print(opt)
      print("AFTER ENCODING:")
      print(encode(opt))
      print("NOT SENT ACCORDING TO USER INSTRUCTIONS")
    end
  else
    error("No file found")
  end


end


canvas.message_user = function(self,send_check,msg)

  local function encode(str)
		str = string.gsub (str, "\n", "\r\n")
    str = string.gsub(str, "([^%w _ %- . ~])",
      function (c) return string.format ("%%%02X", string.byte(c)) end
    )
    str = string.gsub (str, " ", "+")
	  return str
	end

  local forcenew="force_new=true"
  local recipients="recipients[]="..msg.canvasid
  local subject="subject="..encode(msg.subject)
  local body="body="..encode(msg.body)

  opt = forcenew.."&"..recipients.."&"..subject.."&"..body

  if send_check then
    canvas:post("conversations",opt)
  else
    -- print(opt)
  end


end













canvas.send_rubric = function(self,rubric)

  local all_rubrics = canvas:get_pages(true,canvas.course_prefix.."rubrics")
  local rubric_hash = {}
  for ii,vv in ipairs(all_rubrics) do
    rubric_hash[vv.title] = vv.id
  end

  rubric_id = rubric_hash[rubric.title]
  local canvas_rubric
  if rubric_id then
    canvas_rubric = canvas:put(canvas.course_prefix.."rubrics/"..rubric_id,{rubric = rubric})
  else
    canvas_rubric = canvas:post(canvas.course_prefix.."rubrics",{rubric = rubric})
  end

  return canvas_rubric
end

canvas.assoc_rubric = function(self,args)

  local rassoc = {
        rubric_association = {
          rubric_id = args.rubric_id,
          association_type = "Assignment" ,
          association_id = args.assign_id ,
          use_for_grading = true ,
          purpose = "grading" ,
        }
      }
  a = canvas:post(canvas.course_prefix.."rubric_associations",rassoc)

  return a
end


canvas.rubric_from_csv = function(self,csvfile)

  local f = csv.open(csvfile)

  local Nrow = 0
  local row_titles = {}
  local row_descr = {}
  local row_points = {}
  local row_use_range = {}
  local row_cell_titles = {}
  local row_cell_descrs = {}
  local row_cell_points = {}

  for fields in f:lines() do
    if fields[1] == "" then
      -- skip empty rows
    elseif fields[1] == "TITLE" then
      rtitle = fields[2]
    elseif fields[1] == "DESCRIPTION" then
      rdesc = fields[2]
    elseif fields[1] == "ROW TITLE" then
      Nrow = Nrow + 1
      row_use_range[Nrow] = false
      row_titles[Nrow] = fields[2]
    elseif fields[1] == "ROW USE RANGE" then
      if fields[2] == "TRUE" then
        row_use_range[Nrow] = true
      elseif fields[2] == "FALSE" then
        row_use_range[Nrow] = false
      else
        error('Unknown value for ROW USE RANGE ('..fields[2]..')')
      end
    elseif fields[1] == "ROW DESCRIPTION" then
      row_descr[Nrow] = fields[2]
    elseif fields[1] == "ROW POINTS" then
      row_points[Nrow] = fields[2]
    elseif fields[1] == "CELL TITLES" then
      row_cell_titles[Nrow] = {}
      for ii = 2,#fields do
        if not(fields[ii] == "") then
          row_cell_titles[Nrow][ii-1] = fields[ii]
        end
      end
    elseif fields[1] == "CELL DESCRIPTIONS" then
      row_cell_descrs[Nrow] = {}
      for ii = 2,#fields do
        if not(fields[ii] == "") then
          row_cell_descrs[Nrow][ii-1] = fields[ii]
        end
      end
    elseif fields[1] == "CELL POINTS" then
      row_cell_points[Nrow] = {}
      for ii = 2,#fields do
        if not(fields[ii] == "") then
          row_cell_points[Nrow][ii-1] = fields[ii]
        end
      end
    else
      error("Unknown row '"..fields[1].."'")
    end
  end

  local Trow = #row_titles
  local criteria = {}
  for ii = 1,Trow do

    local ratings = {}
    local Tcells = #row_cell_titles[ii]

    for jj = 1,Tcells do
      ratings[tostring(jj-1)] = {
                                  description = row_cell_titles[ii][jj],
                                  long_description = row_cell_descrs[ii][jj],
                                  points = row_cell_points[ii][jj],
                                }
    end

    criteria[tostring(ii-1)] = {
                                 points = row_points[ii] ,
                                 description = row_titles[ii] ,
                                 long_description = row_descr[ii] ,
                                 criterion_use_range = row_use_range[ii] ,
                                 ratings = ratings ,
                               }

  end

  local rubric = {
                   title = rtitle ,
                   description = rdesc ,
                   free_form_criterion_comments = false ,
                   criteria = criteria ,
                 }

  return rubric

end


canvas.setup_group_category = function(self,categories)

  local group_cats = canvas:get_pages(true,canvas.course_prefix.."group_categories")
  local projgrp_hash = {}
  for ii,vv in ipairs(group_cats) do
    projgrp_hash[vv.name] = vv.id
  end

  for ii,vv in ipairs(categories) do
    if projgrp_hash[vv] == nil then
      local xx = canvas:post(canvas.course_prefix.."group_categories","name="..vv)
      projgrp_hash[xx.name] = xx.id
    end
  end

  print("# PROJECT GROUP CATEGORIES")
  pretty.dump(projgrp_hash)

  return projgrp_hash

end



canvas.setup_assignment_groups = function(self,assign_groups)

  local assign_grps = canvas:get_pages(true,canvas.course_prefix.."assignment_groups")
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
      canvas:put(canvas.course_prefix.."assignment_groups/"..grp_hash[vv.name],opt)
    else
      xx = canvas:post(canvas.course_prefix.."assignment_groups",opt)
      grp_hash[xx.name] = xx.id
    end
  end

  print("# ASSIGNMENT GROUPS")
  pretty.dump(grp_hash)

  return grp_hash

end



return canvas
