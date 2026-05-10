--- Shared decoding utilities for TCF segments.
-- @module gdpr.iab.tcfv2.common
-- @author Tiago Peczenyj
-- @license MIT

local M = {}

--- Decodes a 6-bit character (A-Z).
-- @function decode_char6
-- @param bs table BitStream instance.
-- @return string|nil Decoded character or nil on EOF.
function M.decode_char6(bs)
  local val = bs:read_int(6)
  if not val then
    return nil
  end
  return string.char(string.byte("A") + val)
end

--- Decodes a 2-character language code.
-- @function decode_language
-- @param bs table BitStream instance.
-- @return string|nil Decoded language code or nil on EOF.
function M.decode_language(bs)
  local c1 = M.decode_char6(bs)
  local c2 = M.decode_char6(bs)
  if not c1 or not c2 then
    return nil
  end
  return c1 .. c2
end

--- Decodes a fixed-length bitfield into a boolean table.
-- @function decode_bitfield_fixed
-- @param bs table BitStream instance.
-- @param start_offset integer|nil Optional bit position to seek to.
-- @param length integer Number of bits to read.
-- @return table Table where indices are boolean values.
function M.decode_bitfield_fixed(bs, start_offset, length)
  if start_offset then
    bs:seek(start_offset)
  end
  local res = {}
  for i = 1, length do
    res[i] = bs:read_bool()
  end
  return res
end

local function decode_vendor_bitfield(bs, max_id, target_vendors)
  local res = {}
  if target_vendors then
    local target_map = {}
    for _, id in ipairs(target_vendors) do
      target_map[id] = true
    end

    for i = 1, max_id do
      local val = bs:read_bool()
      if target_map[i] then
        res[i] = val
      end
    end
  else
    for i = 1, max_id do
      res[i] = bs:read_bool()
    end
  end
  return res
end

local function decode_vendor_range(bs, target_vendors)
  local num_entries = bs:read_int(12)
  local res = {}

  local target_map
  if target_vendors then
    target_map = {}
    for _, id in ipairs(target_vendors) do
      target_map[id] = true
    end
  end

  for _ = 1, num_entries do
    local is_range = bs:read_bool()
    local start_id = bs:read_int(16)
    if is_range then
      local end_id = bs:read_int(16)
      if target_map then
        for id = start_id, end_id do
          if target_map[id] then
            res[id] = true
          end
        end
      else
        for id = start_id, end_id do
          res[id] = true
        end
      end
    else
      if not target_map or target_map[start_id] then
        res[start_id] = true
      end
    end
  end

  return res
end

--- Decodes a standard Vendor Section (Bitfield or Range).
-- @function decode_vendor_section
-- @param bs table BitStream instance.
-- @param start_offset integer|nil Optional bit position to seek to.
-- @param[opt] options table Configuration options (supports targetVendors).
-- @return table|nil Decoded vendor table or nil on error.
-- @return integer Current bit position after decoding.
function M.decode_vendor_section(bs, start_offset, options)
  if start_offset then
    bs:seek(start_offset)
  end

  local max_id = bs:read_int(16)
  if not max_id then
    return nil, start_offset
  end

  local is_range = bs:read_bool()
  local res
  if not is_range then
    res = decode_vendor_bitfield(bs, max_id, options and options.targetVendors)
  else
    res = decode_vendor_range(bs, options and options.targetVendors)
  end
  return res, bs:pos()
end

return M
