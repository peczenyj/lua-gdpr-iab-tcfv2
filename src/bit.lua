local M = {}

-- Detect environment
local is_lua53_plus = _VERSION >= "Lua 5.3"
local has_bit32, bit32 = pcall(require, "bit32")
local has_bit, bit = pcall(require, "bit")

if is_lua53_plus then
    -- Use native operators via load string to prevent syntax errors in Lua < 5.3
    M.band   = load("return function(a, b) return a & b end")()
    M.bor    = load("return function(a, b) return a | b end")()
    M.bxor   = load("return function(a, b) return a ~ b end")()
    M.bnot   = load("return function(a) return ~a end")()
    M.lshift = load("return function(a, n) return a << n end")()
    M.rshift = load("return function(a, n) return a >> n end")()
elseif has_bit32 then
    M.band   = bit32.band
    M.bor    = bit32.bor
    M.bxor   = bit32.bxor
    M.bnot   = bit32.bnot
    M.lshift = bit32.lshift
    M.rshift = bit32.rshift
elseif has_bit then
    M.band   = bit.band
    M.bor    = bit.bor
    M.bxor   = bit.bxor
    M.bnot   = bit.bnot
    M.lshift = bit.lshift
    M.rshift = bit.rshift
else
    -- Pure Lua fallback for Lua 5.1 (non-JIT)
    local function make_bitop(op)
        return function(a, b)
            local r = 0
            for i = 0, 31 do
                local ai = a % 2
                local bi = b % 2
                a = math.floor(a / 2)
                b = math.floor(b / 2)
                if op(ai, bi) then
                    r = r + 2^i
                end
            end
            return r
        end
    end

    M.band = make_bitop(function(a, b) return a == 1 and b == 1 end)
    M.bor  = make_bitop(function(a, b) return a == 1 or b == 1 end)
    M.bxor = make_bitop(function(a, b) return a ~= b end)
    M.bnot = function(a)
        local r = 0
        for i = 0, 31 do
            if a % 2 == 0 then
                r = r + 2^i
            end
            a = math.floor(a / 2)
        end
        return r
    end
    M.lshift = function(a, n) return (a * 2^n) % 2^32 end
    M.rshift = function(a, n) return math.floor(a / 2^n) end
end

return M
