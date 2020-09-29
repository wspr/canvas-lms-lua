
local binser = require("binser")
local pretty = require("pl.pretty")


canvas.get_modules = function(self,args)

  local modules = self:get_pages(true,self.course_prefix.."modules")
  local hash = {}
  for ii,vv in ipairs(modules) do
    modules[vv.name] = vv.id
  end
  self.modules = modules

end


canvas.setup_modules = function(self,modules)

  if self.modules == nil then
    self:get_modules()
  end

  for i,j in ipairs(modules) do
    if canvas.modules[j] == nil then
      xx = self:post(self.course_prefix.."modules",{module={name=j,position=i}})
      modules[j] = xx.id
      pretty.dump(xx)
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


end



canvas.update_module = function(self,module_name,items)

  if self.modules == nil then
    self:get_modules()
  end

  if self.modules[module_name] == nil then
    error("Unknown module: "..module_name)
  end

  local module_url = self.course_prefix.."modules/"..self.modules[module_name].."/items"

  local curr_items = self:get_pages(true,module_url)

  pretty.dump(curr_items)

  for i,j in ipairs(items) do

    local this_item = j
    for ii,jj in ipairs(this_item) do
      this_item.position = ii
    end
--    self:post(module_url,{module_item=this_item})

  end

end



