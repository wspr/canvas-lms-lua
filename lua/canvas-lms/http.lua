--- Canvas LMS in Lua: HTTP
-- @submodule canvas

local http   = require("ssl.https")
local ltn12  = require("ltn12")
local json   = require("json")
local binser = require("binser")
local mppost = require("multipart-post")
local path   = require("pl.path")

local canvas = {}

--[[
     For future reference. HTTP req syntax is:

        body, code, headers, status = http.request

--]]

--- Paginated GET.
-- @param download_bool true | false | "ask"
-- @string req URL stub to GET from
-- @param opt_arg table of optional parameters
-- @treturn table REST result
--
-- This is the workhorse function for most commands that retrieve data from Canvas.
-- Most REST interfaces use pagination to control sizes of return data.
-- This requires iteration of multiple requests to return a full collection of information.
-- Since this can be quite slow, this function has a built-in cache feature that stores
-- the data to disk and if desired re-reads this cache instead of slowly requesting the data again.
-- Where the cache is stored can be customised in the config file.
--
-- @usage canvas:get_pages(true,self.course_prefix.."assignments")

function canvas:get_pages(download_bool,req,opt_arg)

  local cache_name = string.gsub(req,"/"," - ")
  local cache_file = self.cache_dir.."Pages - "..cache_name..".lua"

  if download_bool == false and not(path.exists(cache_file)) then
    print("Cache file for requested GET ["..req.."] does not exist; forcing Canvas download.")
    download_bool = true
  end

  if download_bool == "ask" then
    if path.exists(cache_file) then
      print("Download all pages for requested GET ["..req.."] ?")
      print("Type y to do so:")
      download_bool = io.read() == "y"
    else
      download_bool = true
    end
  end

  if download_bool then
    local canvas_pages = {}
    local has_data = true
    local data_page = 0

    while has_data do

      data_page = data_page + 1
      local opt = opt_arg or {}
      opt.page = data_page
      local canvas_data = self:get(req,opt)
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


--- Define getter function to retrieve and store item metadata.
-- @string field_name  Name of REST field to store item data
-- @string index_name_arg  Name of metadata field to reference item data (default: `"name"`)
-- @tparam table opt_default Default options to pass to REST call
-- Custom argument: `download` = `true` | `false` | `"ask"`
function canvas:define_getter(field_name,index_name_arg,opt_default)
  self["get_"..field_name] = function(self_,opt_arg)

    local index_name = index_name_arg
    local arg = opt_default or {}
    for i,v in ipairs(opt_arg or {}) do
       arg[i] = v
    end
    local download = arg.download or false
    arg.download = nil
--[[
    -- this is not nuanced enough. first need to check if there is data cached through get_pages and only THEN force it if nothing available
    if self_[field_name] == nil then
      download = true
    end
--]]
    local opt = arg or {}

    print("# Getting "..field_name.." data currently in Canvas")
    local all_items = self_:get_pages(download,self_.course_prefix..field_name,opt)
    local items_by_name = {}
    for _,vv in ipairs(all_items) do
      items_by_name[vv[index_name]] = vv
    end
    self_[field_name] = items_by_name
  end
end
canvas.define_getter(canvas,"assignments","name")
canvas.define_getter(canvas,"files","filename")
canvas.define_getter(canvas,"modules","name",{include={"items"}})
canvas.define_getter(canvas,"rubrics","title")


--- Wrapper for GET.
-- @tparam string req URL stub to GET from
-- @param opt table of optional parameters
-- @treturn table REST result
function canvas:get(req,opt)
  return canvas.getpostput(self,"GET",req,opt)
end

--- Wrapper for POST.
-- @tparam string req URL stub to POST to
-- @param opt table of optional parameters
-- @treturn table REST result
function canvas:post(req,opt)
  return canvas.getpostput(self,"POST",req,opt)
end

--- Wrapper for PUT.
-- @tparam string req URL stub to PUT to
-- @param opt table of optional parameters
-- @treturn table REST result
function canvas:put(req,opt)
  return canvas.getpostput(self,"PUT",req,opt)
end

--- Wrapper for DELETE.
-- @tparam string req URL stub to DELETE from
-- @param opt table of optional parameters
-- @treturn table REST result
function canvas:delete(req,opt)
  return canvas.getpostput(self,"DELETE",req,opt)
end


function canvas:getpostput(param,req,opt_arg)

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

function canvas:getpostput_str(param,req,opt)

    if not(opt == "") then
      opt = "?"..opt
      opt = opt:gsub(" ","+")
      opt = opt:gsub("–","%%E2%%80%%93")
    end

    local httpreq = self.url .. "api/v1/" .. req .. opt
    self:print("HTTP "..param.." REQUEST: " .. httpreq )

    local res = {}
    http.request{
        url = httpreq,
        method = param,
        headers = {
          ["authorization"] = "Bearer " .. self.token,
          ["content-type"]  = "application/json"
        },
        sink = ltn12.sink.table(res),
    }

    return json:decode(table.concat(res))

end

function canvas:getpostput_json(param,req,opt)

    local httpreq = self.url .. "api/v1/" .. req
    self:print("HTTP "..param.." REQUEST: " .. httpreq )
    self:print("JSON: " .. opt )

    local res = {}
    http.request{
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

    return json:decode(table.concat(res))

end



--- Upload a file to a Canvas course
-- The process for uploading files to Canvas is [documented here](https://canvas.instructure.com/doc/api/file.file_uploads.html#method.file_uploads.post).
-- @tparam table opt
-- Required argument `opt.filename` specifies filename to upload.
-- `opt.filepath.."/"..opt.filename` defines where the file is to be found in the local filesystem.
-- File will be uploaded in the root directory for the course or as specified by `opt.folder`.
-- Additional arguments specified in the [Canvas Files API](https://canvas.instructure.com/doc/api/files.html#method.files.api_update).
function canvas:file_upload(opt)

  local res  = {}
  local res2 = {}
  local res3 = {}

  opt.filepath = opt.filepath or "."
  local file_full = opt.filepath.."/"..opt.filename
  if not(path.exists(file_full)) then
    error("File '"..file_full.."' not found.")
  end

  local args = {}
  args.name = opt.filename
  args.parent_folder_path = opt.folder or "/"
  local args_json = json:encode(args)

  -- Step 1: Telling Canvas about the file upload and getting a token
  http.request {
      url = self.url .. "api/v1/" .. self.course_prefix .. "files/",
      method = "POST",
      headers = {
        ["authorization"] = "Bearer " .. self.token ,
        ["content-type"]  = "application/json" ,
        ["content-length"] = args_json:len()     ,
      },
      source = ltn12.source.string(args_json),
      sink   = ltn12.sink.table(res),
  }
  res = json:decode(table.concat(res))

  -- Step 1.5: Read file
  local file = io.open(file_full, "r")
  local file_length = file:seek("end")
  file:seek("set", 0)

  -- Step 2: Upload the file data to the URL given in the previous response
  local rq = mppost.gen_request {
    myfile = { name = opt.filename, data = file, len = file_length }
  }
  rq.url  = res.upload_url
  rq.sink = ltn12.sink.table(res2)
  http.request(rq)
  res2 = json:decode(table.concat(res2))

  -- Step 3: Confirm the upload's success
  http.request {
      url = res2.location,
      method = "POST",
      headers = {
        ["authorization"] = "Bearer " .. self.token ,
      },
      sink   = ltn12.sink.table(res3),
  }
  res3 = json:decode(table.concat(res3))

  return res3

end


return canvas

