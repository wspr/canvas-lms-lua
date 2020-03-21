
local pretty = require("pl.pretty")




canvas.get_rubrics = function(self)

  print("# Getting rubrics currently in Canvas")

  local all_rubrics = canvas:get_pages(true,self.course_prefix.."rubrics")
  local rubrics_hash = {}
  for ii,vv in ipairs(all_rubrics) do
    rubrics_hash[vv.title] = vv.id
  end

  self.rubrics = all_rubrics
  self.rubric_ids = rubrics_hash

  print("## RUBRICS - .rubric_ids ")
  pretty.dump(self.rubric_ids)

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



canvas.setup_csv_rubrics = function(self,args)

  args = args or {}
  args.prefix = args.prefix or ""
  args.suffix = args.suffix or ""
  args.csv = args.csv or {}

  print("# Sending CSV rubrics")

  rubric_hash = {}

  for ii,vv in ipairs(args.csv) do
    local rubric  = self:rubric_from_csv(args.prefix..vv..args.suffix)
    local crubric = self:send_rubric(rubric)
    if crubric.error_report_id then
      error("Rubric create/update failed :(")
    end
    rubric_hash[rubric.title] = crubric.rubric.id

  end

  self.rubric_ids = rubric_hash

  print("## RUBRICS - .rubric_ids ")
  pretty.dump(self.rubric_ids)


end

