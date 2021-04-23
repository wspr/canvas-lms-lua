--- Canvas LMS in Lua: HTTP
-- @submodule canvas


local http   = require("ssl.https")
local ltn12  = require("ltn12")
local json   = require("json")
local binser = require("binser")

--- Wrapper for GET.
-- @param self
-- @tparam string req URL stub to GET from
-- @param opt table of optional parameters
-- @treturn table REST result
canvas.get = function(self,req,opt)
  return canvas.getpostput(self,"GET",req,opt)
end


--- Paginated GET.
-- @param self
-- @param download_bool true | false | "ask"
-- @tparam string req URL stub to GET from
-- @param opt table of optional parameters
-- @treturn table REST result
--
-- Most REST interfaces use pagination to control sizes of return data.
-- This requires iteration of multiple requests to return a full collection of information.
-- Since this can be quite slow, this function has a built-in cache feature that stores
-- the data to disk and if desired re-reads this cache instead of slowly requesting the data again.
-- Where the cache is stored can be customised in the config file.
--
-- @usage canvas:get_pages(true,self.course_prefix.."assignments")

canvas.get_pages = function(self,download_bool,req,opt)

  local cache_name = string.gsub(req,"/"," - ")
  local cache_file = self.cache_dir.."Pages - "..cache_name..".lua"

  if download_bool == "ask" then
    print("Download all pages for requested GET ["..req.."] ?")
    print("Type y to do so:")
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


--- Wrapper for POST.
-- @param self
-- @tparam string req URL stub to POST to
-- @param opt table of optional parameters
-- @treturn table REST result
canvas.post = function(self,req,opt)
  return canvas.getpostput(self,"POST",req,opt)
end

--- Wrapper for PUT.
-- @param self
-- @tparam string req URL stub to PUT to
-- @param opt table of optional parameters
-- @treturn table REST result
canvas.put = function(self,req,opt)
  return canvas.getpostput(self,"PUT",req,opt)
end

--- Wrapper for DELETE.
-- @param self
-- @tparam string req URL stub to DELETE from
-- @param opt table of optional parameters
-- @treturn table REST result
canvas.delete = function(self,req,opt)
  return canvas.getpostput(self,"DELETE",req,opt)
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



