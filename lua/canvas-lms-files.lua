--- Canvas LMS in Lua: Files
-- @submodule canvas

local http   = require("ssl.https")
local binser = require("binser")
local path   = require("pl.path")


--- Get all files and store their metadata.
-- @tparam table arg list of arguments
-- download = true | false | "ask"

canvas:define_getter("files","filename")



