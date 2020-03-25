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
   modules = {} -- auto detected within "lua/"
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
