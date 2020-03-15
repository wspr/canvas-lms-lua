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
      canvas = "canvas.lua",
      ["canvas-data"] = "canvas-data.lua"
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
