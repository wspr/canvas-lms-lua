--- Canvas LMS in Lua: Modules and pages
-- @submodule canvas

local binser = require("binser")
local pretty = require("pl.pretty")

--- Get all Canvas modules and store their metadata.
function canvas:get_modules(args)

  local modules = self:get_pages(true,self.course_prefix.."modules",{include={"items"}})
  local hash = {}
  for ii,vv in ipairs(modules) do
    modules[vv.name] = vv.id
    hash[vv.name] = vv.id
  end
  self.modules = modules
  self.module_ids = hash

end

--- Create/edit all modules.
-- @tparam table modules   List of ordered module names to create.
-- If names are different than the modules currently defined, new ones are created and/or current modules are re-ordered.
-- If modules exist that aren't specified, the function will offer to delete them (case-by-case).
function canvas:setup_modules(modules)

  if self.modules == nil then
    self:get_modules()
  end

  for i,j in ipairs(modules) do
    if canvas.modules[j] == nil then
      xx = self:post(self.course_prefix.."modules",{module={name=j,position=i}})
      modules[j] = xx.id
    end
  end

  for i,j in ipairs(self.modules) do
    local isfound = false
    for ii,jj in ipairs(modules) do
      if j.name == jj then
        isfound = true
        break
      end
    end
    if not(isfound) then
      print("Module exists but not specified: "..j.name.. ". Delete it?")
      print("Type y to do so:")
      check = io.read()
      if check == "y" then
        self:delete(self.course_prefix.."modules/"..j.id)
      end
    end
  end

  local ifokay = false
  while not(ifokay) do
    ifokay = true
    for i,j in ipairs(modules) do
      for ii,jj in ipairs(canvas.modules) do
        if jj.name == j then
          if jj.position ~= i then
            print("Updating position of "..jj.name)
            self:put(self.course_prefix.."modules/"..jj.id,{module={position=i}})
            self:get_modules()
            ifokay = false
            break
          end
        end
      end
    end
  end

  self:get_modules()

end

--- Create/edit contents of an individual module.
-- @tparam string module_name
-- @tparam string ask of whether to proceed — *empty* asks, or |"y"| does, or *anything else* does not
-- @tparam table items (see [Canvas API documentation](https://canvas.instructure.com/doc/api/modules.html#method.context_module_items_api.create) for raw syntax)
-- Table of module items has some shorthand definitions defined in the code. TODO: document these properly.
function canvas:update_module(module_name,ask,items)

  if self.modules == nil then
    self:get_modules()
  end

  if self.modules[module_name] == nil then
    error("Unknown module: "..module_name)
  end

  if ask == "" then
    print("Create/update items for module '"..module_name.."'?")
    print("Type y to proceed:")
    ask = io.read()
  end

  if ask == "y" then

  local module_url = self.course_prefix.."modules/"..self.modules[module_name].."/items"
  local curr_items = self:get_pages(true,module_url)

  local curr_items_lookup = {}
  for i,this_item in ipairs(curr_items) do
    curr_items_lookup[this_item.title] = this_item.id
  end

  -- setup
  local items_lookup = {}
  local items = items
  for i,j in ipairs(items) do

      local this_item = j
      this_item.position = i

      if not(this_item.heading==nil) then
        this_item.type = "SubHeader"
        this_item.title = this_item.heading
        this_item.heading = nil
      end

      if not(this_item.url==nil) then
        this_item.type = "ExternalUrl"
        this_item.external_url = this_item.url
        this_item.new_tab = true
        this_item.url = nil
      end

      if not(this_item.page==nil) then
        this_item.type = "Page"
        this_item.page_url = this_item.page
        this_item.page = nil
      end

      if not(this_item.filename==nil) then
        this_item.type = "File"
        local tmp = self:get(self.course_prefix.."files/",{search_term=this_item.filename})
        if tmp[1].id==nil then
          error("File '"..this_item.filename.."' not found.")
        else
          this_item.content_id = tmp[1].id
        end
        this_item.filename = nil
      end

      if not(this_item.echo==nil) then
        this_item.type = "ExternalTool"
        this_item.external_url = "https://echo360.org.au/lti/5444fea8-33ce-4784-934a-2e9f0cb5a200"
        this_item.echo = nil
      end

      if not(curr_items_lookup[this_item.title]==nil) then
        self:put(module_url.."/"..curr_items_lookup[this_item.title],{module_item=this_item})
      else
        self:post(module_url,{module_item=this_item})
      end

      items_lookup[this_item.title] = true
  end

  for k,id in pairs(curr_items_lookup) do
    if not(items_lookup[k]) then
      print("Module '"..module_name.."': item currently exists but not specified: '"..k.. "'. Delete it?")
      print("Type y to do so:")
      check = io.read()
      if check == "y" then
        self:delete(module_url.."/"..id)
      end
    end
  end

  end

end


--- Suite of sanity checks for all Canvas modules.
-- * Checks if published module is empty
-- * Checks if published items are located in unpublished module
-- * More to come…
function canvas:check_modules()

  if self.modules == nil then
    self:get_modules()
  end

  for ii,jj in ipairs(self.modules) do

    if jj.published then

      local any_published = false
      for iii,jjj in ipairs(jj.items) do
        if jjj.published then
          any_published = true
        end
      end
      if not(any_published) then
        print("Module '"..jj.name.."' it published but has no published items. Un-publish now?")
        print("Type y to do so:")
        if io.read() == "y" then
          self:put(self.course_prefix.."modules/"..jj.id,{module={published=false}})
        end
      end

    else

      local any_published = false
      for iii,jjj in ipairs(jj.items) do
        if jjj.published then
          any_published = true
        end
      end
      if any_published then
        print("Module '"..jj.name.."' it not published but has published items. Publish now?")
        print("Type y to do so:")
        if io.read() == "y" then
          self:put(self.course_prefix.."modules/"..jj.id,{module={published=true}})
        end
      end

    end
  end

end



