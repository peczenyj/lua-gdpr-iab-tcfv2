--- bit library implementation for LuaJIT / Lua 5.1.
-- @module gdpr.iab.tcfv2.bit_luajit
-- @author Tiago Peczenyj
-- @license MIT

local bit = require("bit")
local M = {}

M.band = bit.band
M.bor = bit.bor
M.bxor = bit.bxor
M.bnot = bit.bnot
M.lshift = bit.lshift
M.rshift = bit.rshift

return M
