local M = {}

local status, bit = pcall(require, "bit32")
if not status then
    status, bit = pcall(require, "bit")
end

if status and bit then
    M.band   = bit.band
    M.bor    = bit.bor
    M.bxor   = bit.bxor
    M.bnot   = bit.bnot
    M.lshift = bit.lshift
    M.rshift = bit.rshift
else
    -- Pure Lua fallback for bitwise operations (slow but compatible)
    -- This handles 32-bit integers
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
