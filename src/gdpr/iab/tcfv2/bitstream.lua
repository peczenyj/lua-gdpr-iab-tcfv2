--- High-performance bit-level reader for binary data.
-- @classmod gdpr.iab.tcfv2.bitstream
-- @author Tiago Peczenyj
-- @license MIT

local BitStream = {}
BitStream.__index = BitStream

--- Creates a new BitStream instance.
-- @function new
-- @param data string Raw binary data.
-- @return table BitStream instance.
function BitStream.new(data)
  local self = setmetatable({}, BitStream)
  self.data = data
  self.len = #data
  self.bit_pos = 0 -- 0-based bit position
  return self
end

--- Reads an unsigned integer from the stream.
-- @function read_int
-- @param bits integer Number of bits to read.
-- @return integer|nil Decoded integer or nil on EOF.
-- @return string|nil Error message on failure.
function BitStream:read_int(bits)
  local res = 0
  for i = 1, bits do
    local pos = self.bit_pos
    local byte_idx = math.floor(pos / 8) + 1
    if byte_idx > self.len then
      return nil, "unexpected end of stream"
    end

    local byte = string.byte(self.data, byte_idx)
    local bit_idx = 7 - (pos % 8)
    local bit = math.floor(byte / (2 ^ bit_idx)) % 2

    res = (res * 2) + bit
    self.bit_pos = pos + 1
  end
  return res
end

--- Reads a single bit as a boolean.
-- @function read_bool
-- @return boolean|nil true if 1, false if 0, nil on EOF.
function BitStream:read_bool()
  local val, err = self:read_int(1)
  if val == nil then
    return nil, err
  end
  return val == 1
end

--- Peeks an unsigned integer without advancing the position.
-- @function peek_int
-- @param bits integer Number of bits to peek.
-- @return integer|nil Decoded integer or nil on EOF.
function BitStream:peek_int(bits)
  local old_pos = self.bit_pos
  local val, err = self:read_int(bits)
  self.bit_pos = old_pos
  return val, err
end

--- Returns the current bit position.
-- @function pos
-- @return integer
function BitStream:pos()
  return self.bit_pos
end

--- Moves the reader to a specific bit position.
-- @function seek
-- @param pos integer The 0-based bit position.
function BitStream:seek(pos)
  self.bit_pos = pos
end

return BitStream
