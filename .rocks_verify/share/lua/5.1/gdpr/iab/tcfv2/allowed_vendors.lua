--- Segment decoder for Allowed Vendors (Type 2).
-- @classmod gdpr.iab.tcfv2.allowed_vendors
-- @author Tiago Peczenyj
-- @license MIT

local BitStream = require("gdpr.iab.tcfv2.bitstream")
local common = require("gdpr.iab.tcfv2.common")

local AllowedVendors = {}
AllowedVendors.__index = AllowedVendors

--- Creates a new Allowed Vendors segment instance.
-- @function new
-- @param decoded_data string Raw binary data for the segment.
-- @param[opt] options table Configuration options.
-- @return table|nil AllowedVendors instance or nil on error.
function AllowedVendors.new(decoded_data, options)
  local bs = BitStream.new(decoded_data)
  local segment_type = bs:read_int(3)

  if segment_type ~= 2 then
    return nil,
      "invalid segment type for allowed vendors: " .. tostring(segment_type)
  end

  local res, _ = common.decode_vendor_section(bs, nil, options)

  local self = setmetatable({
    vendorAllowed = res,
  }, AllowedVendors)

  return self
end

--- Converts allowed vendors segment fields to a plain table.
-- @function to_table
-- @return table
function AllowedVendors:to_table()
  return {
    vendorAllowed = self.vendorAllowed,
  }
end

return AllowedVendors
