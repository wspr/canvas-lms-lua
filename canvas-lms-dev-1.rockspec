package = "canvas-lms"
version = "dev-1"
source = {
   url = "git+ssh://git@github.com/wspr/canvas-lms-lua.git"
}
description = {
   homepage = "http://wspr.io/canvas-lms-lua",
   license = "Apache v2"
}
build = {
   type = "builtin",
   modules = {} -- auto detected within "lua/"
}
dependencies = {
  "luasec",     -- these are of course actual dependencies, but nix installs them separately
  "luasocket",  -- these are of course actual dependencies, but nix installs them separately
  "lunajson",
  "penlight",
  "binser",
  "csv",
  "luafilesystem",
--  "markdown",
  "multipart-post"
}
