--- Zero-dependency Base64url decoder.
-- @module gdpr.iab.tcfv2.base64
-- @author Tiago Peczenyj
-- @license MIT

local M = {}

local chars_url =
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"

local function build_decode_map(alphabet)
  local map = {}
  for i = 1, #alphabet do
    map[alphabet:sub(i, i)] = i - 1
  end
  return map
end

local decode_map_url = build_decode_map(chars_url)

--- Decodes a Base64url encoded string.
-- @function decode_url
-- @param input string Base64url encoded string.
-- @return string|nil Decoded binary data or nil on error.
-- @return string|nil Error message if decoding failed.
function M.decode_url(input)
  if not input then
    return nil, "missing input"
  end

  -- Remove padding and sanitize
  local data = input:gsub("=", "")
  local output = {}
  local buffer = 0
  local bits = 0

  for i = 1, #data do
    local char = data:sub(i, i)
    local val = decode_map_url[char]
    if not val then
      return nil, "invalid character in base64: " .. char
    end

    buffer = (buffer * 64) + val
    bits = bits + 6

    if bits >= 8 then
      bits = bits - 8
      local byte = math.floor(buffer / (2 ^ bits))
      table.insert(output, string.char(byte % 256))
      buffer = buffer % (2 ^ bits)
    end
  end

  return table.concat(output)
end

return M
