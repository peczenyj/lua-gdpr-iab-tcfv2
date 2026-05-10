--- Native bitwise operators implementation for Lua 5.3+.
-- @module gdpr.iab.tcfv2.bit_native
-- @author Tiago Peczenyj
-- @license MIT

local M = {}

M.band = load("return function(a, b) return a & b end")()
M.bor = load("return function(a, b) return a | b end")()
M.bxor = load("return function(a, b) return a ~ b end")()
M.bnot = load("return function(a) return ~a end")()
M.lshift = load("return function(a, n) return a << n end")()
M.rshift = load("return function(a, n) return a >> n end")()

return M
