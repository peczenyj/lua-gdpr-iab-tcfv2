local BitStream = require("gdpr.iab.tcfv2.bitstream")
local common = require("gdpr.iab.tcfv2.common")

local AllowedVendors = {}
AllowedVendors.__index = AllowedVendors

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

function AllowedVendors:to_table()
  return {
    vendorAllowed = self.vendorAllowed,
  }
end

return AllowedVendors
