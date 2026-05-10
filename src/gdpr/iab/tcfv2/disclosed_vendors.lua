local BitStream = require("gdpr.iab.tcfv2.bitstream")
local common = require("gdpr.iab.tcfv2.common")

local DisclosedVendors = {}
DisclosedVendors.__index = DisclosedVendors

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

return DisclosedVendors
