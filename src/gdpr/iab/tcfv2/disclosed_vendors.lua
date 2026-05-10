--- Segment decoder for Disclosed Vendors (Type 1).
-- @classmod gdpr.iab.tcfv2.disclosed_vendors
-- @author Tiago Peczenyj
-- @license MIT

local BitStream = require("gdpr.iab.tcfv2.bitstream")
local common = require("gdpr.iab.tcfv2.common")

local DisclosedVendors = {}
DisclosedVendors.__index = DisclosedVendors

--- Creates a new Disclosed Vendors segment instance.
-- @function new
-- @param decoded_data string Raw binary data for the segment.
-- @param[opt] options table Configuration options.
-- @return table|nil DisclosedVendors instance or nil on error.
function DisclosedVendors.new(decoded_data, options)
  local bs = BitStream.new(decoded_data)
  local segment_type = bs:read_int(3)

  if segment_type ~= 1 then
    return nil,
      "invalid segment type for disclosed vendors: " .. tostring(segment_type)
  end

  local res, _ = common.decode_vendor_section(bs, nil, options)

  local self = setmetatable({
    vendorDisclosed = res,
  }, DisclosedVendors)

  return self
end

--- Converts disclosed vendors segment fields to a plain table.
-- @function to_table
-- @return table
function DisclosedVendors:to_table()
  return {
    vendorDisclosed = self.vendorDisclosed,
  }
end

return DisclosedVendors
