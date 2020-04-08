
canvas_url   "https://myuni.adelaide.edu.au/"
course_id    "<CID>"

token        "<TOKEN>" -- see: https://canvas.instructure.com/doc/api/file.oauth.html#manual-token-generation

 -- First monday of week 1:
first_monday { year=2020, month=03, day=02 }

-- Mid-semester break: after week 6 is a 2 week break:
break_week   (6)
break_length (2) -- optional, this is the default

-- If you have more than one semester, replicate the lines above:
--[[
-- Semester 2:
first_monday { year=2020, month=03, day=02 }
break_week   (6)
break_length (2)
--]]

cache_dir "cache/" -- optional, this is the default
