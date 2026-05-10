--- Pure math bitwise fallback for environments without bit libraries.
-- @module gdpr.iab.tcfv2.bit_fallback
-- @author Tiago Peczenyj
-- @license MIT

local M = {}

--- Bitwise AND.
-- @function band
-- @param a integer
-- @param b integer
-- @return integer
M.band = function(a, b)
  local result = 0
  local bit_val = 1
  for _ = 1, 32 do
    if a % 2 == 1 and b % 2 == 1 then
      result = result + bit_val
    end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    bit_val = bit_val * 2
  end
  return result
end

--- Bitwise OR.
-- @function bor
-- @param a integer
-- @param b integer
-- @return integer
M.bor = function(a, b)
  local result = 0
  local bit_val = 1
  for _ = 1, 32 do
    if a % 2 == 1 or b % 2 == 1 then
      result = result + bit_val
    end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    bit_val = bit_val * 2
  end
  return result
end

--- Bitwise XOR.
-- @function bxor
-- @param a integer
-- @param b integer
-- @return integer
M.bxor = function(a, b)
  local result = 0
  local bit_val = 1
  for _ = 1, 32 do
    if a % 2 ~= b % 2 then
      result = result + bit_val
    end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    bit_val = bit_val * 2
  end
  return result
end

--- Bitwise NOT.
-- @function bnot
-- @param a integer
-- @return integer
M.bnot = function(a)
  local r = 0
  for i = 0, 31 do
    if a % 2 == 0 then
      r = r + 2 ^ i
    end
    a = math.floor(a / 2)
  end
  return r
end

--- Bitwise left shift.
-- @function lshift
-- @param a integer
-- @param n integer
-- @return integer
M.lshift = function(a, n)
  return (a * 2 ^ n) % 2 ^ 32
end

--- Bitwise right shift.
-- @function rshift
-- @param a integer
-- @param n integer
-- @return integer
M.rshift = function(a, n)
  return math.floor(a / 2 ^ n)
end

return M
