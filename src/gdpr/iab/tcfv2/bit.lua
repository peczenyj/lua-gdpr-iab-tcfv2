--- Version-agnostic bitwise bridge.
-- Supports Lua 5.1 (native bit), 5.2 (bit32), 5.3+ (native operators), and LuaJIT.
-- @module gdpr.iab.tcfv2.bit
-- @author Tiago Peczenyj
-- @license MIT

local M = {}

-- Detect environment and select best available bitwise logic
local has_bit32, bit32 = pcall(require, "bit32")
local has_bit, bit = pcall(require, "bit")

if _VERSION >= "Lua 5.3" then
  -- Use native 5.3+ operators (via load to maintain 5.1 compatibility)
  M.band = load("return function(a, b) return a & b end")()
  M.bor = load("return function(a, b) return a | b end")()
  M.bxor = load("return function(a, b) return a ~ b end")()
  M.bnot = load("return function(a) return ~a end")()
  M.lshift = load("return function(a, n) return a << n end")()
  M.rshift = load("return function(a, n) return a >> n end")()
elseif has_bit32 then
  M.band = bit32.band
  M.bor = bit32.bor
  M.bxor = bit32.bxor
  M.bnot = bit32.bnot
  M.lshift = bit32.lshift
  M.rshift = bit32.rshift
elseif has_bit then
  M.band = bit.band
  M.bor = bit.bor
  M.bxor = bit.bxor
  M.bnot = bit.bnot
  M.lshift = bit.lshift
  M.rshift = bit.rshift
else
  -- Fallback to pure math (Slow, but ensures 5.1 compatibility without extensions)
  M.band = function(a, b)
    local result = 0
    local bit_val = 1
    for i = 1, 32 do
      if a % 2 == 1 and b % 2 == 1 then
        result = result + bit_val
      end
      a = math.floor(a / 2)
      b = math.floor(b / 2)
      bit_val = bit_val * 2
    end
    return result
  end

  M.bor = function(a, b)
    local result = 0
    local bit_val = 1
    for i = 1, 32 do
      if a % 2 == 1 or b % 2 == 1 then
        result = result + bit_val
      end
      a = math.floor(a / 2)
      b = math.floor(b / 2)
      bit_val = bit_val * 2
    end
    return result
  end

  M.bxor = function(a, b)
    local result = 0
    local bit_val = 1
    for i = 1, 32 do
      if a % 2 ~= b % 2 then
        result = result + bit_val
      end
      a = math.floor(a / 2)
      b = math.floor(b / 2)
      bit_val = bit_val * 2
    end
    return result
  end

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

  M.lshift = function(a, n)
    return (a * 2 ^ n) % 2 ^ 32
  end
  M.rshift = function(a, n)
    return math.floor(a / 2 ^ n)
  end
end

return M
