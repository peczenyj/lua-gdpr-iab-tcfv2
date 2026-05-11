--- bit32 library implementation for Lua 5.2.
-- @module gdpr.iab.tcfv2.bit_bit32
-- @author Tiago Peczenyj
-- @license MIT

local bit32 = require("bit32")
local M = {}

M.band = bit32.band
M.bor = bit32.bor
M.bxor = bit32.bxor
M.bnot = bit32.bnot
M.lshift = bit32.lshift
M.rshift = bit32.rshift

return M
