--- Canvas LMS in Lua: Configuration
-- @submodule canvas

local lfs    = require "lfs"
local canvas = {}


--[[ DEFAULTS --]]

canvas.mobius_url = "https://adelaide.mobius.cloud:443/lti/"

canvas.defaults = {}
canvas.defaults.assignments = {}
canvas.defaults.assignments.day  = nil
canvas.defaults.assignments.hour = nil
canvas.defaults.assignments.open_days = nil
canvas.defaults.assignments.late_days = nil
canvas.defaults.discussion = {}
canvas.defaults.discussion.discussion_type = "threaded"


--[[ CONFIG --]]

--- Set debug status, which disables interaction with the live Canvas API.
function canvas:set_debug(bool)
  self.debug = bool
end
canvas:set_debug(false)

--- Set verbose status, which echoes all interaction with the Canvas API.
-- Default = 0, which hides most things
function canvas:set_verbose(num)
  self.verbose = num
end
canvas:set_verbose(0)

local f = assert(io.open("_proj_log.md", "w"))

function canvas:print(str)
  print(str)
  f:write(str,"\n")
end

function canvas:message(str)
  if self.verbose > 0 then
    self:print(str)
  end
end

function canvas:info(s)
  if self.verbose > 1 then
    self:print("    INFO:  "..s)
  end
end

--- Set course ID, which defines course prefix.
function canvas:set_course_id(str)
  self.courseid = str
  self.course_prefix = "courses/"..str.."/"
end

--- Set Canvas URL.
function canvas:set_url(str)
  self.url = str
end

--- Set cohort (e.g., year+semester).
function canvas:set_cohort(str)
  self.cohort = str
end

--- Set user token for authenticated to API (keep this secret!).
function canvas:set_token(str)
  self.token = str
end

--- Set folder for storing cache files of this library.
function canvas:set_cache_dir(str)
  self.cache_top = str
  self.cache_dir = str..self.courseid.."/"
end

canvas.sem_first_monday = {}
canvas.sem_break_week   = {}
canvas.sem_break_length = {}

--- Set date of first Monday of teaching interval (multiple allowed).
function canvas:set_first_monday(arg)
  self.sem_first_monday[#self.sem_first_monday+1] = arg
end

--- Set last week before mid-interval break (multiple allowed).
function canvas:set_break_week(arg)
  self.sem_break_week[#self.sem_break_week+1] = arg
end

--- Set number of weeks of mid-interval break (multiple allowed).
function canvas:set_break_length(arg)
  self.sem_break_length[#self.sem_break_length+1] = arg
end

function canvas:config(configfile)
  configfile = configfile or _G["canvas_config"] or 'canvas-config.lua'
  do
    local shared = {
      canvas_url       = function(x) self:set_url(x)          end,
      course_id        = function(x) self:set_course_id(x)    end,
      token            = function(x) self:set_token(x)        end,
      first_monday     = function(x) self:set_first_monday(x) end,
      break_after_week = function(x) self:set_break_week(x)   end,
      break_length     = function(x) self:set_break_length(x) end,
      cache_dir        = function(x) self:set_cache_dir(x)    end,
      debug            = function(x) self:set_debug(x)        end,
      verbose          = function(x) self:set_verbose(x)      end,
      cohort           = function(x) self:set_cohort(x)       end,
    }
    loadfile(configfile, 't', shared)()
  end

  if #self.sem_break_week == 0 then
    self.sem_break_week    = {99,99}
  elseif #self.sem_break_week == 1 then
    self.sem_break_week    = {self.sem_break_week[1],self.sem_break_week[1]}
  end
  if #self.sem_break_length == 0 then
    self.sem_break_length  = {2,2}
  elseif #self.sem_break_length == 1 then
    self.sem_break_length = {self.sem_break_length[1],self.sem_break_length[1]}
  end

  self.cache_dir = self.cache_dir or "./cache/"
  self:info("Creating cache directory: "..self.cache_dir)
  lfs.mkdir(self.cache_dir)
end

--[[ OO --]]

function canvas:new(cfg)
  newcourse = setmetatable({},{__index = self})
  newcourse:config(cfg)
  return newcourse
end

return canvas
