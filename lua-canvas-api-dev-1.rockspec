package = "lua-canvas-api"
version = "dev-1"
source = {
   url = "git+ssh://git@github.com/wspr/lua-canvas-api.git"
}
description = {
   homepage = "http://wspr.io/lua-canvas-api",
   license = "Apache v2"
}
build = {
   type = "builtin",
   modules = {
      ["canvas-lms"]          = "canvas-lms/canvas-lms.lua",
      ["canvas-lms-config"]   = "canvas-lms/canvas-lms-config.lua",
      ["canvas-lms-http"]     = "canvas-lms/canvas-lms-http.lua",
      ["canvas-lms-students"] = "canvas-lms/canvas-lms-students.lua",
      ["canvas-lms-rubrics"]  = "canvas-lms/canvas-lms-rubrics.lua",
      ["canvas-lms-message"]  = "canvas-lms/canvas-lms-message.lua",
      ["canvas-lms-assign"]   = "canvas-lms/canvas-lms-assign.lua",
      ["canvas-lms-grades"]   = "canvas-lms/canvas-lms-grades.lua",
   }
}
dependencies = {
  "luasec",
  "luasocket",
  "json-lua",
  "penlight",
  "binser",
  "csv",
  "luafilesystem",
  "markdown",
}
