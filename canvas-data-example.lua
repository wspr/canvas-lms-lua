
canvas_url   "https://myuni.adelaide.edu.au/"
token        "<TOKEN>"
course_id    "<CID>"

 -- First monday of week 1:
first_monday { year=2020, month=03, day=02 }

-- Mid-semester break: after week 6 is a 2 week break:
break_week   (6)
break_length (2) -- optional, this is the default

cache_dir "cache/" -- optional, this is the default
