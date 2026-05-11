--- Version-agnostic bitwise bridge.
-- Detects the Lua environment and loads the appropriate implementation.
-- @module gdpr.iab.tcfv2.bit
-- @author Tiago Peczenyj
-- @license MIT

local has_bit32, _ = pcall(require, "bit32")
local has_bit, _ = pcall(require, "bit")

if _VERSION >= "Lua 5.3" then
  return require("gdpr.iab.tcfv2.bit_native")
elseif has_bit32 then
  return require("gdpr.iab.tcfv2.bit_bit32")
elseif has_bit then
  return require("gdpr.iab.tcfv2.bit_luajit")
end

return require("gdpr.iab.tcfv2.bit_fallback")
