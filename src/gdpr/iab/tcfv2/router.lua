--- Router for TCF segments.
-- Identifies and routes additional segments (Type 1, 2, 3) to their decoders.
-- @module gdpr.iab.tcfv2.router
-- @author Tiago Peczenyj
-- @license MIT

local base64 = require("gdpr.iab.tcfv2.base64")
local BitStream = require("gdpr.iab.tcfv2.bitstream")
local DisclosedVendors = require("gdpr.iab.tcfv2.disclosed_vendors")
local AllowedVendors = require("gdpr.iab.tcfv2.allowed_vendors")
local PublisherTC = require("gdpr.iab.tcfv2.publisher_tc")

local Router = {}

local DECODERS = {
  [1] = DisclosedVendors,
  [2] = AllowedVendors,
  [3] = PublisherTC,
}

--- Decodes and routes all non-core segments.
-- @function decode_segments
-- @param segments table List of Base64url encoded segments.
-- @param[opt] options table Configuration options.
-- @param[opt] warnings table Aggregate to append lenient-mode failures to.
--   Typically the parser's unified `core.warnings` table.
-- @return table|nil Map of segment type to segment object, or nil on error.
-- @return string|nil Error message if decoding failed.
function Router.decode_segments(segments, options, warnings)
  options = options or {}
  warnings = warnings or {}
  local results = {}

  -- Skip the first segment (Core)
  for i = 2, #segments do
    local b64 = segments[i]
    local data, err = base64.decode_url(b64)
    if not data then
      local msg = "invalid base64 in segment " .. i .. ": " .. tostring(err)
      if options.strict then
        return nil, msg
      end
      table.insert(warnings, msg)
    else
      local bs = BitStream.new(data)
      local segment_type = bs:peek_int(3)
      if segment_type and DECODERS[segment_type] then
        local decoder = DECODERS[segment_type]
        local segment_obj, d_err = decoder.new(data, options)
        if segment_obj then
          results[segment_type] = segment_obj
        else
          local msg = "failed to decode segment "
            .. i
            .. ": "
            .. tostring(d_err)
          if options.strict then
            return nil, msg
          end
          table.insert(warnings, msg)
        end
      else
        local msg = "unknown segment type at segment "
          .. i
          .. ": "
          .. tostring(segment_type)
        if options.strict then
          return nil, msg
        end
        table.insert(warnings, msg)
      end
    end
  end
  return results
end

return Router
