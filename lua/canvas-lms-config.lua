--- Canvas LMS in Lua: Configuration
-- @submodule canvas

local lfs    = require "lfs"

--- Set course ID, which defines course prefix.
function canvas:set_course_id(str)
  self.courseid = str
  self.course_prefix = "courses/"..str.."/"
end

--- Set Canvas URL.
function canvas:set_url(str)
  self.url = str
end

--- Set user token for authenticated to API (keep this secret!).
function canvas:set_token(self,str)
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

do
  local shared = {
    canvas_url       = function(x) canvas:set_url(x)          end,
    course_id        = function(x) canvas:set_course_id(x)    end,
    token            = function(x) canvas:set_token(x)        end,
    first_monday     = function(x) canvas:set_first_monday(x) end,
    break_after_week = function(x) canvas:set_break_week(x)   end,
    break_length     = function(x) canvas:set_break_length(x) end,
    cache_dir        = function(x) canvas:set_cache_dir(x)    end,
  }
  loadfile(canvas_config or 'canvas-config.lua', 't', shared)()
end

canvas.sem_break_week    = canvas.sem_break_week   or {99,99}
canvas.sem_break_length  = canvas.sem_break_length or {2,2}
if #canvas.sem_break_length == 1 then
  canvas.sem_break_length = {canvas.sem_break_length[1],canvas.sem_break_length[1]}
end

canvas.cache_dir = canvas.cache_dir or "./cache/"
lfs.mkdir(canvas.cache_dir)

--[[ DEFAULTS --]]

canvas.defaults = {}
canvas.defaults.assignment = {}
canvas.defaults.assignment.day = nil
canvas.defaults.assignment.open_days = nil
canvas.defaults.assignment.late_days = nil
canvas.defaults.discussions.discussion_type = "threaded"
