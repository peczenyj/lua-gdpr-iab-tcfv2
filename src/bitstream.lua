local bit = require("src.bit")

local BitStream = {}
BitStream.__index = BitStream

function BitStream.new(data)
    local self = setmetatable({}, BitStream)
    self.data = data
    self.len = #data
    self.bit_pos = 0 -- 0-based bit position
    return self
end

function BitStream:read_int(bits)
    if bits == 0 then return 0 end
    if self.bit_pos + bits > self.len * 8 then
        return nil, "unexpected end of bitstream"
    end

    local val = 0
    for i = 1, bits do
        local byte_pos = math.floor(self.bit_pos / 8) + 1
        local bit_in_byte = 7 - (self.bit_pos % 8)
        local byte = string.byte(self.data, byte_pos)
        
        local bit_val = math.floor(byte / 2^bit_in_byte) % 2
        val = val * 2 + bit_val
        self.bit_pos = self.bit_pos + 1
    end
    
    return val
end

function BitStream:read_bool()
    local val, err = self.read_int(1)
    if err then return nil, err end
    return val == 1
end

function BitStream:skip(bits)
    self.bit_pos = self.bit_pos + bits
end

function BitStream:peek_int(bits)
    local old_pos = self.bit_pos
    local val, err = self.read_int(bits)
    self.bit_pos = old_pos
    return val, err
end

function BitStream:pos()
    return self.bit_pos
end

function BitStream:seek(pos)
    self.bit_pos = pos
end

return BitStream
