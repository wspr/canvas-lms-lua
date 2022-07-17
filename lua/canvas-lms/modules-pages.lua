--- Canvas LMS in Lua: Modules and pages
-- @submodule canvas

local canvas = {}
local dump = require "pl.pretty".dump

--- Get all Canvas modules and store their metadata.
-- Data stored in `.modules` table, indexed by module `name`.
-- @function get_modules
-- Code for this function uses the generic `define_getter` function in the HTTP submodule.

--- Update metadata for a single module.
function canvas:update_module(modname,opt)

  if(self.modules==nil) then
    self:get_modules()
  end

  local id = self.modules[modname].id
  if id == nil then
    error("Module '"..modname"' not found.")
  end

  self:put(self.course_prefix.."modules/"..id,{module=opt})

end

--- Update metadata for a single page.
function canvas:update_page(modname,opt)

  if(self.pages==nil) then
    self:get_pages()
  end

  local id = self.pages[modname].id
  if id == nil then
    error("Page '"..modname"' not found.")
  end

  return self:put(self.course_prefix.."pages/"..id,{wiki_page=opt})

end

--- Create/edit all modules.
-- @tparam table modules   List of ordered module names to create.
-- If names are different than the modules currently defined, new ones are created and/or
-- current modules are re-ordered.
-- If modules exist that aren't specified, the function will offer to delete them (case-by-case).
function canvas:setup_modules(modules)

  self:get_modules{ download = true }

  for i,j in ipairs(modules) do
    if not(type(j)=="table") then
      modules[i] = {name=j}
    end
    modules[i].position = i
    if j.published == nil then
      modules[i].published = true
    end
  end

  for _,j in ipairs(modules) do
    if self.modules[j.name] == nil then
      print("Module "..j.name.." does not yet exist.")
      local xx = self:post(self.course_prefix.."modules",{module=j})
      modules[j] = xx.id
    else
      print("Module "..j.name.." update.")
      self:put(self.course_prefix.."modules/"..self.modules[j.name].id,{module=j})
    end
  end

  for _,j in ipairs(self.modules) do
    local isfound = false
    for _,jj in ipairs(modules) do
      if j.name == jj then
        isfound = true
        break
      end
    end
    if not(isfound) then
      print("Module exists but not specified: "..j.name.. ". Delete it?")
      print("Type y to do so:")
      if io.read() == "y" then
        self:delete(self.course_prefix.."modules/"..j.id)
      end
    end
  end

  local ifokay = false
  while not(ifokay) do
    ifokay = true
    for i,j in ipairs(modules) do
      for _,jj in ipairs(self.modules) do
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

end

--- Create/edit contents of an individual module.
-- @tparam string module_name
-- @tparam string ask of whether to proceed — *empty* asks, or |"y"| does, or *anything else* does not
-- @tparam table items (see [Canvas API documentation](https://canvas.instructure.com/doc/api/modules.html#method.context_module_items_api.create) for raw syntax)
-- Table of module items has some shorthand definitions defined in the code. TODO: document these properly.
function canvas:update_module_contents(module_name,ask,items)

  self:get_modules{ download = false }

  if self.modules[module_name] == nil then
    error("Unknown module: "..module_name)
  end

  if ask == "" then
    print("Create/update items for module '"..module_name.."'?")
    print("Type y to proceed:")
    ask = io.read()
  end

  if ask == "y" then

    local mod = self.modules[module_name].id
    local module_url = self.course_prefix.."modules/"..mod.."/items"
    local curr_items = self:get_paginated(true,module_url)

    local curr_items_lookup = {}
    for _,this_item in ipairs(curr_items) do
      curr_items_lookup[this_item.title] = this_item.id
    end

    -- setup
    local items_lookup = {}
    for i,j in ipairs(items) do

        local this_item = j
        this_item.position = i

        if not(this_item.heading==nil) then
          this_item.type = "SubHeader"
          this_item.title = this_item.heading
          this_item.heading = nil
          print("Heading:"..this_item.title)
        end

        if not(this_item.url==nil) then
          this_item.type = "ExternalUrl"
          this_item.external_url = this_item.url
          this_item.new_tab = true
          this_item.url = nil
          print("URL:"..this_item.title)
        end

        if not(this_item.page==nil) then
          this_item.type = "Page"
          this_item.page_url = this_item.page
          this_item.page = nil
          print("Page:"..this_item.title)
        end

        if not(this_item.filename==nil) then
          print("Heading:"..this_item.title)
          dump(this_item)
          this_item.type = "File"
          local tmp = self:get(self.course_prefix.."files/",{search_term=this_item.filename})
          if #tmp == 0 or tmp[1].id==nil then
            print("WARNING: File '"..this_item.filename.."' not found.")
          else
            this_item.content_id = tmp[1].id
          end
          this_item.filename = nil
        end

        if not(this_item.echo==nil) then
          if type(this_item.echo)=="string" then
            this_item.title = this_item.echo
          end
          this_item.type = "ExternalTool"
          this_item.external_url = "https://echo360.net.au/lti/5444fea8-33ce-4784-934a-2e9f0cb5a200"
          this_item.echo = nil
        end

        if not(this_item.assignment==nil) then
          self:get_assignments{download=false}
          this_item.type = "Assignment"
          this_item.title = this_item.assignment
          if self.assignments[this_item.assignment] == nil then
            error("Assignment '"..this_item.assignment.."' does not exist")
          end
          this_item.content_id = self.assignments[this_item.assignment].id
          this_item.assignment = nil
        end

        if this_item.published == nil then
          this_item.published = true
        end

        if not(curr_items_lookup[this_item.title]==nil) then
          self:put(module_url.."/"..curr_items_lookup[this_item.title],{module_item=this_item})
        else
          self:post(module_url,{module_item=this_item})
        end

        if this_item.title == nil then
          dump(this_item)
          error("No title: something wrong")
        end
        items_lookup[this_item.title] = true
    end

    for k,id in pairs(curr_items_lookup) do
      if not(items_lookup[k]) then
        print("Module '"..module_name.."': item currently exists but not specified: '"..k.. "'. Delete it?")
        print("Type y to do so:")
        if io.read() == "y" then
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

  self:get_modules{ download = false }

  for _,jj in ipairs(self.modules) do

    if jj.published then

      local any_published = false
      for _,jjj in ipairs(jj.items) do
        if jjj.published then
          any_published = true
        end
      end
      if not(any_published) then
        print("Module '"..jj.name.."' is published but has no published items. Un-publish now?")
        print("Type y to do so:")
        if io.read() == "y" then
          self:put(self.course_prefix.."modules/"..jj.id,{module={published=false}})
        end
      end

    else

      local any_published = false
      for _,jjj in ipairs(jj.items) do
        if jjj.published then
          any_published = true
        end
      end
      if any_published then
        print("Module '"..jj.name.."' is not published but has published items. Publish now?")
        print("Type y to do so:")
        if io.read() == "y" then
          self:put(self.course_prefix.."modules/"..jj.id,{module={published=true}})
        end
      end

    end
  end

end

return canvas


