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
      ["canvas-lms"]          = "canvas-lms.lua",
      ["canvas-lms-http"]     = "canvas-lms-http.lua",
      ["canvas-lms-students"] = "canvas-lms-students.lua",
      ["canvas-lms-rubrics"]  = "canvas-lms-rubrics.lua",
      ["canvas-lms-message"]  = "canvas-lms-message.lua",
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
}
