package = "lua-gdpr-iab-tcfv2"
version = "0.1.0-1"
source = {
   url = "git+https://github.com/peczenyj/lua-gdpr-iab-tcfv2.git"
}
description = {
   summary = "A zero-dependency, JIT-optimized Lua parser for IAB TCF v2.x.",
   detailed = [[
      lua-gdpr-iab-tcfv2 is a high-performance, version-agnostic Lua parser for IAB TCF v2.x consent strings.
      It is optimized for middleware environments like OpenResty and HAProxy, featuring lazy decoding and zero external dependencies.
   ]],
   homepage = "https://github.com/peczenyj/lua-gdpr-iab-tcfv2",
   license = "MIT"
}
dependencies = {
   "lua >= 5.1"
}
test_dependencies = {
   "busted",
   "luacheck",
   "stylua",
   "luacov"
}
build = {
   type = "builtin",
   modules = {
      ["gdpr.iab.tcfv2"] = "src/init.lua",
      ["gdpr.iab.tcfv2.bit"] = "src/bit.lua",
      ["gdpr.iab.tcfv2.base64"] = "src/base64.lua",
      ["gdpr.iab.tcfv2.bitstream"] = "src/bitstream.lua"
   }
}
