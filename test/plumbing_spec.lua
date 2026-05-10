local bit = require("src.bit")
local base64 = require("src.base64")
local BitStream = require("src.bitstream")

local function assert_eq(actual, expected, msg)
    if actual ~= expected then
        print("FAIL: " .. (msg or ""))
        print("  Expected: " .. tostring(expected))
        print("  Actual:   " .. tostring(actual))
        os.exit(1)
    end
end

print("Testing Bit bridge...")
assert_eq(bit.band(0xF0, 0x0F), 0, "band")
assert_eq(bit.bor(0xF0, 0x0F), 0xFF, "bor")
assert_eq(bit.lshift(1, 4), 16, "lshift")
assert_eq(bit.rshift(16, 4), 1, "rshift")

print("Testing Base64url...")
-- 'A' is 000000 in 6-bit. 'B' is 000001.
-- 'AB' -> 000000 000001 -> 00000000 0001....
-- 00000000 is 0. 00010000 is 16.
local decoded, err = base64.decode_url("AB")
assert_eq(decoded:sub(1,1), string.char(0), "base64 decode 1")

-- TCF test string snippet: 'COw'
-- C=2, O=14, w=48
-- 000010 001110 110000 -> 00001000 11101100 00......
-- 0x08 0xEC
local decoded2 = base64.decode_url("COw")
assert_eq(string.byte(decoded2, 1), 0x08, "base64 decode 2")
assert_eq(string.byte(decoded2, 2), 0xEC, "base64 decode 3")

print("Testing BitStream...")
local bs = BitStream.new(decoded2)
assert_eq(bs:read_int(6), 2, "read_int 1")
assert_eq(bs:read_int(6), 14, "read_int 2")
assert_eq(bs:read_int(4), 0, "read_int 3") -- The remaining 4 bits of 'w'

print("All plumbing tests passed!")
