--- Canvas LMS in Lua: Calculating dates
-- @submodule canvas

local date   = require("pl.date")
--local pretty = require("pl.pretty")

local canvas = {}

--- Simple lookup table to allow string arguments to specify days of the week
local function day_string_to_num(argday)
  if type(argday) == "string" then
    if argday == "mon"       then argday =   0 end
    if argday == "tue"       then argday =   1 end
    if argday == "tues"      then argday =   1 end
    if argday == "wed"       then argday =   2 end
    if argday == "thu"       then argday =   3 end
    if argday == "fri"       then argday =   4 end
    if argday == "sat"       then argday =   5 end
    if argday == "sun"       then argday =   6 end
    if argday == "mon-next"  then argday = 7+0 end
    if argday == "tue-next"  then argday = 7+1 end
    if argday == "tues-next" then argday = 7+1 end
    if argday == "wed-next"  then argday = 7+2 end
    if argday == "thu-next"  then argday = 7+3 end
    if argday == "fri-next"  then argday = 7+4 end
    if argday == "sat-next"  then argday = 7+5 end
    if argday == "sun-next"  then argday = 7+6 end
  end
  return argday
end

local function date_offset(d,t)
  for k,v in pairs(t) do
    d:add{[k]=v}
  end
end

--- Calculate the datetime from a table of "logical" date and time declarations.
function canvas:datetime(args)

  local arg_sem    = args.sem or 1
  local wk_offset  = args.week
  local arg_day    = args.day or self.defaults.assignment.day
  local arg_hr     = args.hour or 23
  local arg_min    = args.min or nil
  local arg_offset = args.offset or {}
  if arg_min == nil then
    if arg_hr == 23 then arg_min = 59 else arg_min = 0 end
  end

  if self.sem_break_week[arg_sem] > 0 and self.sem_break_length[arg_sem] > 0 then
    if wk_offset > self.sem_break_week[arg_sem] then
      wk_offset = wk_offset + self.sem_break_length[arg_sem]
    end
  end
  local day_num = day_string_to_num(arg_day)

  local duedate = date(self.sem_first_monday[arg_sem])
  duedate:add{day=day_num+7*(wk_offset-1)}
  duedate:hour(arg_hr)
  duedate:min(arg_min)
  date_offset(duedate,arg_offset)

  return duedate
end

return canvas
