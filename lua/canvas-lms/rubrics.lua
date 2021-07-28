--- Canvas LMS in Lua: Rubrics
-- @submodule canvas

local dump = require("pl.pretty").dump
local csv    = require("csv")
local path   = require("pl.path")

local canvas = {}

--- Get all course rubrics and store their metadata.
-- Data stored in: `.rubrics` table indexed by `title` of the rubric.
-- @function get_rubrics
-- Code for this function uses the generic `define_getter` function in the HTTP submodule.


--- Send a rubric to Canvas.
-- Note that rubrics are first defined independently from assignments, and later associated with an assignment.
-- @see canvas.assoc_rubric
-- @param self
-- @tparam table rubric definition
canvas.send_rubric = function(self,rubric)

  self:get_rubrics{ download = true }
  self.rubrics[rubric.title] = self.rubrics[rubric.title] or {}

  local canvas_rubric
  local rubric_id = self.rubrics[rubric.title].id

  if rubric_id then
    print("RUBRIC SEND: "..rubric.title)
    print("Rubric already exists in Canvas, are you sure you want to overwrite it?")
    print("This will DELETE all comments made against any marked assignments.")
    print("  ")
    print("Type y to overwrite and delete comments:")
    if io.read() == "y" then
      canvas_rubric = self:put(self.course_prefix.."rubrics/"..rubric_id,{rubric = rubric})
      self.rubrics[rubric.title].id = canvas_rubric.id
    end
  else
    canvas_rubric = self:post(self.course_prefix.."rubrics",{rubric = rubric})
  end

  return canvas_rubric or {}
end



--- Associate a rubric to an assignment.
-- @param self
-- @tparam table args arguments
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
  return self:post(self.course_prefix.."rubric_associations",rassoc)

end



--- Read in a carefully structured CSV file and convert it into a rubric.
-- @tparam string csvfile
function canvas:rubric_from_csv(csvfile)

  if not(path.exists(csvfile)) then
    error("File '"..csvfile.."' not found.")
  end
  local f = csv.open(csvfile)

  local Nrow = 0
  local row_titles = {}
  local row_descr = {}
  local row_points = {}
  local row_use_range = {}
  local row_cell_titles = {}
  local row_cell_descrs = {}
  local row_cell_points = {}

  local rtitle
  local rdesc

  local function noop() end

  for fields in f:lines() do
    -- skip empty rows
    if fields[1] == "" then
      noop()
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

  self.rubric_csv = self.rubric_csv or {}
  self.rubric_csv[rtitle] = rubric -- currently unused

  return rubric

end


--- Read a collection of CSV files and create rubrics from them all.
-- @param self
-- @tparam table args arguments
canvas.setup_csv_rubrics = function(self,args)

  args = args or {}
  args.prefix = args.prefix or ""
  args.suffix = args.suffix or ""
  args.csv = args.csv or {}

  print("# Sending CSV rubrics")

  self:get_rubrics{ download = true }

  for _,vv in ipairs(args.csv) do
    local csvfile = args.prefix..vv..args.suffix
    print("Processing rubric from file: "..csvfile)
    local rubric  = self:rubric_from_csv(csvfile)
    local crubric = self:send_rubric(rubric)
    if crubric.error_report_id then
      error("Rubric create/update failed :(")
    elseif crubric.rubric then
      self.rubrics[rubric.title] = crubric.rubric
    end

  end

  print("## RUBRICS")
  for kk,vv in pairs(self.rubrics) do
    print( "   • "..vv.id.."  -  "..kk)
  end

end


function canvas:delete_all_rubrics()

  self:get_rubrics{ download = true }
  for _,j in pairs(self.rubrics) do
    local xx = self:delete( self.course_prefix.."rubrics/"..j.id)
    dump(xx)
  end

end

return canvas
